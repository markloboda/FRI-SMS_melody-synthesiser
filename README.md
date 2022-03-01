<!DOCTYPE html>
<html>
<head>
<style>
h1 {
    position: absolute;
    top: 40%
}
#author {
    position: absolute;
    top: 50%
}
img {
    display: block;
    margin-left: auto;
    margin-right: auto;
}
</style>
<link rel="stylesheet" type="text/css" href="mystyle.css">
</head>
<body>

<h1><b>Sintetizator melodij na mikrokrmilniku <br>
FRI-SMS</h1>
<h2 id="author">Avtor: Mark Loboda</h2>

<img src="logo.png" style="margin-top:10%;">

</body>
</html>


<div style="page-break-after: always;"></div>

## 1. Uvod
S pomočjo vezja FRI-SMS sem realiziral sintetizator melodije, ki komunicira preko RS232 povezave. Uporabil sem mikro krmilnik FRI-SMS in piskač. Note sem s pomočjo piskača zaigral tako, da sem spreminjal razmerje časa med piskom in ne piskom.

## 2. Uporaba
Najprej se uporabniku izpiše začetno sporočilo, ki mu poda napotke.
<img src="./img1.png"> 
*<p style="font-size:12px">Slika1: Začetno sporočilo</p>*
Nato lahko začne vpisovati melodijo. Lahko izbira med "**c**", "**d**", "**e**", "**f**", "**g**", "**a**", "**h**" in pa "**_**", ki pa pomeni premor. Lahko pa vpiše tudi v naprej določene ukaze. Za prikaz teh ukazov mora v terminal vpisati "/help". Vsak ukaz se začne z znakom "/", potrditev vnosa pa se naredi z pritiskom na "ENTER".
<img src="./img2.png"> 
*<p style="font-size:12px">Slika2: Sporočilo /help</p>*

<div style="page-break-after: always;"></div>

Uporabnik lahko vnese neko zaporedje tonov, katere se mu med vnašanjem igrajo.
<img src="./img3.png"> 
*<p style="font-size:12px">Slika3: Primer melodije</p>*

Po vnešeni melodiji ima možnost sharanjevanja te melodije. Vpiše ukaz "/save". Če ima uporabnik že shranjeno neko melodijo, jo ta ukaz izbriše in shrani
<img src="./img4.png"> 
*<p style="font-size:12px">Slika4: Shranjevanje melodije</p>*

Ko ima neko melodijo shranjeno, vpiše ukaz "/play" in se mu ta melodija ponovno zaigra. To lahko stori večkrat.
Možnost ima pa tudi brisanja te melodije z ukazom "/clr".
Ko uporabnik hoče zaključiti izvajanje, vpiše ukaz "/quit".

## 3. Predstavitev kode programa
Program se začne z inicializacijo vseh komponent. Inicializira se TC0, TC1, LED lučka, BUZZER in enota DBGU.
Nato se zgodi izpis začetnega sporočila.

Nato pa se začne glavna zanka programa. Najprej program čaka na nek vnos v terminal. To naredi v funkciji RCV_DEBUG. Ko prejme nek znak, najprej preveri, če ima dobljen znak ASCII kodo *0x2f*. To je znak **/**. V tem primeru v terminal izpiše znak *\n*, kar pomeni, da gre v novo vrstico in izvede funkcijo COMMAND_CATCH.
V funkciji COMMAND_CATCH nato počaka, da uporabnik vnese nek ukaz. Ukaz uporabnik potrdi z pritiskom gumba ENTER. Ko pritisne enter se najprej v terminal izpiše *\n*. Nato pa se preveri, če je ukaz enak kateremu od vnaprej določenih. Vsebuje ukaze: /help, /save, /play, /clr, /quit.
- Ukaz /help izpiše vsebovane ukaze in kaj naredijo.
- Ukaz /save shrani nazadnje zaigrano melodijo.
- Ukaz /play zaigra shranjeno melodijo ponovno.
- Ukaz /clr počisti shranjeno melodijo.
- Ukaz /quit zaključi izvajanje programa.

Vse funkcije, ki se sprožijo pri ukazih so navedene in razložene spodaj v točki: *5. Funkcije ukazov*. Po tem pa se program vrne na začetek glavne zanke in čaka na nov vnos.

V primeru, da vnesen znak ni bil */*, se celotni del preskoči in se najprej izvede funkcija ADD_NOTE, ki trenutno zaigran ton označi in doda v pomnilnik. Nato se izvede funckija NOTE_FREQ, ki pogleda ASCII kodo znaka in na podlagi te vrne neko vrednost, ki določi ton.
Na koncu pa se izvede še funkcija BUZZ.
Funkcija *BUZZ* najprej začne časovnik za igranje note (TC1). Nato vstopi v zanko, ki se bo izvajala toliko časa, dokler časovnik TC1 ne postavi CPCS zastavice. Časovnik TC1 vedno traja 0.5s.
$$SLCK=32768Hz, RC=16384  : t=(1/32768) * 16384 = 0.5s$$ Nato kliče funkcijo BUZZER_ON, ki prižge piskač. Potem kliče DELAY_TC0, za katerega je čas čakanja določen s pomočjo vrednosti v registru r0. Časi čakanja so določeni na podlagi trenutno prebranega znaka (note). Nato se kliče funkcija BUZZER_OFF, ki piskač ugasne. Nato pa se ponovno kliče DELAY_TC0, ki počaka enako dolgo kot pri prvem klicu. Potem pa se izvede preverjanje CPCS zastavice časovnika TC1. Če zastavica ni postavljena, potem ponovno zažene del programa, kjer je BUZZER_ON, WAIT, BUZZER_OFF, WAIT.
Na koncu pa se izvede še DELAY_TC0 s konstanto 4000, da je med zaigranimi toni majhen premor.
Po izvedeni funkciji se program vrne na začetek glavne zanke programa.

