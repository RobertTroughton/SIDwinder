
.var music = LoadSid ("/Users/olima/C64_Resources/Human_Race.sid")
* = music.location "Music"
.fill music.size, music.getData (i)

BasicUpstart2(start)

*=$4000 "Main PRG"
 
.label screen = $0400
.label dummy =  $07f5

.label areg =       $13
.label yreg =       $14
.label xreg =       $15

.label sinecount  = $17
.label sinecount2 = $18
.label sinecount3 = $19

///////////////////////////////////// setup
start:   
sei   
lda #$35
sta $01 
 
lda #0
sta sinecount
lda #20
sta sinecount2
lda #40
sta sinecount3

lda #$00
sta $d020
sta $d021
sta $d026
sta $d01b
sta $d027 ; sta $d028 ; sta $d029 ; sta $d02a ; sta $d02b ; sta $d02c ; sta $d02d
jsr music.init

lda #$0c
sta $d022
sta $d025
lda #$0b
sta $d023

lda #%00000011
sta $3fff


///////////////////////////////////// setup sprites
lda #%01111111 
sta $d015
sta $d01d
sta $d017
sta $d01c

lda #$fa
sta $d001 ; sta $d003 ; sta $d005 ; sta $d007 ; sta $d009 ; sta $d00b ; sta $d00d

lda #$18
clc
sta $d000 ; adc #$30 ; sta $d002 ; adc #$30 ; sta $d004 ; adc #$30 ; sta $d006
adc #$30 ; sta $d008 ; adc #$30 ; sta $d00a ; clc ; adc #$30 ; sta $d00c

lda #%01100000
sta $d010

lda #sprite/64
sta $07f8 ; sta $07f9 ; sta $07fa ; sta $07fb ; sta $07fc ; sta $07fd ; sta $07fe


///////////////////////////////////// set charcolors
ldy #0
colorfill:
lda #$0B
sta $d800,Y
sta $d840,Y
lda #$0f
sta $d940,y
sta $d980,y
lda #$09
sta $da80,Y
sta $db00,Y
iny
bne colorfill


lda #$7b                // blank screen
sta $d011
lda #%11011000          // MC on
sta $d016
lda #%00011000          // charset $2000, videoram $0400
sta $d018


///////////////////////////////////// display row 25
ldy #00
lastrow:
lda #$0e
sta screen+960,Y
iny
lda #$0f
sta screen+960,Y
iny
cpy #40
bne lastrow


.label irq01 = $f8
///////////////////////////////////// irq setup
lda #$7f
sta $dc0d  
sta $dd0d 
lda $dc0d  
lda $dd0d 

bit $d011               
bpl *-3
bit $d011
bmi *-3

lda #$1b
sta $d011

lda #irq01
sta $d012

lda #<irq
sta $fffe
lda #>irq
sta $ffff

lda #$f1               
sta $d01a
lda #0
sta $dc0e
cli 

idleloop:
jmp idleloop


///////////////////////////////////// irq
irq:
sta areg ; sty yreg ; stx xreg

lda #%00010011              // open border
sta $d011

ldy #$0b

lda #$fa
cmp $d012
bne *-3

inc dummy ; inc dummy ; inc dummy ; inc dummy ; inc dummy ; inc dummy ; inc dummy ; inc dummy

sty $d021

jsr columnseffect
jsr sinecopy            // fill columnbuffer with sinedata
jsr music.play

asl $d019
lda #irq01
sta $d012
lda areg ; ldy yreg ; ldx xreg
rti


///////////////////////////////////// copy new sinedata to columnbuffer
sinecopy:
ldy sinecount
ldx #19
sineloop:
lda sine,Y
sta sinebuffer,x
iny
dex
bpl sineloop
inc sinecount

ldy sinecount2
ldx #19
sineloop2:
lda sine,Y
sta sinebuffer2,x
iny
dex
bpl sineloop2
inc sinecount2

ldy sinecount3
ldx #19
sineloop3:
lda sine,Y
sta sinebuffer3,x
iny
dex
bpl sineloop3
inc sinecount3

rts


///////////////////////////////////// columns effect

columnseffect:

////////////// every section = 1 column
ldy sinebuffer
ldx convtable,Y
clc
lda upper+00,X
sta screen +00 +00
adc #1
sta screen +01 +00

lda upper+01,X
sta screen +00 +40
adc #1
sta screen +01 +40

lda upper+02,X
sta screen +00 +80
adc #1
sta screen +01 +80

lda upper+03,X
sta screen +00 +120
adc #1
sta screen +01 +120

lda upper+04,X
sta screen +00 +160
adc #1
sta screen +01 +160

lda upper+05,X
sta screen +00 +200
adc #1
sta screen +01 +200

lda upper+06,X
sta screen +00 +240
adc #1
sta screen +01 +240

lda upper+07,X
sta screen +00 +280
adc #1
sta screen +01 +280

//////////////
ldy sinebuffer+1
ldx convtable,Y
clc
lda upper+00,X
sta screen +02 +00
adc #1
sta screen +03 +00

lda upper+01,X
sta screen +02 +40
adc #1
sta screen +03 +40

lda upper+02,X
sta screen +02 +80
adc #1
sta screen +03 +80

lda upper+03,X
sta screen +02 +120
adc #1
sta screen +03 +120

lda upper+04,X
sta screen +02 +160
adc #1
sta screen +03 +160

lda upper+05,X
sta screen +02 +200
adc #1
sta screen +03 +200

lda upper+06,X
sta screen +02 +240
adc #1
sta screen +03 +240

lda upper+07,X
sta screen +02 +280
adc #1
sta screen +03 +280

//////////////
ldy sinebuffer+2
ldx convtable,Y
clc
lda upper+00,X
sta screen +04 +00
adc #1
sta screen +05 +00

lda upper+01,X
sta screen +04 +40
adc #1
sta screen +05 +40

lda upper+02,X
sta screen +04 +80
adc #1
sta screen +05 +80

lda upper+03,X
sta screen +04 +120
adc #1
sta screen +05 +120

lda upper+04,X
sta screen +04 +160
adc #1
sta screen +05 +160

lda upper+05,X
sta screen +04 +200
adc #1
sta screen +05 +200

lda upper+06,X
sta screen +04 +240
adc #1
sta screen +05 +240

lda upper+07,X
sta screen +04 +280
adc #1
sta screen +05 +280

//////////////
ldy sinebuffer+3
ldx convtable,Y
clc
lda upper+00,X
sta screen +06 +00
adc #1
sta screen +07 +00

lda upper+01,X
sta screen +06 +40
adc #1
sta screen +07 +40

lda upper+02,X
sta screen +06 +80
adc #1
sta screen +07 +80

lda upper+03,X
sta screen +06 +120
adc #1
sta screen +07 +120

lda upper+04,X
sta screen +06 +160
adc #1
sta screen +07 +160

lda upper+05,X
sta screen +06 +200
adc #1
sta screen +07 +200

lda upper+06,X
sta screen +06 +240
adc #1
sta screen +07 +240

lda upper+07,X
sta screen +06 +280
adc #1
sta screen +07 +280

//////////////
ldy sinebuffer+4
ldx convtable,Y
clc
lda upper+00,X
sta screen +08 +00
adc #1
sta screen +09 +00

lda upper+01,X
sta screen +08 +40
adc #1
sta screen +09 +40

lda upper+02,X
sta screen +08 +80
adc #1
sta screen +09 +80

lda upper+03,X
sta screen +08 +120
adc #1
sta screen +09 +120

lda upper+04,X
sta screen +08 +160
adc #1
sta screen +09 +160

lda upper+05,X
sta screen +08 +200
adc #1
sta screen +09 +200

lda upper+06,X
sta screen +08 +240
adc #1
sta screen +09 +240

lda upper+07,X
sta screen +08 +280
adc #1
sta screen +09 +280

//////////////
ldy sinebuffer+5
ldx convtable,Y
clc
lda upper+00,X
sta screen +10 +00
adc #1
sta screen +11 +00

lda upper+01,X
sta screen +10 +40
adc #1
sta screen +11 +40

lda upper+02,X
sta screen +10 +80
adc #1
sta screen +11 +80

lda upper+03,X
sta screen +10 +120
adc #1
sta screen +11 +120

lda upper+04,X
sta screen +10 +160
adc #1
sta screen +11 +160

lda upper+05,X
sta screen +10 +200
adc #1
sta screen +11 +200

lda upper+06,X
sta screen +10 +240
adc #1
sta screen +11 +240

lda upper+07,X
sta screen +10 +280
adc #1
sta screen +11 +280

//////////////
ldy sinebuffer+6
ldx convtable,Y
clc
lda upper+00,X
sta screen +12 +00
adc #1
sta screen +13 +00

lda upper+01,X
sta screen +12 +40
adc #1
sta screen +13 +40

lda upper+02,X
sta screen +12 +80
adc #1
sta screen +13 +80

lda upper+03,X
sta screen +12 +120
adc #1
sta screen +13 +120

lda upper+04,X
sta screen +12 +160
adc #1
sta screen +13 +160

lda upper+05,X
sta screen +12 +200
adc #1
sta screen +13 +200

lda upper+06,X
sta screen +12 +240
adc #1
sta screen +13 +240

lda upper+07,X
sta screen +12 +280
adc #1
sta screen +13 +280

//////////////
ldy sinebuffer+7
ldx convtable,Y
clc
lda upper+00,X
sta screen +14 +00
adc #1
sta screen +15 +00

lda upper+01,X
sta screen +14 +40
adc #1
sta screen +15 +40

lda upper+02,X
sta screen +14 +80
adc #1
sta screen +15 +80

lda upper+03,X
sta screen +14 +120
adc #1
sta screen +15 +120

lda upper+04,X
sta screen +14 +160
adc #1
sta screen +15 +160

lda upper+05,X
sta screen +14 +200
adc #1
sta screen +15 +200

lda upper+06,X
sta screen +14 +240
adc #1
sta screen +15 +240

lda upper+07,X
sta screen +14 +280
adc #1
sta screen +15 +280

