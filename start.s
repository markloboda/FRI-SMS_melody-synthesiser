.equ PMC_BASE,  0xFFFFFC00  /* (PMC) Base Address */
.equ CKGR_MOR,	0x20        /* (CKGR) Main Oscillator Register */
.equ CKGR_PLLAR,0x28        /* (CKGR) PLL A Register */
.equ PMC_MCKR,  0x30        /* (PMC) Master Clock Register */
.equ PMC_SR,	  0x68        /* (PMC) Status Register */

.text
.code 32

.global _error
_error:
  b _error

.global	_start
_start:

/* select system mode 
  CPSR[4:0]	Mode
  --------------
   10000	  User
   10001	  FIQ
   10010	  IRQ
   10011	  SVC
   10111	  Abort
   11011	  Undef
   11111	  System   
*/

  mrs r0, cpsr
  bic r0, r0, #0x1F   /* clear mode flags */  
  orr r0, r0, #0xDF   /* set supervisor mode + DISABLE IRQ, FIQ*/
  msr cpsr, r0     
  
  /* init stack */
  ldr sp,_Lstack_end
                                   
  /* setup system clocks */
  ldr r1, =PMC_BASE

  ldr r0, = 0x0F01
  str r0, [r1,#CKGR_MOR]

osc_lp:
  ldr r0, [r1,#PMC_SR]
  tst r0, #0x01
  beq osc_lp
  
  mov r0, #0x01
  str r0, [r1,#PMC_MCKR]

  ldr r0, =0x2000bf00 | ( 124 << 16) | 12  /* 18,432 MHz * 125 / 12 */
  str r0, [r1,#CKGR_PLLAR]

pll_lp:
  ldr r0, [r1,#PMC_SR]
  tst r0, #0x02
  beq pll_lp

  /* MCK = PCK/4 */
  ldr r0, =0x0202
  str r0, [r1,#PMC_MCKR]

mck_lp:
  ldr r0, [r1,#PMC_SR]
  tst r0, #0x08
  beq mck_lp

  /* Enable caches */
  mrc p15, 0, r0, c1, c0, 0 
  orr r0, r0, #(0x1 <<12) 
  orr r0, r0, #(0x1 <<2)
  mcr p15, 0, r0, c1, c0, 0 

.global _main
/* main program */
_main:
  .equ PMC_BASE, 0xFFFFFC00      /* Power Manag. Controller Base Addr.*/
  .equ PMC_PCER, 0x10                  /* Peripheral Clock Enable Register */
  .equ PIOC_BASE, 0xFFFFF800
  .equ PIO_PER, 0x00
  .equ PIO_OER, 0x10
  .equ PIO_SODR, 0x30
  .equ PIO_CODR, 0x34
  
  .equ PIOA_BASE, 0xFFFFF400
  .equ PIO_PDR, 0x0004
  .equ PIO_ASR, 0x0070
  .equ PIO_SODR, 0x0030
  .equ PIO_CODR, 0x0034
  
  .equ TC0_BASE, 0xFFFA0000        /* TC0 Channel Registers */
  .equ TC1_BASE, 0xFFFA0040        /* TC1 Channel Registers */
  
  .equ TC_IMR, 0x02C                /* TC0 Interrupt Mask Register */
  .equ TC_IER, 0x24                    /* TC0 Interrupt Enable Register*/
  .equ TC_RC, 0x1C                    /* TC0 Register C */
  .equ TC_RA, 0x14                    /* TC0 Register A */
  .equ TC_CMR, 0x04                /* TC0 Channel Mode Register (Capture Mode / Waveform Mode */
  .equ TC_IDR, 0x28                  /* TC0 Interrupt Disable Register */
  .equ TC_SR, 0x20                    /* TC0 Status Register */
  .equ TC_RB, 0x18                    /* TC0 Register B */
  .equ TC_CV, 0x10                    /* TC0 Counter Value */
  .equ TC_CCR, 0x00                  /* TC0 Channel Control Register */

  .equ DBGU_BASE, 0xFFFFF200	/* Debug Unit Base Address */
  .equ DBGU_CR, 0x00  		/* DBGU Control Register */
  .equ DBGU_MR, 0x04	  	/* DBGU Mode Register*/
  .equ DBGU_IER, 0x08		/* DBGU Interrupt Enable Register*/
  .equ DBGU_IDR, 0x0C		/* DBGU Interrupt Disable Register */
  .equ DBGU_IMR, 0x10		/* DBGU Interrupt Mask Register */
  .equ DBGU_SR,   0x14		/* DBGU Status Register */
  .equ DBGU_RHR, 0x18		/* DBGU Receive Holding Register */
  .equ DBGU_THR, 0x1C		/* DBGU Transmit Holding Register */
  .equ DBGU_BRGR, 0x20		/* DBGU Baud Rate Generator Register */

/* user code here */

/* INITIALIZE */
  bl INIT_LED
  bl INIT_TC0
  bl INIT_TC1
  bl INIT_BUZZER
  bl DEBUG_INIT
   
  ldr r0, =start_msg
  bl SNDS_DEBUG

/*  MAIN START  */
LOOP: 
  bl RCV_DEBUG
  cmp r2, #0x2f       /* Check if char is "/" */
  
  
  bne SKIP0
  ldr r2, =10
  bl SND_DEBUG
  ldr r2, =0x2f 
  bl SND_DEBUG 
  bl COMMAND_CATCH

  /* is for sure not a command */
  
  SKIP0:
  bl SND_DEBUG

  
  bl ADD_NOTE
  
  bl NOTE_FREQ
  bl BUZZ
  b LOOP

/* end user code */

_wait_for_ever:
  b _wait_for_ever

/*  FUNCTIONS  */

/* DBGU */
DEBUG_INIT:
  stmfd r13!, {r0, r1, r14}
  ldr r0, =DBGU_BASE
@      mov r1, #26        @  BR=115200
  mov r1, #156        @  BR=19200
  str r1, [r0, #DBGU_BRGR]
  mov r1, #(1 << 11)
  str r1, [r0, #DBGU_MR]
  mov r1, #0b1010000
  str r1, [r0, #DBGU_CR]
  ldmfd r13!, {r0, r1, pc}

RCV_DEBUG:
  stmfd r13!, {r0, r1, r14}
  ldr r1, =DBGU_BASE
RCVD_LP:
  ldr r0, [r1, #DBGU_SR]
  tst r0, #1
  beq RCVD_LP
  ldr r2, [r1, #DBGU_RHR]
  ldmfd r13!, {r0, r1, pc}

SND_DEBUG:
  stmfd r13!, {r1, r3, r14}
  ldr r1, =DBGU_BASE
SNDD_LP:
  ldr r3, [r1, #DBGU_SR]
  tst r3, #(1 << 1)
  beq SNDD_LP
  str r2, [r1, #DBGU_THR]
  ldmfd r13!, {r1, r3, pc}

SNDS_DEBUG:
  stmfd r13!, {r0, r2, r14}
SNDSD_LP:
  ldrb r2, [r0], #1
  cmp r2, #0
  beq SNDD_END
  bl SND_DEBUG
  b SNDSD_LP
SNDD_END:
  ldmfd r13!, {r0, r2, pc}
  
COMMAND_CATCH:
  stmfd r13!, {r0, r1, r2}
  
  ldr r0, =Command
  CONTINUE_READING:
  bl RCV_DEBUG
  bl SND_DEBUG
  strb r2, [r0]
  add r0, r0, #1
  cmp r2, #13   /* IS ENTER? */
  bne CONTINUE_READING
  
  ldr r2, =10
  bl SND_DEBUG
  /* PRINT NEWLINE */
  
  ldr r0, =Command
  ldr r1, [r0]
  ldr r2, =0x706C6568
  cmp r1, r2  /* IF r1=="help" */
  bleq COMMAND_HELP 
  ldr r2, =0x65766173
  cmp r1, r2  /* IF r1=="save" */
  bleq COMMAND_SAVE
  ldr r2, =0x79616C70
  cmp r1, r2  /* IF r1=="play" */
  bleq COMMAND_PLAY
  ldr r2, =0x0D726C63
  cmp r1, r2  /* IF r1=="clr" */
  bleq COMMAND_CLEAR
  ldr r2, =0x74697571
  cmp r1, r2  /* IF r1=="quit" */
  bleq COMMAND_QUIT
  
  ldmfd r13!, {r0, r1, r2}
  b LOOP


  
COMMAND_HELP:
  stmfd r13!, {r0, r14}
  
  ldr r0, =help_msg
  bl SNDS_DEBUG
  
  ldmfd r13!, {r0, pc}
  
COMMAND_SAVE:
  stmfd r13!, {r0, r1, r2, r3, r14}
  
  ldr r0, =save_msg
  bl SNDS_DEBUG
  
  ldr r0, =Saved_melody
  ldr r1, =Current_melody
  mov r2, #0
  SAVE_BACK:
  ldrb r3, [r1]
  strb r3, [r0]
  strb r2, [r1]
  add r0, r0, #1
  add r1, r1, #1
  cmp r3, #0
  bne SAVE_BACK  
 
  ldr r0, =Num_saved
  ldr r1, =Num_played
  ldrb r3, [r1]
  strb r2, [r1]
  strb r3, [r0]

  
  ldmfd r13!, {r0, r1, r2, r3, pc}
  
COMMAND_PLAY:
  stmfd r13!, {r0, r1, r2, r14}
  
  ldr r0, =Saved_melody
  ldr r1, =Num_saved
  ldrb r1, [r1]
  COMMAND_PLAYback:
  subs r1, r1, #1
  blt COMMAND_PLAYend
  ldrb r2, [r0]
  add r0, r0, #1
  bl NOTE_FREQ
  bl BUZZ
  b COMMAND_PLAYback
  
  COMMAND_PLAYend:
  bl BUZZER_OFF
  
  ldmfd r13!, {r0, r1, r2, pc}
  
COMMAND_CLEAR:
  stmfd r13!, {r0, r1, r2, r3, r14}
  
  ldr r3, =Num_saved
  ldrb r1, [r3]
  ldr r0, =Saved_melody
  mov r2, #0
  
  COMMAND_CLEARback:

  subs r1, r1, #1
  strb r2, [r0, r1]

  bhi COMMAND_CLEARback
  
  strb r2, [r3]

  ldmfd r13!, {r0, r1, r2, r3, pc} 
  
COMMAND_QUIT:
  b _wait_for_ever

/* DBGU END */
      
      
/*  MAKE A 1s BUZZ WITH FREQUENCY[HZ] in r2  */
BUZZ:
  stmfd r13!, {r0, r1, r2, r3, r4, r14}   
  
  /* start timer for buzz */
  ldr r3, =TC1_BASE
  mov r0, #0b0101      /*TC_CLKEN,TC_SWTRG*/
  ldr r1, [r3, #TC_SR]    /* READ TC_SR REGISTER FOR THE BIT 4 RESET */
  str r0, [r3, #TC_CCR] 
  
  BACK:
  bl BUZZER_ON
  bl LED_ON
  mov r0, r2
  bl DELAY_TC0

  bl BUZZER_OFF
  bl LED_OFF
  mov r0, r2
  bl DELAY_TC0

  ldr r1, [r3, #TC_SR]
  tst r1, #1 << 4                             /* CPCS Flag ?*/
  beq BACK
  
  mov r0, #4000
  bl DELAY_TC0
  
  ldmfd r13!, {r0, r1, r2, r3, r4, r14}

/*  START LIGHT  */
INIT_LED:
  stmfd r13!, {r0, r2, r14}
  ldr r2, =PIOC_BASE
  mov r0, #1 << 1
  str r0, [r2, #PIO_PER]
  str r0, [r2, #PIO_OER]
  ldmfd r13!, {r0, r2, pc}

LED_ON:
  stmfd r13!, {r0, r2, r14}
  ldr r2, =PIOC_BASE
  mov r0, #1 << 1
  str r0, [r2, #PIO_CODR]
  ldmfd r13!, {r0, r2, pc}

LED_OFF:
  stmfd r13!, {r0, r2, r14}
  ldr r2, =PIOC_BASE
  mov r0, #1 << 1
  str r0, [r2, #PIO_SODR]
  ldmfd r13!, {r0, r2, pc} 
  
/*  END LIGHT  */
 
/*  START BUZZER  */
INIT_BUZZER:
  stmfd r13!, {r0, r1, r14}
  
  mov r1, #0b1 << 26
  ldr r0, =PIOA_BASE
  
  str r1, [r0, #PIO_PER]
  str r1, [r0, #PIO_OER]
  
  ldmfd r13!, {r0, r1, r15}
  
BUZZER_ON:
  stmfd r13!, {r0, r1, r14}
  
  ldr r0, =PIOA_BASE
  mov r1, #0b1 << 26
  str r1, [r0, #PIO_SODR]
    
  ldmfd r13!, {r0, r1, pc}

BUZZER_OFF:
  stmfd r13!, {r14}
  
  ldr r0, =PIOA_BASE
  mov r1, #0b1 << 26
  str r1, [r0, #PIO_CODR]
    
  ldmfd r13!, {pc}
  
/* END BUZZER */


/* TIMER/COUNTER -s */
INIT_TC0:
  stmfd r13!, {r0, r2, r14}
  ldr r2, =PMC_BASE    /*Enable PMC for TC0 */
  mov r0, #(1 << 17)
  str r0, [r2,#PMC_PCER]

  /*Initialize TC0 MCK/2, RC=24 (1 ?s) */
  ldr r2, =TC0_BASE
  mov r0, #0b110 << 13 /*WAVE=1, WAVSEL= 10*/
  add r0, r0, #0b000            /* MCK/2 */
  str r0, [r2, #TC_CMR]
  ldr r0, =375
  str r0, [r2, #TC_RC]
  mov r0, #0b0101      /*TC_CLKEN,TC_SWTRG*/
  str r0, [r2, #TC_CCR]
  ldmfd r13!, {r0, r2, r15}
  
INIT_TC1:
  stmfd r13!, {r0, r2, r14}
  ldr r2, =PMC_BASE    /*Enable PMC for TC1 */
  mov r0, #(1 << 18)
  str r0, [r2,#PMC_PCER]

  /*Initialize TC1 SLCK, RC=16384 (0.5s) */
  ldr r2, =TC1_BASE
  mov r0, #0b110 << 13 /*WAVE=1, WAVSEL= 10*/
  add r0, r0, #0b100           /* SLCK = 32768Hz */
  str r0, [r2, #TC_CMR]
  ldr r0, =16384                      /* 0.5s at 32768Hz */
  str r0, [r2, #TC_RC]
  /* mov r0, #0b0101 */   
  /* TC_CLKEN,TC_SWTRG */ 
  /* str r0, [r2, #TC_CCR] */
  ldmfd r13!, {r0, r2, r15}
  


DELAY_TC0:
  stmfd r13!, {r1, r2, r14}
  ldr r2, =TC0_BASE

DLP_TC0:  
  ldr r1, [r2, #TC_SR]
  tst r1, #1 << 4                              /* CPCS Flag ?*/
  beq DLP_TC0

  subs r0, r0, #1
  bne DLP_TC0
  ldmfd r13!, {r1, r2, r15}
  
DELAY_TC1:
  stmfd r13!, {r1, r2, r14}
  ldr r2, =TC1_BASE

DLP_TC1:  
  ldr r1, [r2, #TC_SR]
  tst r1, #1 << 4                              /* CPCS Flag ?*/
  beq DLP_TC1
  ldmfd r13!, {r1, r2, r15}
  

/* DELAY SETUP */

NOTE_FREQ:
/*
note given with char in r2
return freq in r2
*/
  stmfd r13!, {r0, r1, r14}
  
  cmp r2, #0x63
  ldreq r2, =45
  beq FREQ_END
  
  cmp r2, #0x64
  ldreq r2, =41
  beq FREQ_END
  
  cmp r2, #0x65
  ldreq r2, =37
  beq FREQ_END
  
  cmp r2, #0x66
  ldreq r2, =36
  beq FREQ_END
  
  cmp r2, #0x67
  ldreq r2, =33
  beq FREQ_END
  
  cmp r2, #0x61
  ldreq r2, =30
  beq FREQ_END
  
  cmp r2, #0x68
  ldreq r2, =27
  beq FREQ_END
  
  cmp r2, #0x5f
  ldreq r2, =1
  beq FREQ_END
  
  ldr r2, =1
  
  FREQ_END:
   

  ldmfd r13!, {r0, r1, pc} 
  
ADD_NOTE:
  stmfd r13!, {r0, r1, r14}
  
  ldr r0, =Num_played
  ldrb r1, [r0]
  
  ldr r0, =Current_melody
  strb r2, [r0, r1]
  
  add r1, r1, #1
  ldr r0, =Num_played
  strb r1, [r0]
  
  ldmfd r13!, {r0, r1, pc}


/* constants */
.align
start_msg: .asciz "Type a character from \"c,d,e,f,g,a,h,\_\" where the letters represent notes and \"\_\" represents a pause.\nWrite \"\/help\" for command list.\n"

.align
help_msg: .asciz "\"/help\" for command list\n\"/save\" to append the melody just played to saved melody \n\"/play\" to play the melody\n\"/clr\" for saved melody clear\n\"/quit\" to quit the program\n"

.align
save_msg: .asciz "Played melody has been saved! Type \"/play\" to play it back\n"

.align
Command: .space 5

.align 
Received: .asciz "" 

.align
Saved_melody: .space 100

.align
Current_melody: .space 100

.align
Num_played: .byte 0

.align
Num_saved: .byte 0                                                                    

.align

_Lstack_end:
  .long __STACK_END__

.end