<div style="page-break-after: always;"></div>

## 4. Posamezni deli kode
### 4.1. Inicializacija
```c
bl INIT_LED
bl INIT_TC0
bl INIT_TC1
bl INIT_BUZZER
bl DEBUG_INIT
```

#### 4.1.1. INIT_TC0

V tem delu se inicializira časovnik TC0. Inicializira se z nastavitvami:

- WAVE=1, WAVESEL=10
- Frekvenca urinega signala: $MCK/2 = 240000000Hz$
- $RC=24$

$$t=(1/24000000)*24=0.000001s$$

Ta časovnik torej čaka 1µs.
Poskuša doseči največjo natančnost, med tem ko je za pod enoto izbrana neka smiselna vrednost.

```c
INIT_TC0:
  stmfd r13!, {r0, r2, r14}
  ldr r2, =PMC_BASE    /*Enable PMC for TC0 */
  mov r0, #(1 << 17)
  str r0, [r2,#PMC_PCER]

  /*Initialize TC0 MCK/2, RC=24 (1 µs) */
  ldr r2, =TC0_BASE
  mov r0, #0b110 << 13           /*WAVE=1, WAVSEL= 10*/
  add r0, r0, #0b000            /* MCK/2 */
  str r0, [r2, #TC_CMR]
  ldr r0, =375
  str r0, [r2, #TC_RC]
  mov r0, #0b0101      /*TC_CLKEN,TC_SWTRG*/
  str r0, [r2, #TC_CCR]
  ldmfd r13!, {r0, r2, r15}
```
<div style="page-break-after: always;"></div>

#### 4.1.2. INIT_TC1
V tem delu se inicializira časovnik TC1. Inicializira se z nastavitvami:

- WAVE=1, WAVESEL=10
- Frekvenca urinega signala: $SLCK=32768 Hz$
- $RC=16384$

$$t=(1/32768)*16384=0.5s$$

```c
INIT_TC1:
INIT_TC1:
  stmfd r13!, {r0, r2, r14}
  ldr r2, =PMC_BASE    /*Enable PMC for TC1 */
  mov r0, #(1 << 18)
  str r0, [r2,#PMC_PCER]

  /*Initialize TC1 SLCK, RC=16384 (0.5s) */
  ldr r2, =TC1_BASE
  mov r0, #0b110 << 13          /*WAVE=1, WAVSEL= 10*/
  add r0, r0, #0b100           /* SLCK = 32768Hz */
  str r0, [r2, #TC_CMR]
  ldr r0, =16384                      /* 0.5s at 32768Hz */
  str r0, [r2, #TC_RC]
  /* mov r0, #0b0101 */   
  /* TC_CLKEN,TC_SWTRG */ 
  /* str r0, [r2, #TC_CCR] */
  ldmfd r13!, {r0, r2, r15}
```
#### 4.1.3. INIT_BUZZER
V tem delu se inicializira piskač. Na ustrezno mesto se zapiše bit 1 v registrih PIO_PER (PIO ENABLE REGISTER) in PIO_OER (PIO OUTPUT ENABLE REGISTER).

```c
INIT_BUZZER:
  stmfd r13!, {r0, r1, r14}
  
  mov r1, #0b1 << 26
  ldr r0, =PIOA_BASE
  
  str r1, [r0, #PIO_PER]
  str r1, [r0, #PIO_OER]
  
  ldmfd r13!, {r0, r1, r15}
```

<div style="page-break-after: always;"></div>