//////////////
ldy sinebuffer+8
ldx convtable,Y
clc
lda upper+00,X
sta screen +16 +00
adc #1
sta screen +17 +00

lda upper+01,X
sta screen +16 +40
adc #1
sta screen +17 +40

lda upper+02,X
sta screen +16 +80
adc #1
sta screen +17 +80

lda upper+03,X
sta screen +16 +120
adc #1
sta screen +17 +120

lda upper+04,X
sta screen +16 +160
adc #1
sta screen +17 +160

lda upper+05,X
sta screen +16 +200
adc #1
sta screen +17 +200

lda upper+06,X
sta screen +16 +240
adc #1
sta screen +17 +240

lda upper+07,X
sta screen +16 +280
adc #1
sta screen +17 +280

//////////////
ldy sinebuffer+9
ldx convtable,Y
clc
lda upper+00,X
sta screen +18 +00
adc #1
sta screen +19 +00

lda upper+01,X
sta screen +18 +40
adc #1
sta screen +19 +40

lda upper+02,X
sta screen +18 +80
adc #1
sta screen +19 +80

lda upper+03,X
sta screen +18 +120
adc #1
sta screen +19 +120

lda upper+04,X
sta screen +18 +160
adc #1
sta screen +19 +160

lda upper+05,X
sta screen +18 +200
adc #1
sta screen +19 +200

lda upper+06,x
sta screen +18 +240
adc #1
sta screen +19 +240

lda upper+07,X
sta screen +18 +280
adc #1
sta screen +19 +280

//////////////
ldy sinebuffer+10
ldx convtable,Y
clc
lda upper+00,X
sta screen +20 +00
adc #1
sta screen +21 +00

lda upper+01,X
sta screen +20 +40
adc #1
sta screen +21 +40

lda upper+02,X
sta screen +20 +80
adc #1
sta screen +21 +80

lda upper+03,X
sta screen +20 +120
adc #1
sta screen +21 +120

lda upper+04,X
sta screen +20 +160
adc #1
sta screen +21 +160

lda upper+05,X
sta screen +20 +200
adc #1
sta screen +21 +200

lda upper+06,x
sta screen +20 +240
adc #1
sta screen +21 +240

lda upper+07,X
sta screen +20 +280
adc #1
sta screen +21 +280

//////////////
ldy sinebuffer+11
ldx convtable,Y
clc
lda upper+00,X
sta screen +22 +00
adc #1
sta screen +23 +00

lda upper+01,X
sta screen +22 +40
adc #1
sta screen +23 +40

lda upper+02,X
sta screen +22 +80
adc #1
sta screen +23 +80

lda upper+03,X
sta screen +22 +120
adc #1
sta screen +23 +120

lda upper+04,X
sta screen +22 +160
adc #1
sta screen +23 +160

lda upper+05,X
sta screen +22 +200
adc #1
sta screen +23 +200

lda upper+06,x
sta screen +22 +240
adc #1
sta screen +23 +240

lda upper+07,X
sta screen +22 +280
adc #1
sta screen +23 +280

//////////////
ldy sinebuffer+12
ldx convtable,Y
clc
lda upper+00,X
sta screen +24 +00
adc #1
sta screen +25 +00

lda upper+01,X
sta screen +24 +40
adc #1
sta screen +25 +40

lda upper+02,X
sta screen +24 +80
adc #1
sta screen +25 +80

lda upper+03,X
sta screen +24 +120
adc #1
sta screen +25 +120

lda upper+04,X
sta screen +24 +160
adc #1
sta screen +25 +160

lda upper+05,X
sta screen +24 +200
adc #1
sta screen +25 +200

lda upper+06,x
sta screen +24 +240
adc #1
sta screen +25 +240

lda upper+07,X
sta screen +24 +280
adc #1
sta screen +25 +280

//////////////
ldy sinebuffer+13
ldx convtable,Y
clc
lda upper+00,X
sta screen +26 +00
adc #1
sta screen +27 +00

lda upper+01,X
sta screen +26 +40
adc #1
sta screen +27 +40

lda upper+02,X
sta screen +26 +80
adc #1
sta screen +27 +80

lda upper+03,X
sta screen +26 +120
adc #1
sta screen +27 +120

lda upper+04,X
sta screen +26 +160
adc #1
sta screen +27 +160

lda upper+05,X
sta screen +26 +200
adc #1
sta screen +27 +200

lda upper+06,x
sta screen +26 +240
adc #1
sta screen +27 +240

lda upper+07,X
sta screen +26 +280
adc #1
sta screen +27 +280

//////////////
ldy sinebuffer+14
ldx convtable,Y
clc
lda upper+00,X
sta screen +28 +00
adc #1
sta screen +29 +00

lda upper+01,X
sta screen +28 +40
adc #1
sta screen +29 +40

lda upper+02,X
sta screen +28 +80
adc #1
sta screen +29 +80

lda upper+03,X
sta screen +28 +120
adc #1
sta screen +29 +120

lda upper+04,X
sta screen +28 +160
adc #1
sta screen +29 +160

lda upper+05,X
sta screen +28 +200
adc #1
sta screen +29 +200

lda upper+06,x
sta screen +28 +240
adc #1
sta screen +29 +240

lda upper+07,X
sta screen +28 +280
adc #1
sta screen +29 +280

//////////////
ldy sinebuffer+15
ldx convtable,Y
clc
lda upper+00,X
sta screen +30 +00
adc #1
sta screen +31 +00

lda upper+01,X
sta screen +30 +40
adc #1
sta screen +31 +40

lda upper+02,X
sta screen +30 +80
adc #1
sta screen +31 +80

lda upper+03,X
sta screen +30 +120
adc #1
sta screen +31 +120

lda upper+04,X
sta screen +30 +160
adc #1
sta screen +31 +160

lda #%00011011                                  //close border & reset d021
sta $d011
lda #0
sta $d021

lda upper+05,X
sta screen +30 +200
adc #1
sta screen +31 +200

lda upper+06,x
sta screen +30 +240
adc #1
sta screen +31 +240

lda upper+07,X
sta screen +30 +280
adc #1
sta screen +31 +280

//////////////
ldy sinebuffer+16
ldx convtable,Y
clc
lda upper+00,X
sta screen +32 +00
adc #1
sta screen +33 +00

lda upper+01,X
sta screen +32 +40
adc #1
sta screen +33 +40

lda upper+02,X
sta screen +32 +80
adc #1
sta screen +33 +80

lda upper+03,X
sta screen +32 +120
adc #1
sta screen +33 +120

lda upper+04,X
sta screen +32 +160
adc #1
sta screen +33 +160

lda upper+05,X
sta screen +32 +200
adc #1
sta screen +33 +200

lda upper+06,x
sta screen +32 +240
adc #1
sta screen +33 +240

lda upper+07,X
sta screen +32 +280
adc #1
sta screen +33 +280

//////////////
ldy sinebuffer+17
ldx convtable,Y
clc
lda upper+00,X
sta screen +34 +00
adc #1
sta screen +35 +00

lda upper+01,X
sta screen +34 +40
adc #1
sta screen +35 +40

lda upper+02,X
sta screen +34 +80
adc #1
sta screen +35 +80

lda upper+03,X
sta screen +34 +120
adc #1
sta screen +35 +120

lda upper+04,X
sta screen +34 +160
adc #1
sta screen +35 +160

lda upper+05,X
sta screen +34 +200
adc #1
sta screen +35 +200

lda upper+06,x
sta screen +34 +240
adc #1
sta screen +35 +240

lda upper+07,X
sta screen +34 +280
adc #1
sta screen +35 +280

//////////////
ldy sinebuffer+18
ldx convtable,Y
clc
lda upper+00,X
sta screen +36 +00
adc #1
sta screen +37 +00

lda upper+01,X
sta screen +36 +40
adc #1
sta screen +37 +40

lda upper+02,X
sta screen +36 +80
adc #1
sta screen +37 +80

lda upper+03,X
sta screen +36 +120
adc #1
sta screen +37 +120

lda upper+04,X
sta screen +36 +160
adc #1
sta screen +37 +160

lda upper+05,X
sta screen +36 +200
adc #1
sta screen +37 +200

lda upper+06,x
sta screen +36 +240
adc #1
sta screen +37 +240

lda upper+07,X
sta screen +36 +280
adc #1
sta screen +37 +280


//////////////
ldy sinebuffer+19
ldx convtable,Y
clc
lda upper+00,X
sta screen +38 +00
adc #1
sta screen +39 +00

lda upper+01,X
sta screen +38 +40
adc #1
sta screen +39 +40

lda upper+02,X
sta screen +38 +80
adc #1
sta screen +39 +80

lda upper+03,X
sta screen +38 +120
adc #1
sta screen +39 +120

lda upper+04,X
sta screen +38 +160
adc #1
sta screen +39 +160

lda upper+05,X
sta screen +38 +200
adc #1
sta screen +39 +200

lda upper+06,x
sta screen +38 +240
adc #1
sta screen +39 +240

lda upper+07,X
sta screen +38 +280
adc #1
sta screen +39 +280


//////////////////////////////////

//////////////
ldy sinebuffer2
ldx convtable,Y
clc
lda lower+00,X
sta screen +00 +320
adc #1
sta screen +01 +320

lda lower+01,X
sta screen +00 +360
adc #1
sta screen +01 +360

lda lower+02,X
sta screen +00 +400
adc #1
sta screen +01 +400

lda lower+03,X
sta screen +00 +440
adc #1
sta screen +01 +440

lda lower+04,X
sta screen +00 +480
adc #1
sta screen +01 +480

lda lower+05,X
sta screen +00 +520
adc #1
sta screen +01 +520

lda lower+06,X
sta screen +00 +560
adc #1
sta screen +01 +560

lda lower+07,X
sta screen +00 +600
adc #1
sta screen +01 +600

//////////////
ldy sinebuffer2+1
ldx convtable,Y
clc
lda lower+00,X
sta screen +02 +320
adc #1
sta screen +03 +320

lda lower+01,X
sta screen +02 +360
adc #1
sta screen +03 +360

lda lower+02,X
sta screen +02 +400
adc #1
sta screen +03 +400

lda lower+03,X
sta screen +02 +440
adc #1
sta screen +03 +440

lda lower+04,X
sta screen +02 +480
adc #1
sta screen +03 +480

lda lower+05,X
sta screen +02 +520
adc #1
sta screen +03 +520

lda lower+06,X
sta screen +02 +560
adc #1
sta screen +03 +560

lda lower+07,X
sta screen +02 +600
adc #1
sta screen +03 +600

//////////////
ldy sinebuffer2+2
ldx convtable,Y
clc
lda lower+00,X
sta screen +04 +320
adc #1
sta screen +05 +320

lda lower+01,X
sta screen +04 +360
adc #1
sta screen +05 +360

lda lower+02,X
sta screen +04 +400
adc #1
sta screen +05 +400

lda lower+03,X
sta screen +04 +440
adc #1
sta screen +05 +440

lda lower+04,X
sta screen +04 +480
adc #1
sta screen +05 +480

lda lower+05,X
sta screen +04 +520
adc #1
sta screen +05 +520

lda lower+06,X
sta screen +04 +560
adc #1
sta screen +05 +560

lda lower+07,X
sta screen +04 +600
adc #1
sta screen +05 +600

//////////////
ldy sinebuffer2+3
ldx convtable,Y
clc
lda lower+00,X
sta screen +06 +320
adc #1
sta screen +07 +320

lda lower+01,X
sta screen +06 +360
adc #1
sta screen +07 +360

lda lower+02,X
sta screen +06 +400
adc #1
sta screen +07 +400

lda lower+03,X
sta screen +06 +440
adc #1
sta screen +07 +440

lda lower+04,X
sta screen +06 +480
adc #1
sta screen +07 +480

lda lower+05,X
sta screen +06 +520
adc #1
sta screen +07 +520

lda lower+06,X
sta screen +06 +560
adc #1
sta screen +07 +560

lda lower+07,X
sta screen +06 +600
adc #1
sta screen +07 +600

//////////////
ldy sinebuffer2+4
ldx convtable,Y
clc
lda lower+00,X
sta screen +08 +320
adc #1
sta screen +09 +320

lda lower+01,X
sta screen +08 +360
adc #1
sta screen +09 +360

lda lower+02,X
sta screen +08 +400
adc #1
sta screen +09 +400

lda lower+03,X
sta screen +08 +440
adc #1
sta screen +09 +440

lda lower+04,X
sta screen +08 +480
adc #1
sta screen +09 +480

lda lower+05,X
sta screen +08 +520
adc #1
sta screen +09 +520

lda lower+06,X
sta screen +08 +560
adc #1
sta screen +09 +560

lda lower+07,X
sta screen +08 +600
adc #1
sta screen +09 +600

//////////////
ldy sinebuffer2+5
ldx convtable,Y
clc
lda lower+00,X
sta screen +10 +320
adc #1
sta screen +11 +320

lda lower+01,X
sta screen +10 +360
adc #1
sta screen +11 +360

lda lower+02,X
sta screen +10 +400
adc #1
sta screen +11 +400

lda lower+03,X
sta screen +10 +440
adc #1
sta screen +11 +440

lda lower+04,X
sta screen +10 +480
adc #1
sta screen +11 +480

lda lower+05,X
sta screen +10 +520
adc #1
sta screen +11 +520

lda lower+06,X
sta screen +10 +560
adc #1
sta screen +11 +560

lda lower+07,X
sta screen +10 +600
adc #1
sta screen +11 +600


//////////////
ldy sinebuffer2+6
ldx convtable,Y
clc
lda lower+00,X
sta screen +12 +320
adc #1
sta screen +13 +320

lda lower+01,X
sta screen +12 +360
adc #1
sta screen +13 +360

lda lower+02,X
sta screen +12 +400
adc #1
sta screen +13 +400

lda lower+03,X
sta screen +12 +440
adc #1
sta screen +13 +440

lda lower+04,X
sta screen +12 +480
adc #1
sta screen +13 +480

lda lower+05,X
sta screen +12 +520
adc #1
sta screen +13 +520

lda lower+06,X
sta screen +12 +560
adc #1
sta screen +13 +560

lda lower+07,X
sta screen +12 +600
adc #1
sta screen +13 +600


//////////////
ldy sinebuffer2+7
ldx convtable,Y
clc
lda lower+00,X
sta screen +14 +320
adc #1
sta screen +15 +320

lda lower+01,X
sta screen +14 +360
adc #1
sta screen +15 +360

lda lower+02,X
sta screen +14 +400
adc #1
sta screen +15 +400

lda lower+03,X
sta screen +14 +440
adc #1
sta screen +15 +440

lda lower+04,X
sta screen +14 +480
adc #1
sta screen +15 +480

lda lower+05,X
sta screen +14 +520
adc #1
sta screen +15 +520

lda lower+06,X
sta screen +14 +560
adc #1
sta screen +15 +560

lda lower+07,X
sta screen +14 +600
adc #1
sta screen +15 +600


//////////////
ldy sinebuffer2+8
ldx convtable,Y
clc
lda lower+00,X
sta screen +16 +320
adc #1
sta screen +17 +320

lda lower+01,X
sta screen +16 +360
adc #1
sta screen +17 +360

lda lower+02,X
sta screen +16 +400
adc #1
sta screen +17 +400

lda lower+03,X
sta screen +16 +440
adc #1
sta screen +17 +440

lda lower+04,X
sta screen +16 +480
adc #1
sta screen +17 +480

lda lower+05,X
sta screen +16 +520
adc #1
sta screen +17 +520

lda lower+06,X
sta screen +16 +560
adc #1
sta screen +17 +560

lda lower+07,X
sta screen +16 +600
adc #1
sta screen +17 +600

//////////////
ldy sinebuffer2+9
ldx convtable,Y
clc
lda lower+00,X
sta screen +18 +320
adc #1
sta screen +19 +320

lda lower+01,X
sta screen +18 +360
adc #1
sta screen +19 +360

lda lower+02,X
sta screen +18 +400
adc #1
sta screen +19 +400

lda lower+03,X
sta screen +18 +440
adc #1
sta screen +19 +440

lda lower+04,X
sta screen +18 +480
adc #1
sta screen +19 +480

lda lower+05,X
sta screen +18 +520
adc #1
sta screen +19 +520

lda lower+06,X
sta screen +18 +560
adc #1
sta screen +19 +560

lda lower+07,X
sta screen +18 +600
adc #1
sta screen +19 +600


//////////////
ldy sinebuffer2+10
ldx convtable,Y
clc
lda lower+00,X
sta screen +20 +320
adc #1
sta screen +21 +320

lda lower+01,X
sta screen +20 +360
adc #1
sta screen +21 +360

lda lower+02,X
sta screen +20 +400
adc #1
sta screen +21 +400

lda lower+03,X
sta screen +20 +440
adc #1
sta screen +21 +440

lda lower+04,X
sta screen +20 +480
adc #1
sta screen +21 +480

lda lower+05,X
sta screen +20 +520
adc #1
sta screen +21 +520

lda lower+06,X
sta screen +20 +560
adc #1
sta screen +21 +560

lda lower+07,X
sta screen +20 +600
adc #1
sta screen +21 +600

//////////////
ldy sinebuffer2+11
ldx convtable,Y
clc
lda lower+00,X
sta screen +22 +320
adc #1
sta screen +23 +320

lda lower+01,X
sta screen +22 +360
adc #1
sta screen +23 +360

lda lower+02,X
sta screen +22 +400
adc #1
sta screen +23 +400

lda lower+03,X
sta screen +22 +440
adc #1
sta screen +23 +440

lda lower+04,X
sta screen +22 +480
adc #1
sta screen +23 +480

lda lower+05,x
sta screen +22 +520
adc #1
sta screen +23 +520

lda lower+06,X
sta screen +22 +560
adc #1
sta screen +23 +560

lda lower+07,X
sta screen +22 +600
adc #1
sta screen +23 +600


//////////////
ldy sinebuffer2+12
ldx convtable,Y
clc
lda lower+00,X
sta screen +24 +320
adc #1
sta screen +25 +320

lda lower+01,X
sta screen +24 +360
adc #1
sta screen +25 +360

lda lower+02,X
sta screen +24 +400
adc #1
sta screen +25 +400

lda lower+03,X
sta screen +24 +440
adc #1
sta screen +25 +440

lda lower+04,X
sta screen +24 +480
adc #1
sta screen +25 +480

lda lower+05,x
sta screen +24 +520
adc #1
sta screen +25 +520

lda lower+06,X
sta screen +24 +560
adc #1
sta screen +25 +560

lda lower+07,X
sta screen +24 +600
adc #1
sta screen +25 +600

//////////////
ldy sinebuffer2+13
ldx convtable,Y
clc
lda lower+00,X
sta screen +26 +320
adc #1
sta screen +27 +320

lda lower+01,X
sta screen +26 +360
adc #1
sta screen +27 +360

lda lower+02,X
sta screen +26 +400
adc #1
sta screen +27 +400

lda lower+03,X
sta screen +26 +440
adc #1
sta screen +27 +440

lda lower+04,X
sta screen +26 +480
adc #1
sta screen +27 +480

lda lower+05,x
sta screen +26 +520
adc #1
sta screen +27 +520

lda lower+06,X
sta screen +26 +560
adc #1
sta screen +27 +560

lda lower+07,X
sta screen +26 +600
adc #1
sta screen +27 +600

//////////////
ldy sinebuffer2+14
ldx convtable,Y
clc
lda lower+00,X
sta screen +28 +320
adc #1
sta screen +29 +320

lda lower+01,X
sta screen +28 +360
adc #1
sta screen +29 +360

lda lower+02,X
sta screen +28 +400
adc #1
sta screen +29 +400

lda lower+03,X
sta screen +28 +440
adc #1
sta screen +29 +440

lda lower+04,X
sta screen +28 +480
adc #1
sta screen +29 +480

lda lower+05,x
sta screen +28 +520
adc #1
sta screen +29 +520

lda lower+06,X
sta screen +28 +560
adc #1
sta screen +29 +560