### 4.2. Glani del programa
To je glavna zanka programa, ki se ponavlja do prekinitve izvajanja. Najprej se izvede branje znaka, nato pa generira odziv glede na vpisano. Najprej preveri, če gre za ukaz, drugače pa zaigra zapisano noto.
```c
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
```

<div style="page-break-after: always;"></div>

### 4.3. Pomembnejši podprogrami
#### 4.3.1. RCV_DEBUG
V tej funkciji program čaka na vnos znaka uporabnika.
```c
RCV_DEBUG:
  stmfd r13!, {r0, r1, r14}
  ldr r1, =DBGU_BASE
RCVD_LP:
  ldr r0, [r1, #DBGU_SR]
  tst r0, #1
  beq RCVD_LP
  ldr r2, [r1, #DBGU_RHR]
  ldmfd r13!, {r0, r1, pc}
```

#### 4.3.2. SND_DEBUG
Ta funkcija izpiše znak v terminal.
```c
SND_DEBUG:
  stmfd r13!, {r1, r3, r14}
  ldr r1, =DBGU_BASE
SNDD_LP:
  ldr r3, [r1, #DBGU_SR]
  tst r3, #(1 << 1)
  beq SNDD_LP
  str r2, [r1, #DBGU_THR]
  ldmfd r13!, {r1, r3, pc}
```

<div style="page-break-after: always;"></div>

#### 4.3.3. COMMAND_CATCH
Ta funkcija najprej počaka, da uporabnik vnese nek ukaz. Pravzaprav v zanki bere zapisane znake, branje pa prekini, ko uporabnik pritisne gumb ENTER. Nato pa se izvede preverjanje zapisanega. Če pride do ujemanja, se izvede primerna funkcija za določen ukaz. Če ukaz ni najden, pa vrne vse registre na prejsnje stanje in skoči na začetek glavne zanke.
```c
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
```

<div style="page-break-after: always;"></div>

#### 4.3.4. Določanje čakanja; NOTE_FREQ
Naloga te funkcije je določati čas čakanja TC0 v funkciji BUZZ. Primerja vnesen znak z njihovo ASCII kodo in če pride do ujemanja zapiše v register r2 vrednost čakanja. Nato bo TC0 čakal toliko mikrosekund, kot je vnesena vrednost.

```c
NOTE_FREQ:
/*
note given with char in r2
return freq in r2
*/
  stmfd r13!, {r14}
  
  cmp r2, #0x0
  beq PLAY_MELODY
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
  
  FREQ_END:
  ldmfd r13!, {pc}
```

<div style="page-break-after: always;"></div>

#### 4.3.5. BUZZER_ON
Piskač se prižge z vpisom bita 1 na ustrezno mesto v registru PIO_SODR (Set Output Data Register).
```c
BUZZER_ON:
  stmfd r13!, {r0, r1, r14}
  
  ldr r0, =PIOA_BASE
  mov r1, #0b1 << 26
  str r1, [r0, #PIO_SODR]
    
  ldmfd r13!, {r0, r1, pc}
```

Prav tako program vsebuje BUZZER_OFF funkcijo, ki deluje enako kot BUZZER_ON, le da je vnesen bit 0.

#### 4.3.6. ADD_NOTE

```c
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
```

<div style="page-break-after: always;"></div>

#### 4.3.7. BUZZ
Ta funkcija je za samo igranje tonov. Potek le te je razložen zgoraj v točki 3.

```c
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
```



<div style="page-break-after: always;"></div>

### 5. Funkcije ukazov
#### 5.1. COMMAND_HELP
Je preprosta funkcija, ki izpiše sporočilo, zapisano v pomnilniku.
```c
COMMAND_HELP:
  stmfd r13!, {r0, r14}
  
  ldr r0, =help_msg
  bl SNDS_DEBUG
  
  ldmfd r13!, {r0, pc}
```

#### 5.2. COMMAND_SAVE
Je funkcija, ki shrani nazandnje zaigrano melodijo. Najprej izpiše sporočilo. Nato pa prepiše znake zapisanje v pomnilniku pod imenom *Current_melody* v pomnilnik pod imenom *Saved_melody*.
```c
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
```

#### 5.3. COMMAND_PLAY
Je funkcija, ki gre čez znake zapisane v pomnilniku pod imenom *Saved_melody* in jih zaigra.

```c
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
```
#### 5.4 COMMAND_CLEAR
Je funkcija, ki pobriše znake zapisane pod imenom *Saved_melody*.
```c
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
```
#### 5.5 COMMAND_QUIT
Zaključek izvajanja programa.
```c
COMMAND_QUIT:
  b _wait_for_ever
```