lda lower+07,X
sta screen +28 +600
adc #1
sta screen +29 +600

//////////////
ldy sinebuffer2+15
ldx convtable,Y
clc
lda lower+00,X
sta screen +30 +320
adc #1
sta screen +31 +320

lda lower+01,X
sta screen +30 +360
adc #1
sta screen +31 +360

lda lower+02,X
sta screen +30 +400
adc #1
sta screen +31 +400

lda lower+03,X
sta screen +30 +440
adc #1
sta screen +31 +440

lda lower+04,X
sta screen +30 +480
adc #1
sta screen +31 +480

lda lower+05,x
sta screen +30 +520
adc #1
sta screen +31 +520

lda lower+06,X
sta screen +30 +560
adc #1
sta screen +31 +560

lda lower+07,X
sta screen +30 +600
adc #1
sta screen +31 +600

//////////////
ldy sinebuffer2+16
ldx convtable,Y
clc
lda lower+00,X
sta screen +32 +320
adc #1
sta screen +33 +320

lda lower+01,X
sta screen +32 +360
adc #1
sta screen +33 +360

lda lower+02,X
sta screen +32 +400
adc #1
sta screen +33 +400

lda lower+03,X
sta screen +32 +440
adc #1
sta screen +33 +440

lda lower+04,X
sta screen +32 +480
adc #1
sta screen +33 +480

lda lower+05,x
sta screen +32 +520
adc #1
sta screen +33 +520

lda lower+06,X
sta screen +32 +560
adc #1
sta screen +33 +560

lda lower+07,X
sta screen +32 +600
adc #1
sta screen +33 +600


//////////////
ldy sinebuffer2+17
ldx convtable,Y
clc
lda lower+00,X
sta screen +34 +320
adc #1
sta screen +35 +320

lda lower+01,X
sta screen +34 +360
adc #1
sta screen +35 +360

lda lower+02,X
sta screen +34 +400
adc #1
sta screen +35 +400

lda lower+03,X
sta screen +34 +440
adc #1
sta screen +35 +440

lda lower+04,X
sta screen +34 +480
adc #1
sta screen +35 +480

lda lower+05,x
sta screen +34 +520
adc #1
sta screen +35 +520

lda lower+06,X
sta screen +34 +560
adc #1
sta screen +35 +560

lda lower+07,X
sta screen +34 +600
adc #1
sta screen +35 +600

//////////////
ldy sinebuffer2+18
ldx convtable,Y
clc
lda lower+00,X
sta screen +36 +320
adc #1
sta screen +37 +320

lda lower+01,X
sta screen +36 +360
adc #1
sta screen +37 +360

lda lower+02,X
sta screen +36 +400
adc #1
sta screen +37 +400

lda lower+03,X
sta screen +36 +440
adc #1
sta screen +37 +440

lda lower+04,X
sta screen +36 +480
adc #1
sta screen +37 +480

lda lower+05,x
sta screen +36 +520
adc #1
sta screen +37 +520

lda lower+06,X
sta screen +36 +560
adc #1
sta screen +37 +560

lda lower+07,X
sta screen +36 +600
adc #1
sta screen +37 +600

//////////////
ldy sinebuffer2+19
ldx convtable,Y
clc
lda lower+00,X
sta screen +38 +320
adc #1
sta screen +39 +320

lda lower+01,X
sta screen +38 +360
adc #1
sta screen +39 +360

lda lower+02,X
sta screen +38 +400
adc #1
sta screen +39 +400

lda lower+03,X
sta screen +38 +440
adc #1
sta screen +39 +440

lda lower+04,X
sta screen +38 +480
adc #1
sta screen +39 +480

lda lower+05,x
sta screen +38 +520
adc #1
sta screen +39 +520

lda lower+06,X
sta screen +38 +560
adc #1
sta screen +39 +560

lda lower+07,X
sta screen +38 +600
adc #1
sta screen +39 +600

//////////////////////////////////

//////////////
ldy sinebuffer3
ldx convtable,Y
clc
lda lowest+00,X
sta screen +00 +640
adc #1
sta screen +01 +640

lda lowest+01,X
sta screen +00 +680
adc #1
sta screen +01 +680

lda lowest+02,X
sta screen +00 +720
adc #1
sta screen +01 +720

lda lowest+03,X
sta screen +00 +760
adc #1
sta screen +01 +760

lda lowest+04,X
sta screen +00 +800
adc #1
sta screen +01 +800

lda lowest+05,X
sta screen +00 +840
adc #1
sta screen +01 +840

lda lowest+06,X
sta screen +00 +880
adc #1
sta screen +01 +880

lda lowest+07,X
sta screen +00 +920
adc #1
sta screen +01 +920

//////////////
ldy sinebuffer3+1
ldx convtable,Y
clc
lda lowest+00,X
sta screen +02 +640
adc #1
sta screen +03 +640

lda lowest+01,X
sta screen +02 +680
adc #1
sta screen +03 +680

lda lowest+02,X
sta screen +02 +720
adc #1
sta screen +03 +720

lda lowest+03,X
sta screen +02 +760
adc #1
sta screen +03 +760

lda lowest+04,X
sta screen +02 +800
adc #1
sta screen +03 +800

lda lowest+05,X
sta screen +02 +840
adc #1
sta screen +03 +840

lda lowest+06,X
sta screen +02 +880
adc #1
sta screen +03 +880

lda lowest+07,X
sta screen +02 +920
adc #1
sta screen +03 +920

//////////////
ldy sinebuffer3+2
ldx convtable,Y
clc
lda lowest+00,X
sta screen +04 +640
adc #1
sta screen +05 +640

lda lowest+01,X
sta screen +04 +680
adc #1
sta screen +05 +680

lda lowest+02,X
sta screen +04 +720
adc #1
sta screen +05 +720

lda lowest+03,X
sta screen +04 +760
adc #1
sta screen +05 +760

lda lowest+04,X
sta screen +04 +800
adc #1
sta screen +05 +800

lda lowest+05,X
sta screen +04 +840
adc #1
sta screen +05 +840

lda lowest+06,X
sta screen +04 +880
adc #1
sta screen +05 +880

lda lowest+07,X
sta screen +04 +920
adc #1
sta screen +05 +920

//////////////
ldy sinebuffer3+3
ldx convtable,Y
clc
lda lowest+00,X
sta screen +06 +640
adc #1
sta screen +07 +640

lda lowest+01,X
sta screen +06 +680
adc #1
sta screen +07 +680

lda lowest+02,X
sta screen +06 +720
adc #1
sta screen +07 +720

lda lowest+03,X
sta screen +06 +760
adc #1
sta screen +07 +760

lda lowest+04,X
sta screen +06 +800
adc #1
sta screen +07 +800

lda lowest+05,X
sta screen +06 +840
adc #1
sta screen +07 +840

lda lowest+06,X
sta screen +06 +880
adc #1
sta screen +07 +880

lda lowest+07,X
sta screen +06 +920
adc #1
sta screen +07 +920

//////////////
ldy sinebuffer3+4
ldx convtable,Y
clc
lda lowest+00,X
sta screen +08 +640
adc #1
sta screen +09 +640

lda lowest+01,X
sta screen +08 +680
adc #1
sta screen +09 +680

lda lowest+02,X
sta screen +08 +720
adc #1
sta screen +09 +720

lda lowest+03,X
sta screen +08 +760
adc #1
sta screen +09 +760

lda lowest+04,X
sta screen +08 +800
adc #1
sta screen +09 +800

lda lowest+05,X
sta screen +08 +840
adc #1
sta screen +09 +840

lda lowest+06,X
sta screen +08 +880
adc #1
sta screen +09 +880

lda lowest+07,X
sta screen +08 +920
adc #1
sta screen +09 +920

//////////////
ldy sinebuffer3+5
ldx convtable,Y
clc
lda lowest+00,X
sta screen +10 +640
adc #1
sta screen +11 +640

lda lowest+01,X
sta screen +10 +680
adc #1
sta screen +11 +680

lda lowest+02,X
sta screen +10 +720
adc #1
sta screen +11 +720

lda lowest+03,X
sta screen +10 +760
adc #1
sta screen +11 +760

lda lowest+04,X
sta screen +10 +800
adc #1
sta screen +11 +800

lda lowest+05,X
sta screen +10 +840
adc #1
sta screen +11 +840

lda lowest+06,X
sta screen +10 +880
adc #1
sta screen +11 +880

lda lowest+07,X
sta screen +10 +920
adc #1
sta screen +11 +920

//////////////
ldy sinebuffer3+6
ldx convtable,Y
clc
lda lowest+00,X
sta screen +12 +640
adc #1
sta screen +13 +640

lda lowest+01,X
sta screen +12 +680
adc #1
sta screen +13 +680

lda lowest+02,X
sta screen +12 +720
adc #1
sta screen +13 +720

lda lowest+03,X
sta screen +12 +760
adc #1
sta screen +13 +760

lda lowest+04,X
sta screen +12 +800
adc #1
sta screen +13 +800

lda lowest+05,X
sta screen +12 +840
adc #1
sta screen +13 +840

lda lowest+06,X
sta screen +12 +880
adc #1
sta screen +13 +880

lda lowest+07,X
sta screen +12 +920
adc #1
sta screen +13 +920

//////////////
ldy sinebuffer3+7
ldx convtable,Y
clc
lda lowest+00,X
sta screen +14 +640
adc #1
sta screen +15 +640

lda lowest+01,X
sta screen +14 +680
adc #1
sta screen +15 +680

lda lowest+02,X
sta screen +14 +720
adc #1
sta screen +15 +720

lda lowest+03,X
sta screen +14 +760
adc #1
sta screen +15 +760

lda lowest+04,X
sta screen +14 +800
adc #1
sta screen +15 +800

lda lowest+05,X
sta screen +14 +840
adc #1
sta screen +15 +840

lda lowest+06,X
sta screen +14 +880
adc #1
sta screen +15 +880

lda lowest+07,X
sta screen +14 +920
adc #1
sta screen +15 +920

//////////////
ldy sinebuffer3+8
ldx convtable,Y
clc
lda lowest+00,X
sta screen +16 +640
adc #1
sta screen +17 +640

lda lowest+01,X
sta screen +16 +680
adc #1
sta screen +17 +680

lda lowest+02,X
sta screen +16 +720
adc #1
sta screen +17 +720

lda lowest+03,X
sta screen +16 +760
adc #1
sta screen +17 +760

lda lowest+04,X
sta screen +16 +800
adc #1
sta screen +17 +800

lda lowest+05,X
sta screen +16 +840
adc #1
sta screen +17 +840

lda lowest+06,X
sta screen +16 +880
adc #1
sta screen +17 +880

lda lowest+07,X
sta screen +16 +920
adc #1
sta screen +17 +920

//////////////
ldy sinebuffer3+9
ldx convtable,Y
clc
lda lowest+00,X
sta screen +18 +640
adc #1
sta screen +19 +640

lda lowest+01,X
sta screen +18 +680
adc #1
sta screen +19 +680

lda lowest+02,X
sta screen +18 +720
adc #1
sta screen +19 +720

lda lowest+03,X
sta screen +18 +760
adc #1
sta screen +19 +760

lda lowest+04,X
sta screen +18 +800
adc #1
sta screen +19 +800

lda lowest+05,X
sta screen +18 +840
adc #1
sta screen +19 +840

lda lowest+06,X
sta screen +18 +880
adc #1
sta screen +19 +880

lda lowest+07,X
sta screen +18 +920
adc #1
sta screen +19 +920


//////////////
ldy sinebuffer3+10
ldx convtable,Y
clc
lda lowest+00,X
sta screen +20 +640
adc #1
sta screen +21 +640

lda lowest+01,X
sta screen +20 +680
adc #1
sta screen +21 +680

lda lowest+02,X
sta screen +20 +720
adc #1
sta screen +21 +720

lda lowest+03,X
sta screen +20 +760
adc #1
sta screen +21 +760

lda lowest+04,X
sta screen +20 +800
adc #1
sta screen +21 +800

lda lowest+05,X
sta screen +20 +840
adc #1
sta screen +21 +840

lda lowest+06,X
sta screen +20 +880
adc #1
sta screen +21 +880

lda lowest+07,X
sta screen +20 +920
adc #1
sta screen +21 +920

//////////////
ldy sinebuffer3+11
ldx convtable,Y
clc
lda lowest+00,X
sta screen +22 +640
adc #1
sta screen +23 +640

lda lowest+01,X
sta screen +22 +680
adc #1
sta screen +23 +680

lda lowest+02,X
sta screen +22 +720
adc #1
sta screen +23 +720

lda lowest+03,X
sta screen +22 +760
adc #1
sta screen +23 +760

lda lowest+04,X
sta screen +22 +800
adc #1
sta screen +23 +800

lda lowest+05,X
sta screen +22 +840
adc #1
sta screen +23 +840

lda lowest+06,X
sta screen +22 +880
adc #1
sta screen +23 +880

lda lowest+07,X
sta screen +22 +920
adc #1
sta screen +23 +920

//////////////
ldy sinebuffer3+12
ldx convtable,Y
clc
lda lowest+00,X
sta screen +24 +640
adc #1
sta screen +25 +640

lda lowest+01,X
sta screen +24 +680
adc #1
sta screen +25 +680

lda lowest+02,X
sta screen +24 +720
adc #1
sta screen +25 +720

lda lowest+03,X
sta screen +24 +760
adc #1
sta screen +25 +760

lda lowest+04,X
sta screen +24 +800
adc #1
sta screen +25 +800

lda lowest+05,X
sta screen +24 +840
adc #1
sta screen +25 +840

lda lowest+06,X
sta screen +24 +880
adc #1
sta screen +25 +880

lda lowest+07,X
sta screen +24 +920
adc #1
sta screen +25 +920

//////////////
ldy sinebuffer3+13
ldx convtable,Y
clc
lda lowest+00,X
sta screen +26 +640
adc #1
sta screen +27 +640

lda lowest+01,X
sta screen +26 +680
adc #1
sta screen +27 +680

lda lowest+02,X
sta screen +26 +720
adc #1
sta screen +27 +720

lda lowest+03,X
sta screen +26 +760
adc #1
sta screen +27 +760

lda lowest+04,X
sta screen +26 +800
adc #1
sta screen +27 +800

lda lowest+05,X
sta screen +26 +840
adc #1
sta screen +27 +840

lda lowest+06,X
sta screen +26 +880
adc #1
sta screen +27 +880

lda lowest+07,X
sta screen +26 +920
adc #1
sta screen +27 +920

//////////////
ldy sinebuffer3+14
ldx convtable,Y
clc
lda lowest+00,X
sta screen +28 +640
adc #1
sta screen +29 +640

lda lowest+01,X
sta screen +28 +680
adc #1
sta screen +29 +680

lda lowest+02,X
sta screen +28 +720
adc #1
sta screen +29 +720

lda lowest+03,X
sta screen +28 +760
adc #1
sta screen +29 +760

lda lowest+04,X
sta screen +28 +800
adc #1
sta screen +29 +800

lda lowest+05,X
sta screen +28 +840
adc #1
sta screen +29 +840

lda lowest+06,X
sta screen +28 +880
adc #1
sta screen +29 +880

lda lowest+07,X
sta screen +28 +920
adc #1
sta screen +29 +920


//////////////
ldy sinebuffer3+15
ldx convtable,Y
clc
lda lowest+00,X
sta screen +30 +640
adc #1
sta screen +31 +640

lda lowest+01,X
sta screen +30 +680
adc #1
sta screen +31 +680

lda lowest+02,X
sta screen +30 +720
adc #1
sta screen +31 +720

lda lowest+03,X
sta screen +30 +760
adc #1
sta screen +31 +760

lda lowest+04,X
sta screen +30 +800
adc #1
sta screen +31 +800

lda lowest+05,X
sta screen +30 +840
adc #1
sta screen +31 +840

lda lowest+06,X
sta screen +30 +880
adc #1
sta screen +31 +880

lda lowest+07,X
sta screen +30 +920
adc #1
sta screen +31 +920

//////////////
ldy sinebuffer3+16
ldx convtable,Y
clc
lda lowest+00,X
sta screen +32 +640
adc #1
sta screen +33 +640

lda lowest+01,X
sta screen +32 +680
adc #1
sta screen +33 +680

lda lowest+02,X
sta screen +32 +720
adc #1
sta screen +33 +720

lda lowest+03,X
sta screen +32 +760
adc #1
sta screen +33 +760

lda lowest+04,X
sta screen +32 +800
adc #1
sta screen +33 +800

lda lowest+05,X
sta screen +32 +840
adc #1
sta screen +33 +840

lda lowest+06,X
sta screen +32 +880
adc #1
sta screen +33 +880

lda lowest+07,X
sta screen +32 +920
adc #1
sta screen +33 +920

//////////////
ldy sinebuffer3+17
ldx convtable,Y
clc
lda lowest+00,X
sta screen +34 +640
adc #1
sta screen +35 +640

lda lowest+01,X
sta screen +34 +680
adc #1
sta screen +35 +680

lda lowest+02,X
sta screen +34 +720
adc #1
sta screen +35 +720

lda lowest+03,X
sta screen +34 +760
adc #1
sta screen +35 +760

lda lowest+04,X
sta screen +34 +800
adc #1
sta screen +35 +800

lda lowest+05,X
sta screen +34 +840
adc #1
sta screen +35 +840

lda lowest+06,X
sta screen +34 +880
adc #1
sta screen +35 +880

lda lowest+07,X
sta screen +34 +920
adc #1
sta screen +35 +920

//////////////
ldy sinebuffer3+18
ldx convtable,Y
clc
lda lowest+00,X
sta screen +36 +640
adc #1
sta screen +37 +640

lda lowest+01,X
sta screen +36 +680
adc #1
sta screen +37 +680

lda lowest+02,X
sta screen +36 +720
adc #1
sta screen +37 +720

lda lowest+03,X
sta screen +36 +760
adc #1
sta screen +37 +760

lda lowest+04,X
sta screen +36 +800
adc #1
sta screen +37 +800

lda lowest+05,X
sta screen +36 +840
adc #1
sta screen +37 +840

lda lowest+06,X
sta screen +36 +880
adc #1
sta screen +37 +880

lda lowest+07,X
sta screen +36 +920
adc #1
sta screen +37 +920

//////////////
ldy sinebuffer3+19
ldx convtable,Y
clc
lda lowest+00,X
sta screen +38 +640
adc #1
sta screen +39 +640

lda lowest+01,X
sta screen +38 +680
adc #1
sta screen +39 +680

lda lowest+02,X
sta screen +38 +720
adc #1
sta screen +39 +720

lda lowest+03,X
sta screen +38 +760
adc #1
sta screen +39 +760

lda lowest+04,X
sta screen +38 +800
adc #1
sta screen +39 +800

lda lowest+05,X
sta screen +38 +840
adc #1
sta screen +39 +840

lda lowest+06,X
sta screen +38 +880
adc #1
sta screen +39 +880

lda lowest+07,X
sta screen +38 +920
adc #1
sta screen +39 +920

rts



///////////////////////////////////// chartable for upper columns
* = $6000 "upper"
upper:
c07:
.byte $fe
c0f:
.byte $fe
c17:
.byte $fe
c1f:
.byte $fe
c27:
.byte $fe
c2f:
.byte $fe
c37:
.byte $fe
c3f:
.byte $00
.byte $02
.byte $04
.byte $06
.byte $06
.byte $06
.byte $06
.byte $06
// 01
c06:
.byte $fe
c0e:
.byte $fe
c16:
.byte $fe
c1e:
.byte $fe
c26:
.byte $fe
c2e:
.byte $fe
c36:
.byte $fe
c3e:
.byte $10
.byte $12
.byte $14
.byte $16
.byte $16
.byte $16
.byte $16
.byte $16
// 02
c05:
.byte $fe
c0d:
.byte $fe
c15:
.byte $fe
c1d:
.byte $fe
c25:
.byte $fe
c2d:
.byte $fe
c35:
.byte $fe
c3d:
.byte $20
.byte $22
.byte $24
.byte $26
.byte $26
.byte $26
.byte $26
.byte $26
// 03
c04:
.byte $fe
c0c:
.byte $fe
c14:
.byte $fe
c1c:
.byte $fe
c24:
.byte $fe
c2c:
.byte $fe
c34:
.byte $fe
c3c:
.byte $30
.byte $32
.byte $34
.byte $36
.byte $36
.byte $36
.byte $36
.byte $36
// 04
c03:
.byte $fe
c0b:
.byte $fe
c13:
.byte $fe
c1b:
.byte $fe
c23:
.byte $fe
c2b:
.byte $fe
c33:
.byte $fe
c3b:
.byte $40
.byte $42
.byte $44
.byte $46
.byte $46
.byte $46
.byte $46
.byte $46
// 05
c02:
.byte $fe
c0a:
.byte $fe
c12:
.byte $fe
c1a:
.byte $fe
c22:
.byte $fe
c2a:
.byte $fe
c32:
.byte $fe
c3a:
.byte $50
.byte $52
.byte $54
.byte $56
.byte $56
.byte $56
.byte $56
.byte $56
// 06
c01:
.byte $fe
c09:
.byte $fe
c11:
.byte $fe
c19:
.byte $fe
c21:
.byte $fe
c29:
.byte $fe
c31:
.byte $fe
c39:
.byte $60
.byte $62
.byte $64
.byte $66
.byte $66
.byte $66
.byte $66
.byte $66
// 07
c00:
.byte $fe
c08:
.byte $fe
c10:
.byte $fe
c18:
.byte $fe
c20:
.byte $fe
c28:
.byte $fe
c30:
.byte $fe
c38:
.byte $70
.byte $72
.byte $74
.byte $76
.byte $76
.byte $76
.byte $76
.byte $76

///////////////////////////////////// chartable for middle columns
* = $6080 "lower"
lower:
d07:
.byte $06
d0f:
.byte $06
d17:
.byte $06
d1f:
.byte $06
d27:
.byte $06
d2f:
.byte $06
d37:
.byte $06
d3f:
.byte $80
.byte $82
.byte $84
.byte $86
.byte $86
.byte $86
.byte $86
.byte $86
// 01
d06:
.byte $06
d0e:
.byte $06
d16:
.byte $06
d1e:
.byte $06
d26:
.byte $06
d2e:
.byte $06
d36:
.byte $06
d3e:
.byte $90
.byte $92
.byte $94
.byte $96
.byte $96
.byte $96
.byte $96
.byte $96
// 02
d05:
.byte $06
d0d:
.byte $06
d15:
.byte $06
d1d:
.byte $06
d25:
.byte $06
d2d:
.byte $06
d35:
.byte $06
d3d:
.byte $a0
.byte $a2
.byte $a4
.byte $a6
.byte $a6
.byte $a6
.byte $a6
.byte $a6
// 03
d04:
.byte $06
d0c:
.byte $06
d14:
.byte $06
d1c:
.byte $06
d24:
.byte $06
d2c:
.byte $06
d34:
.byte $06
d3c:
.byte $b0
.byte $b2
.byte $b4
.byte $b6
.byte $b6
.byte $b6
.byte $b6
.byte $b6
// 04
d03:
.byte $06
d0b:
.byte $06
d13:
.byte $06
d1b:
.byte $06
d23:
.byte $06
d2b:
.byte $06
d33:
.byte $06
d3b:
.byte $c0
.byte $c2
.byte $c4
.byte $c6
.byte $c6
.byte $c6
.byte $c6
.byte $c6
// 05
d02:
.byte $06
d0a:
.byte $06
d12:
.byte $06
d1a:
.byte $06
d22:
.byte $06
d2a:
.byte $06
d32:
.byte $06
d3a:
.byte $d0
.byte $d2
.byte $d4
.byte $d6
.byte $d6
.byte $d6
.byte $d6
.byte $d6
// 06
d01:
.byte $06
d09:
.byte $06
d11:
.byte $06
d19:
.byte $06
d21:
.byte $06
d29:
.byte $06
d31:
.byte $06
d39:
.byte $e0
.byte $e2
.byte $e4
.byte $e6
.byte $e6
.byte $e6
.byte $e6
.byte $e6
// 07
d00:
.byte $06
d08:
.byte $06
d10:
.byte $06
d18:
.byte $06
d20:
.byte $06
d28:
.byte $06
d30:
.byte $06
d38:
.byte $f0
.byte $f2
.byte $f4
.byte $f6
.byte $f6
.byte $f6
.byte $f6
.byte $f6

///////////////////////////////////// chartable for lower columns
* = $6100 "lowest"
lowest:
e07:
.byte $86
e0f:
.byte $86
e17:
.byte $86
e1f:
.byte $86
e27:
.byte $86
e2f:
.byte $86
e37:
.byte $86
e3f:
.byte $08
.byte $0a
.byte $0c
.byte $0e
.byte $0e
.byte $0e
.byte $0e
.byte $0e
// 01
e06:
.byte $86
e0e:
.byte $86
e16:
.byte $86
e1e:
.byte $86
e26:
.byte $86
e2e:
.byte $86
e36:
.byte $86
e3e:
.byte $18
.byte $1a
.byte $1c
.byte $1e
.byte $1e
.byte $1e
.byte $1e
.byte $1e
// 02
e05:
.byte $86
e0d:
.byte $86
e15:
.byte $86
e1d:
.byte $86
e25:
.byte $86
e2d:
.byte $86
e35:
.byte $86
e3d:
.byte $28
.byte $2a
.byte $2c
.byte $2e
.byte $2e
.byte $2e
.byte $2e
.byte $2e
// 03
e04:
.byte $86
e0c:
.byte $86
e14:
.byte $86
e1c:
.byte $86
e24:
.byte $86
e2c:
.byte $86
e34:
.byte $86
e3c:
.byte $38
.byte $3a
.byte $3c
.byte $3e
.byte $3e
.byte $3e
.byte $3e
.byte $3e
// 04
e03:
.byte $86
e0b:
.byte $86
e13:
.byte $86
e1b:
.byte $86
e23:
.byte $86
e2b:
.byte $86
e33:
.byte $86
e3b:
.byte $48
.byte $4a
.byte $4c
.byte $4e
.byte $4e
.byte $4e
.byte $4e
.byte $4e
// 05
e02:
.byte $86
e0a:
.byte $86
e12:
.byte $86
e1a:
.byte $86
e22:
.byte $86
e2a:
.byte $86
e32:
.byte $86
e3a:
.byte $58
.byte $5a
.byte $5c
.byte $5e
.byte $5e
.byte $5e
.byte $5e
.byte $5e
// 06
e01:
.byte $86
e09:
.byte $86
e11:
.byte $86
e19:
.byte $86
e21:
.byte $86
e29:
.byte $86
e31:
.byte $86
e39:
.byte $68
.byte $6a
.byte $6c
.byte $6e
.byte $6e
.byte $6e
.byte $6e
.byte $6e
// 07
e00:
.byte $86
e08:
.byte $86
e10:
.byte $86
e18:
.byte $86
e20:
.byte $86
e28:
.byte $86
e30:
.byte $86
e38:
.byte $78
.byte $7a
.byte $7c
.byte $7e
.byte $7e
.byte $7e
.byte $7e
.byte $7e


///////////////////////////////////// offset table for char lookup
* = $6180 "conv1"
convtable:
.byte <c00,<c01,<c02,<c03,<c04,<c05,<c06,<c07,<c08,<c09,<c0a,<c0b,<c0c,<c0d,<c0e,<c0f
.byte <c10,<c11,<c12,<c13,<c14,<c15,<c16,<c17,<c18,<c19,<c1a,<c1b,<c1c,<c1d,<c1e,<c1f
.byte <c20,<c21,<c22,<c23,<c24,<c25,<c26,<c27,<c28,<c29,<c2a,<c2b,<c2c,<c2d,<c2e,<c2f
.byte <c30,<c31,<c32,<c33,<c34,<c35,<c36,<c37,<c38,<c39,<c3a,<c3b,<c3c,<c3d,<c3e,<c3f


///////////////////////////////////// 3 buffers for column date
///////////////////////////////////// values can go from 16 to 63 
* = $61c0 "sinebuffer"
sinebuffer:
.byte 00,00,00,00,00,00,00,00,00,00,00,00,00,00,00,00,00,00,00,00
sinebuffer2:
.byte 00,00,00,00,00,00,00,00,00,00,00,00,00,00,00,00,00,00,00,00
sinebuffer3:
.byte 00,00,00,00,00,00,00,00,00,00,00,00,00,00,00,00,00,00,00,00


///////////////////////////////////// sinewave for testing
* = $6200 "sine"
sine:
.byte 58,59,60,61,62,63
.byte 63,63,63,62,61,60
.byte 59,57,56,54,52,50
.byte 48,46,44,42,40,39
.byte 37,36,35,34,34,33
.byte 33,33,34,34,35,36
.byte 37,38,39,40,41,42
.byte 43,44,45,45,46,46
.byte 46,45,45,44,43,42
.byte 40,38,37,35,33,31
.byte 29,27,25,23,21,20
.byte 19,18,17,16,16,16
.byte 16,17,18,19,20,22
.byte 23,25,27,29,31,33
.byte 35,37,39,40,42,43
.byte 44,45,45,46,46,46
.byte 45,45,44,43,42,41
.byte 40,39,38,37,36,35
.byte 34,34,33,33,33,34
.byte 34,35,36,37,39,41
.byte 42,44,46,48,50,52
.byte 54,56,58,59,60,61
.byte 62,63,63,63,63,62
.byte 61,60,59,57,56,54
.byte 52,50,48,46,44,42
.byte 40,39,37,36,35,34
.byte 34,33,33,33,34,34
.byte 35,36,37,38,39,40
.byte 41,42,43,44,45,45
.byte 46,46,46,45,45,44
.byte 43,42,40,38,37,35
.byte 33,31,29,27,25,23
.byte 21,20,19,18,17,16
.byte 16,16,16,17,18,19
.byte 20,22,23,25,27,29
.byte 31,33,35,37,39,40
.byte 42,43,44,45,45,46
.byte 46,46,45,45,44,43
.byte 42,41,40,39,38,37
.byte 36,35,34,34,33,33
.byte 33,34,34,35,36,37
.byte 39,41,42,44,46,48
.byte 50,52,54,56


///////////////////////////////////// pre shifted char data
* = $2000 "font"
.byte $01,$07,$1F,$7F,$FF,$FF,$7F,$5F
.byte $00,$40,$D0,$F4,$FC,$F4,$D8,$64
.byte $77,$5D,$57,$5D,$57,$55,$57,$55
.byte $98,$68,$98,$68,$A8,$68,$A8,$A8
.byte $57,$55,$55,$55,$55,$55,$55,$55
.byte $A8,$A8,$A8,$A8,$A8,$A8,$A8,$A8
.byte $55,$55,$55,$55,$55,$55,$55,$55
.byte $A8,$A8,$A8,$A8,$A8,$A8,$A8,$A8
.byte $16,$1B,$2F,$BF,$FF,$FF,$7F,$5F
.byte $6A,$AA,$CA,$F2,$FC,$F4,$D8,$64
.byte $77,$5D,$57,$5D,$57,$55,$57,$55
.byte $98,$68,$98,$68,$A8,$68,$A8,$A8
.byte $57,$55,$55,$55,$55,$55,$55,$55
.byte $A8,$A8,$A8,$A8,$A8,$A8,$A8,$A8
.byte $55,$55,$55,$55,$55,$55,$55,$55
.byte $A8,$A8,$A8,$A8,$A8,$A8,$A8,$A8
.byte $00,$01,$07,$1F,$7F,$FF,$FF,$7F
.byte $00,$00,$40,$D0,$F4,$FC,$F4,$D8
.byte $5F,$77,$5D,$57,$5D,$57,$55,$57
.byte $64,$98,$68,$98,$68,$A8,$68,$A8
.byte $55,$57,$55,$55,$55,$55,$55,$55
.byte $A8,$A8,$A8,$A8,$A8,$A8,$A8,$A8
.byte $55,$55,$55,$55,$55,$55,$55,$55
.byte $A8,$A8,$A8,$A8,$A8,$A8,$A8,$A8
.byte $15,$16,$1B,$2F,$BF,$FF,$FF,$7F
.byte $6A,$6A,$AA,$CA,$F2,$FC,$F4,$D8
.byte $5F,$77,$5D,$57,$5D,$57,$55,$57
.byte $64,$98,$68,$98,$68,$A8,$68,$A8
.byte $55,$57,$55,$55,$55,$55,$55,$55
.byte $A8,$A8,$A8,$A8,$A8,$A8,$A8,$A8
.byte $55,$55,$55,$55,$55,$55,$55,$55
.byte $A8,$A8,$A8,$A8,$A8,$A8,$A8,$A8
.byte $00,$00,$01,$07,$1F,$7F,$FF,$FF
.byte $00,$00,$00,$40,$D0,$F4,$FC,$F4
.byte $7F,$5F,$77,$5D,$57,$5D,$57,$55
.byte $D8,$64,$98,$68,$98,$68,$A8,$68
.byte $57,$55,$57,$55,$55,$55,$55,$55
.byte $A8,$A8,$A8,$A8,$A8,$A8,$A8,$A8
.byte $55,$55,$55,$55,$55,$55,$55,$55
.byte $A8,$A8,$A8,$A8,$A8,$A8,$A8,$A8
.byte $15,$15,$16,$1B,$2F,$BF,$FF,$FF
.byte $6A,$6A,$6A,$AA,$CA,$F2,$FC,$F4
.byte $7F,$5F,$77,$5D,$57,$5D,$57,$55
.byte $D8,$64,$98,$68,$98,$68,$A8,$68
.byte $57,$55,$57,$55,$55,$55,$55,$55
.byte $A8,$A8,$A8,$A8,$A8,$A8,$A8,$A8
.byte $55,$55,$55,$55,$55,$55,$55,$55
.byte $A8,$A8,$A8,$A8,$A8,$A8,$A8,$A8
.byte $00,$00,$00,$01,$07,$1F,$7F,$FF
.byte $00,$00,$00,$00,$40,$D0,$F4,$FC
.byte $FF,$7F,$5F,$77,$5D,$57,$5D,$57
.byte $F4,$D8,$64,$98,$68,$98,$68,$A8
.byte $55,$57,$55,$57,$55,$55,$55,$55
.byte $68,$A8,$A8,$A8,$A8,$A8,$A8,$A8
.byte $55,$55,$55,$55,$55,$55,$55,$55
.byte $A8,$A8,$A8,$A8,$A8,$A8,$A8,$A8
.byte $15,$15,$15,$16,$1B,$2F,$BF,$FF
.byte $6A,$6A,$6A,$6A,$AA,$CA,$F2,$FC
.byte $FF,$7F,$5F,$77,$5D,$57,$5D,$57
.byte $F4,$D8,$64,$98,$68,$98,$68,$A8
.byte $55,$57,$55,$57,$55,$55,$55,$55
.byte $68,$A8,$A8,$A8,$A8,$A8,$A8,$A8
.byte $55,$55,$55,$55,$55,$55,$55,$55
.byte $A8,$A8,$A8,$A8,$A8,$A8,$A8,$A8
.byte $00,$00,$00,$00,$01,$07,$1F,$7F
.byte $00,$00,$00,$00,$00,$40,$D0,$F4
.byte $FF,$FF,$7F,$5F,$77,$5D,$57,$5D
.byte $FC,$F4,$D8,$64,$98,$68,$98,$68
.byte $57,$55,$57,$55,$57,$55,$55,$55
.byte $A8,$68,$A8,$A8,$A8,$A8,$A8,$A8
.byte $55,$55,$55,$55,$55,$55,$55,$55
.byte $A8,$A8,$A8,$A8,$A8,$A8,$A8,$A8
.byte $15,$15,$15,$15,$16,$1B,$2F,$BF
.byte $6A,$6A,$6A,$6A,$6A,$AA,$CA,$F2
.byte $FF,$FF,$7F,$5F,$77,$5D,$57,$5D
.byte $FC,$F4,$D8,$64,$98,$68,$98,$68
.byte $57,$55,$57,$55,$57,$55,$55,$55
.byte $A8,$68,$A8,$A8,$A8,$A8,$A8,$A8
.byte $55,$55,$55,$55,$55,$55,$55,$55
.byte $A8,$A8,$A8,$A8,$A8,$A8,$A8,$A8
.byte $00,$00,$00,$00,$00,$01,$07,$1F
.byte $00,$00,$00,$00,$00,$00,$40,$D0
.byte $7F,$FF,$FF,$7F,$5F,$77,$5D,$57
.byte $F4,$FC,$F4,$D8,$64,$98,$68,$98
.byte $5D,$57,$55,$57,$55,$57,$55,$55
.byte $68,$A8,$68,$A8,$A8,$A8,$A8,$A8
.byte $55,$55,$55,$55,$55,$55,$55,$55
.byte $A8,$A8,$A8,$A8,$A8,$A8,$A8,$A8
.byte $15,$15,$15,$15,$15,$16,$1B,$2F
.byte $6A,$6A,$6A,$6A,$6A,$6A,$AA,$CA
.byte $BF,$FF,$FF,$7F,$5F,$77,$5D,$57
.byte $F2,$FC,$F4,$D8,$64,$98,$68,$98
.byte $5D,$57,$55,$57,$55,$57,$55,$55
.byte $68,$A8,$68,$A8,$A8,$A8,$A8,$A8
.byte $55,$55,$55,$55,$55,$55,$55,$55
.byte $A8,$A8,$A8,$A8,$A8,$A8,$A8,$A8
.byte $00,$00,$00,$00,$00,$00,$01,$07
.byte $00,$00,$00,$00,$00,$00,$00,$40
.byte $1F,$7F,$FF,$FF,$7F,$5F,$77,$5D
.byte $D0,$F4,$FC,$F4,$D8,$64,$98,$68
.byte $57,$5D,$57,$55,$57,$55,$57,$55
.byte $98,$68,$A8,$68,$A8,$A8,$A8,$A8
.byte $55,$55,$55,$55,$55,$55,$55,$55
.byte $A8,$A8,$A8,$A8,$A8,$A8,$A8,$A8
.byte $15,$15,$15,$15,$15,$15,$16,$1B
.byte $6A,$6A,$6A,$6A,$6A,$6A,$6A,$2A
.byte $2F,$BF,$FF,$FF,$7F,$5F,$77,$5D
.byte $CA,$F2,$FC,$F4,$D8,$64,$98,$68
.byte $57,$5D,$57,$55,$57,$55,$57,$55
.byte $98,$68,$A8,$68,$A8,$A8,$A8,$A8
.byte $55,$55,$55,$55,$55,$55,$55,$55
.byte $A8,$A8,$A8,$A8,$A8,$A8,$A8,$A8
.byte $00,$00,$00,$00,$00,$00,$00,$01
.byte $00,$00,$00,$00,$00,$00,$00,$00
.byte $07,$1F,$7F,$FF,$FF,$7F,$5F,$77
.byte $40,$D0,$F4,$FC,$F4,$D8,$64,$98
.byte $5D,$57,$5D,$57,$55,$57,$55,$57
.byte $68,$98,$68,$A8,$68,$A8,$A8,$A8
.byte $55,$55,$55,$55,$55,$55,$55,$55
.byte $A8,$A8,$A8,$A8,$A8,$A8,$A8,$A8
.byte $15,$15,$15,$15,$15,$15,$15,$16
.byte $6A,$6A,$6A,$6A,$6A,$6A,$6A,$6A
.byte $1B,$2F,$3F,$FF,$FF,$7F,$5F,$77
.byte $AA,$CA,$F2,$FC,$F4,$D8,$64,$98
.byte $5D,$57,$5D,$57,$55,$57,$55,$57
.byte $68,$98,$68,$A8,$68,$A8,$A8,$A8
.byte $55,$55,$55,$55,$55,$55,$55,$55
.byte $A8,$A8,$A8,$A8,$A8,$A8,$A8,$A8
.byte $55,$56,$5B,$6F,$BF,$3F,$1F,$17
.byte $28,$C8,$F0,$FC,$FF,$FD,$F6,$D9
.byte $1D,$17,$15,$17,$15,$15,$15,$15
.byte $E6,$5A,$E6,$5A,$EA,$5A,$EA,$6A
.byte $15,$15,$15,$15,$15,$15,$15,$15
.byte $EA,$6A,$6A,$6A,$6A,$6A,$6A,$6A
.byte $15,$15,$15,$15,$15,$15,$15,$15
.byte $6A,$6A,$6A,$6A,$6A,$6A,$6A,$6A
.byte $00,$00,$00,$00,$00,$00,$00,$00
.byte $00,$00,$00,$00,$00,$00,$00,$00
.byte $00,$00,$00,$00,$00,$00,$00,$00
.byte $00,$00,$00,$00,$00,$00,$00,$00
.byte $00,$00,$00,$00,$00,$00,$00,$00
.byte $00,$00,$00,$00,$00,$00,$00,$00
.byte $00,$00,$00,$00,$00,$00,$00,$00
.byte $00,$00,$00,$00,$00,$00,$00,$00
.byte $55,$55,$56,$5B,$6F,$BF,$3F,$1F
.byte $A8,$28,$C8,$F0,$FC,$FF,$FD,$F6
.byte $17,$1D,$17,$15,$17,$15,$15,$15
.byte $D9,$E6,$5A,$E6,$5A,$EA,$5A,$EA
.byte $15,$15,$15,$15,$15,$15,$15,$15
.byte $6A,$EA,$6A,$6A,$6A,$6A,$6A,$6A
.byte $15,$15,$15,$15,$15,$15,$15,$15
.byte $6A,$6A,$6A,$6A,$6A,$6A,$6A,$6A
.byte $00,$00,$00,$00,$00,$00,$00,$00
.byte $00,$00,$00,$00,$00,$00,$00,$00
.byte $00,$00,$00,$00,$00,$00,$00,$00
.byte $00,$00,$00,$00,$00,$00,$00,$00
.byte $00,$00,$00,$00,$00,$00,$00,$00
.byte $00,$00,$00,$00,$00,$00,$00,$00
.byte $00,$00,$00,$00,$00,$00,$00,$00
.byte $00,$00,$00,$00,$00,$00,$00,$00
.byte $55,$55,$55,$56,$5B,$6F,$BF,$3F
.byte $A8,$A8,$28,$C8,$F0,$FC,$FF,$FD
.byte $1F,$17,$1D,$17,$15,$17,$15,$15
.byte $F6,$D9,$E6,$5A,$E6,$5A,$EA,$5A
.byte $15,$15,$15,$15,$15,$15,$15,$15
.byte $EA,$6A,$EA,$6A,$6A,$6A,$6A,$6A
.byte $15,$15,$15,$15,$15,$15,$15,$15
.byte $6A,$6A,$6A,$6A,$6A,$6A,$6A,$6A
.byte $00,$00,$00,$00,$00,$00,$00,$00
.byte $00,$00,$00,$00,$00,$00,$00,$00
.byte $00,$00,$00,$00,$00,$00,$00,$00
.byte $00,$00,$00,$00,$00,$00,$00,$00
.byte $00,$00,$00,$00,$00,$00,$00,$00
.byte $00,$00,$00,$00,$00,$00,$00,$00
.byte $00,$00,$00,$00,$00,$00,$00,$00
.byte $00,$00,$00,$00,$00,$00,$00,$00
.byte $55,$55,$55,$55,$56,$5B,$6F,$BF
.byte $A8,$A8,$A8,$28,$C8,$F0,$FC,$FF
.byte $3F,$1F,$17,$1D,$17,$15,$17,$15
.byte $FD,$F6,$D9,$E6,$5A,$E6,$5A,$EA
.byte $15,$15,$15,$15,$15,$15,$15,$15
.byte $5A,$EA,$6A,$EA,$6A,$6A,$6A,$6A
.byte $15,$15,$15,$15,$15,$15,$15,$15
.byte $6A,$6A,$6A,$6A,$6A,$6A,$6A,$6A
.byte $00,$00,$00,$00,$00,$00,$00,$00
.byte $00,$00,$00,$00,$00,$00,$00,$00
.byte $00,$00,$00,$00,$00,$00,$00,$00
.byte $00,$00,$00,$00,$00,$00,$00,$00
.byte $00,$00,$00,$00,$00,$00,$00,$00
.byte $00,$00,$00,$00,$00,$00,$00,$00
.byte $00,$00,$00,$00,$00,$00,$00,$00
.byte $00,$00,$00,$00,$00,$00,$00,$00
.byte $55,$55,$55,$55,$55,$56,$5B,$6F
.byte $A8,$A8,$A8,$A8,$28,$C8,$F0,$FC
.byte $BF,$3F,$1F,$17,$1D,$17,$15,$17
.byte $FF,$FD,$F6,$D9,$E6,$5A,$E6,$5A
.byte $15,$15,$15,$15,$15,$15,$15,$15
.byte $EA,$5A,$EA,$6A,$EA,$6A,$6A,$6A
.byte $15,$15,$15,$15,$15,$15,$15,$15
.byte $6A,$6A,$6A,$6A,$6A,$6A,$6A,$6A
.byte $00,$00,$00,$00,$00,$00,$00,$00
.byte $00,$00,$00,$00,$00,$00,$00,$00
.byte $00,$00,$00,$00,$00,$00,$00,$00
.byte $00,$00,$00,$00,$00,$00,$00,$00
.byte $00,$00,$00,$00,$00,$00,$00,$00
.byte $00,$00,$00,$00,$00,$00,$00,$00
.byte $00,$00,$00,$00,$00,$00,$00,$00
.byte $00,$00,$00,$00,$00,$00,$00,$00
.byte $55,$55,$55,$55,$55,$55,$56,$5B
.byte $A8,$A8,$A8,$A8,$A8,$28,$C8,$F0
.byte $6F,$BF,$3F,$1F,$17,$1D,$17,$15
.byte $FC,$FF,$FD,$F6,$D9,$E6,$5A,$E6
.byte $17,$15,$15,$15,$15,$15,$15,$15
.byte $5A,$EA,$5A,$EA,$6A,$EA,$6A,$6A
.byte $15,$15,$15,$15,$15,$15,$15,$15
.byte $6A,$6A,$6A,$6A,$6A,$6A,$6A,$6A
.byte $00,$00,$00,$00,$00,$00,$00,$00
.byte $00,$00,$00,$00,$00,$00,$00,$00
.byte $00,$00,$00,$00,$00,$00,$00,$00
.byte $00,$00,$00,$00,$00,$00,$00,$00
.byte $00,$00,$00,$00,$00,$00,$00,$00
.byte $00,$00,$00,$00,$00,$00,$00,$00
.byte $00,$00,$00,$00,$00,$00,$00,$00
.byte $00,$00,$00,$00,$00,$00,$00,$00
.byte $55,$55,$55,$55,$55,$55,$55,$56
.byte $A8,$A8,$A8,$A8,$A8,$A8,$28,$C8
.byte $5B,$6F,$BF,$3F,$1F,$17,$1D,$17
.byte $F0,$FC,$FF,$FD,$F6,$D9,$E6,$5A
.byte $15,$17,$15,$15,$15,$15,$15,$15
.byte $E6,$5A,$EA,$5A,$EA,$6A,$EA,$6A
.byte $15,$15,$15,$15,$15,$15,$15,$15
.byte $6A,$6A,$6A,$6A,$6A,$6A,$6A,$6A
.byte $00,$00,$00,$00,$00,$00,$00,$00
.byte $00,$00,$00,$00,$00,$00,$00,$00
.byte $00,$00,$00,$00,$00,$00,$00,$00
.byte $00,$00,$00,$00,$00,$00,$00,$00
.byte $00,$00,$00,$00,$00,$00,$00,$00
.byte $00,$00,$00,$00,$00,$00,$00,$00
.byte $00,$00,$00,$00,$00,$00,$00,$00
.byte $00,$00,$00,$00,$00,$00,$00,$00
.byte $55,$55,$55,$55,$55,$55,$55,$55
.byte $A8,$A8,$A8,$A8,$A8,$A8,$A8,$28
.byte $56,$5B,$6F,$BF,$3F,$1F,$17,$1D
.byte $C8,$F0,$FC,$FF,$FD,$F6,$D9,$E6
.byte $17,$15,$17,$15,$15,$15,$15,$15
.byte $5A,$E6,$5A,$EA,$5A,$EA,$6A,$EA
.byte $15,$15,$15,$15,$15,$15,$15,$15
.byte $6A,$6A,$6A,$6A,$6A,$6A,$6A,$6A
.byte $00,$00,$00,$00,$00,$00,$00,$00
.byte $00,$00,$00,$00,$00,$00,$00,$00
.byte $00,$00,$00,$00,$00,$00,$00,$00
.byte $00,$00,$00,$00,$00,$00,$00,$00
.byte $00,$00,$00,$00,$00,$00,$00,$00
.byte $00,$00,$00,$00,$00,$00,$00,$00
.byte $00,$00,$00,$00,$00,$00,$00,$00
.byte $00,$00,$00,$00,$00,$00,$00,$00


sprite:
.byte  80,  80,  80
.byte  80,  80,  80
.byte  80,  80,  80
.byte  80,  80,  80
.byte  80,  80,  80
.byte  80,  80,  80
.byte  80,  80,  80
.byte  80,  80,  80
.byte  80,  80,  80
.byte  80,  80,  80
.byte  80,  80,  80
.byte  80,  80,  80
.byte  80,  80,  80
.byte  80,  80,  80
.byte  80,  80,  80
.byte  80,  80,  80
.byte  80,  80,  80
.byte  80,  80,  80
.byte  80,  80,  80
.byte  80,  80,  80
.byte  80,  80,  80

