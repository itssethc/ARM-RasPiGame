            .equ    BASE, 0x3F200000    @GPIO Basse Addr
            .equ    SEL0, 0x3F200000    @GPIO_GPFSEL0
            .equ    SEL1, 0x3F200004    @GPIO_GPFSEL1
            .equ    SEL2, 0x3F200008    @GPIO_GPFSEL2
            .equ    SET0, 0x3F20001C    @GPIO_GPSET0 
            .equ    CLR0, 0x3F200028    @GPIO_GPCLRO
            .equ    EDS0, 0x3F200040    @GPIO_GPEDS0
            .equ    FEN0, 0x3F200058    @GPIO_GPFEN0

@ ======================================
@ [LIGHT] sub procedure
@ ======================================
@
@ Purpose:
@ +++++++
@ Turn a light on by setting the pin given from upper TURNON(N) procedure
@
@ Initial Condition:
@ ++++++++++++
@ Preserve regs, have stack as shown below:
@     STACK POP ORDER: CLR0, SET(n), SEL(other), TOGGLE(n), SEL(1/2), SET0, SPEED
@
@ Final Condition:
@ ++++++++++++
@ Registers are restored. Variables set at .data level.
@ The appropriate pin will be toggled on to display light, 
@   no other light should be on at return.
@
@ Registers Used: R0-R5, pc, lr, sp, fp
@
@ Sample Case:
@ ++++++++++
@    TURNON16 is called, bit 16 is set as the only pin and turns on the light at pin 16.
@ =======================================   


            .global LIGHT
LIGHT:
            stmfd   sp!, {R0-R5, fp, lr}    @ preserve regs and return address  
            mov     fp, sp                  @ setup local frame pointer
            @ Turn off anything that's on already
            ldr     R0, [fp,#32]            @ Load addr of GPIO_GPCLR0
            ldr     R1, [fp,#36]            @ Load in mask to set pins LOW/HIGH
            ldr     R1, [R1]                @ Get value of mask
            str     R1, [R0]                @ Put mask in GPCLR0 to set pin to LOW
            ldr     R5, [fp,#40]            @ Load addr of other SEL(n)
            mov     R3, #0                  @ Clear any bits from before
            str     R3, [R5]                @ Store mask of 0
            @ Set your PIN as output
            ldr     R2, [fp,#44]            @ Load in mask to set pin to OUTPUT
            ldr     R2, [R2]                @ Get value of mask
            ldr     R3, [fp,#48]            @ Load addr of GPSEL(n)
            str     R2, [R3]                @ Put mask in GPSEL(n)
            @ Turn the light on
            ldr     R4, [fp,#52]            @ Load in SET0 
            str     R1, [R4]                @ Put mask in GPSET0 to set pin to HIGH
            @ Wait a bit
            ldr     R5, [fp,#56]            @ Load in SPEED
            ldr     R5, [R5]                @ Get value of SPEED
            wait:
            sub     R5, #1                  @ Subtract from SPEED
            cmp     R5, #0                  @ Loop until you are at 0
            bne     wait
            @ Leave procedure
            mov     sp, fp                  @ release local frame pointer
            ldmfd   sp!, {R0-R5, fp, pc}    @ Restore regs and return

@ ======================================
@ [BUTTON] sub procedure
@ ======================================
@
@ Purpose:
@ +++++++
@ Check the button for a press, and if a press is detected account for bounce
@   by checking over a loop for new edge detections. Returns 1 for a press and
@   0 for no press detected.
@
@ Initial Condition:
@ ++++++++++++
@ Preserve regs, have R6 unused in source to return boolean to
@
@ Final Condition:
@ ++++++++++++
@ Registers are restored. Variables set at .data level.
@ The appropriate pin will be toggled on to display light, 
@   no other light should be on at return.
@
@ Registers Used: R0-R6, pc, lr, sp, fp
@
@ Sample Case:
@ ++++++++++
@    If button is pressed, check for bounce and then return 1 to R6.
@ =======================================       

            .globl  BUTTON
BUTTON:
            stmfd   sp!, {R0-R5, fp, lr}   @ preserve regs and return address  
            mov     fp, sp
            @ Check if pressed
            PRESSED:
            mov     R5, #0                  @ Initial counter for GCHECK
            ldr     R0, =EDS0               @ Load addr of GPEDS0
            mov     R1, #0b00000000000000000010000000000000 @ Mask for pin 25
            ldr     R2, [R0]                @ Initial value
            and     R3, R2, R1              @ Set pin 25 with AND
            cmp     R3, R1                  @ Edge event detected?
            bne     EXITBUTTON
            GCHECK:     
            @ Register press in R6 as 1
            mov     R6, #1                  @ Set boolean for return to true
            mov     R1, #0b00000000000000000010000000000000 @ Maskfor pin 25
            str     R1, [R0]                @ Clear
            ldr     R0, =EDS0               @ Load EDS0 back in
            mov     R1, #0b00000000000000000010000000000000 @ Mask for pin 25
            ldr     R2, [R0]                @ Get value at EDS0
            and     R3, R2, R1              @ Set pin with AND
            cmp     R3, R1                  @ Another event detected?
            beq     GCHECK
            add     R5, #1                  @ No event detected, tick counter
            cmp     R5, #0x00080000         @ Have we allowed enough errors?
            blo     GCHECK
            @ Increase speed after we know it's a press
            ldr     R1, =SPEED              @ Load SPEED address
            ldr     R2, [R1]                @ Original value
            @ Multiply by 9, divide by 8, subtract original value to get ~0.88 to 0.9 original value
            mov     R3, #9                  @ 9 for mul operation below
            mul     R4, R2, R3              @ OG * 9
            lsr     R3, R4, #3              @ (OG * 9) / 8
            sub     R4, R3, R2              @ ((OG * 9) / 8) - OG = ~10% of OG
            sub     R3, R2, R4              @ Take off the 10% of OG
            str     R3, [R1]                @ Place new speed in SPEED
            b       EXITBUTTON
            NOPRESS:
            mov     R6, #0                  @ Set boolean for return to false
            EXITBUTTON:
            @ Leave procedure
            mov     sp, fp                  @ release local frame pointer
            ldmfd   sp!, {R0-R5, fp, pc}    @ Restore regs and return

@ ======================================
@ [RESETSPEED] sub procedure
@ ======================================
@
@ Purpose:
@ +++++++
@ Reset the SPEED variable used for the game to the SPEED2 variable used elsewhere
@
@ Initial Condition:
@ ++++++++++++
@ Preserve regs.
@
@ Final Condition:
@ ++++++++++++
@ Registers are restored. SPEED reset to SPEED2 value.
@
@ Registers Used: R1, R2, fp, lr, pc
@
@ =======================================       

            .globl  RESETSPEED
RESETSPEED:
            stmfd   sp!, {R1, R2, fp, lr}   @ preserve regs and return address  
            mov     fp, sp
            ldr     R1, =SPEED              @ Load current speed
            ldr     R2, =SPEED2             @ Load origin speed
            ldr     R2, [R2]                @ Get origin speed value
            str     R2, [R1]                @ Push origin speed 
            @ Leave procedure
            mov     sp, fp                  @ release local frame pointer
            ldmfd   sp!, {R1, R2, fp, pc}   @ Restore regs and return

@ ======================================
@ [SHOWSCORE] sub procedure
@ ======================================
@
@ Purpose:
@ +++++++
@ Show the game score in binary using 5 LEDs to display bits 0-4. Max score shown is 31.
@
@ Initial Condition:
@ ++++++++++++
@ Preserve regs. R8 needs to contain score from source
@
@ Final Condition:
@ ++++++++++++
@ Registers are restored. Binary is displayed as each light being a bit 0-4
@
@ Registers Used: R0-R5, R9 fp, lr, pc
@
@ =======================================            

            .global SHOWSCORE
SHOWSCORE:
            stmfd   sp!, {R0-R5, fp, lr}    @ preserve regs and return address  
            mov     fp, sp                  @ setup local frame pointer
            @ Turn off anything that's on already
            ldr     R5, =SEL2               @ Load addr of other SEL(n)
            mov     R3, #0                  @ Clear any bits from before
            str     R3, [R5]                @ Put mask in GPCLR0 to set pin to LOW
            ldr     R5, =SEL1               @ Load addr of other SEL(n)
            mov     R3, #0                  @ Clear any bits from before
            str     R3, [R5]                @ Store mask of 0
    @ !!! ----- > Points are in R6
            mov     R9, #0b00000000000000000000000000000001 @ Set to 1 for AND mask

            @ Set first LED, the 0th bit?
            CHECK1:
            and     R2, R8, R9              @ Is the bit set?
            lsr     R8, #1                  @ Move next bit over 
            cmp     R2, #1                  @ Set? if so light LED
            bne     CHECK2
            FIRSTSET:
            @ Set your PIN as output
            ldr     R1, =SET21              @ Load in mask to set pins LOW/HIGH
            ldr     R2, =TOGGLE21           @ Load in mask to set pin to OUTPUT
            ldr     R2, [R2]                @ Get value of mask
            ldr     R3, =SEL2               @ Load addr of GPSEL(n)
            str     R2, [R3]                @ Put mask in GPSEL(n)
            @ Turn the light on
            ldr     R4, =SET0               @ Load in SET0 
            str     R1, [R4]                @ Put mask in GPSET0 to set pin to HIGH

            @ Set second LED, the 1th bit?
            CHECK2:
            and     R2, R8, R9              @ Is the bit set?
            lsr     R8, #1                  @ Move next bit over 
            cmp     R2, #1                  @ Set? if so light LED
            bne     CHECK3
            SECONDSET:
            @ Set your PIN as output
            ldr     R1, =SET20              @ Load in mask to set pins LOW/HIGH
            ldr     R2, =TOGGLE20           @ Load in mask to set pin to OUTPUT
            ldr     R2, [R2]                @ Get value of mask
            ldr     R3, =SEL2               @ Load addr of GPSEL(n)
            str     R2, [R3]                @ Put mask in GPSEL(n)
            @ Turn the light on
            ldr     R4, =SET0               @ Load in SET0 
            str     R1, [R4]                @ Put mask in GPSET0 to set pin to HIGH

            @ Set third LED, the 2th bit?
            CHECK3:
            and     R2, R8, R9              @ Is the bit set?
            lsr     R8, #1                  @ Move next bit over 
            cmp     R2, #1                  @ Set? if so light LED
            bne     CHECK4
            THIRDSET:
            @ Set your PIN as output
            ldr     R1, =SET16              @ Load in mask to set pins LOW/HIGH
            ldr     R2, =TOGGLE16           @ Load in mask to set pin to OUTPUT
            ldr     R2, [R2]                @ Get value of mask
            ldr     R3, =SEL1               @ Load addr of GPSEL(n)
            str     R2, [R3]                @ Put mask in GPSEL(n)
            @ Turn the light on
            ldr     R4, =SET0               @ Load in SET0 
            str     R1, [R4]                @ Put mask in GPSET0 to set pin to HIGH

            @ Set fourth LED, the 3th bit?
            CHECK4:
            and     R2, R8, R9              @ Is the bit set?
            lsr     R8, #1                  @ Move next bit over 
            cmp     R2, #1                  @ Set? if so light LED
            bne     CHECK5
            FOURTHSET:
            @ Set your PIN as output
            ldr     R1, =SET12              @ Load in mask to set pins LOW/HIGH
            ldr     R2, =TOGGLE12           @ Load in mask to set pin to OUTPUT
            ldr     R2, [R2]                @ Get value of mask
            ldr     R3, =SEL1               @ Load addr of GPSEL(n)
            str     R2, [R3]                @ Put mask in GPSEL(n)
            @ Turn the light on
            ldr     R4, =SET0               @ Load in SET0 
            str     R1, [R4]                @ Put mask in GPSET0 to set pin to HIGH

            @ Set fifth LED, the 4th bit?
            CHECK5:
            and     R2, R8, R9              @ Is the bit set?
            lsr     R8, #1                  @ Move next bit over 
            cmp     R2, #1                  @ Set? if so light LED
            bne     ENDSHOW
            FIFTHSET:
            @ Set your PIN as output
            ldr     R1, =SET26              @ Load in mask to set pins LOW/HIGH
            ldr     R2, =TOGGLE26           @ Load in mask to set pin to OUTPUT
            ldr     R2, [R2]                @ Get value of mask
            ldr     R3, =SEL2               @ Load addr of GPSEL(n)
            str     R2, [R3]                @ Put mask in GPSEL(n)
            @ Turn the light on
            ldr     R4, =SET0               @ Load in SET0 
            str     R1, [R4]                @ Put mask in GPSET0 to set pin to HIGH

            ENDSHOW:
            @ Leave procedure
            mov     sp, fp                  @ release local frame pointer
            ldmfd   sp!, {R0-R5, fp, pc}    @ Restore regs and return


@ ======================================
@ [TURNON(N)] sub procedures
@ ======================================
@
@ Purpose:
@ +++++++
@ All TURNON(N) calls will push appropriate addresses and masks to 
@   set the pin (N) to be lit in the LIGHT procedure. The only call
@   that differs from the rest is pin 25, which uses a dummy call after
@   its initial to simulate the clearing and setting of a phantom pin
@   too loop it's blinks.
@
@ Initial Condition:
@ ++++++++++++
@ Preserve regs. Have appropriate masks in .data.
@
@ Final Condition:
@ ++++++++++++
@ Registers are restored. The pin (N) will be set, all others cleared 
@   and the light should be on.
@
@ Registers Used: R0-R6, fp, lr, pc
@
@ ======================================= 
            .globl  TURNON12
TURNON12:
@     @     @     @     @     @     @     @     @     @     @     

@     LIGHT 12

@     @     @     @     @     @     @     @     @     @     @
            stmfd   sp!, {R0-R6, fp, lr}   @ preserve regs and return address  
            mov     fp, sp
            LIGHTUP12:
            @ Set defaults always used
            ldr     R0, =SET0
            ldr     R1, =CLR0
            ldr     R2, =SPEED
            @ SET(n), TOGGLE(n), and SEL(1 or 2) are specific to their call
        @ Turn on second light
            ldr     R3, =SET12
            ldr     R4, =TOGGLE12
            ldr     R5, =SEL1
            ldr     R6, =SEL2
            @ Must push to stack in this order
            str     R2, [sp, #-4]!      @ Push SPEED
            str     R0, [sp, #-4]!      @ Push SET
            str     R5, [sp, #-4]!      @ Push SEL(1 or 2)
            str     R4, [sp, #-4]!      @ Push TOGGLE(n)
            str     R6, [sp, #-4]!      @ Push SEL(1 or 2)
            str     R3, [sp, #-4]!      @ Push SET(n)
            str     R1, [sp, #-4]!      @ Push CLR
            bl      LIGHT
            @ Leave procedure
            mov     sp, fp                  @ release local frame pointer
            ldmfd   sp!, {R0-R6, fp, pc}   @ Restore regs and return

            .globl  TURNON16
TURNON16:
@     @     @     @     @     @     @     @     @     @     @     

@     LIGHT 16

@     @     @     @     @     @     @     @     @     @     @
            stmfd   sp!, {R0-R6, fp, lr}   @ preserve regs and return address  
            mov     fp, sp
            LIGHTUP16:
            ldr     R0, =SET0
            ldr     R1, =CLR0
            ldr     R2, =SPEED
            @ SET(n), TOGGLE(n), and SEL(1 or 2) are specific to their call
        @ Turn on third light
            ldr     R3, =SET16
            ldr     R4, =TOGGLE16
            ldr     R5, =SEL1
            ldr     R6, =SEL2
            @ Must push to stack in this order
            str     R2, [sp, #-4]!      @ Push SPEED
            str     R0, [sp, #-4]!      @ Push SET
            str     R5, [sp, #-4]!      @ Push SEL(1 or 2)
            str     R4, [sp, #-4]!      @ Push TOGGLE(n)
            str     R6, [sp, #-4]!      @ Push SEL(1 or 2)
            str     R3, [sp, #-4]!      @ Push SET(n)
            str     R1, [sp, #-4]!      @ Push CLR
            bl      LIGHT
            @ Leave procedure
            mov     sp, fp                  @ release local frame pointer
            ldmfd   sp!, {R0-R6, fp, pc}   @ Restore regs and return

            .globl  TURNON20
TURNON20:
@     @     @     @     @     @     @     @     @     @     @     

@     LIGHT 20

@     @     @     @     @     @     @     @     @     @     @
            stmfd   sp!, {R0-R6, fp, lr}   @ preserve regs and return address  
            mov     fp, sp
            LIGHTUP20:
            ldr     R0, =SET0
            ldr     R1, =CLR0
            ldr     R2, =SPEED
            @ SET(n), TOGGLE(n), and SEL(1 or 2) are specific to their call
        @ Turn on fourth light
            ldr     R3, =SET20
            ldr     R4, =TOGGLE20
            ldr     R5, =SEL2
            ldr     R6, =SEL1
            @ Must push to stack in this order
            str     R2, [sp, #-4]!      @ Push SPEED
            str     R0, [sp, #-4]!      @ Push SET
            str     R5, [sp, #-4]!      @ Push SEL(1 or 2)
            str     R4, [sp, #-4]!      @ Push TOGGLE(n)
            str     R6, [sp, #-4]!      @ Push SEL(1 or 2)
            str     R3, [sp, #-4]!      @ Push SET(n)
            str     R1, [sp, #-4]!      @ Push CLR
            bl      LIGHT
            @ Leave procedure
            mov     sp, fp                  @ release local frame pointer
            ldmfd   sp!, {R0-R6, fp, pc}   @ Restore regs and return

            .globl  TURNON21
TURNON21:
@     @     @     @     @     @     @     @     @     @     @     

@     LIGHT 21

@     @     @     @     @     @     @     @     @     @     @
            stmfd   sp!, {R0-R6, fp, lr}   @ preserve regs and return address  
            mov     fp, sp
            LIGHTUP21:
            ldr     R0, =SET0
            ldr     R1, =CLR0
            ldr     R2, =SPEED
            @ SET(n), TOGGLE(n), and SEL(1 or 2) are specific to their call
        @ Turn on fif light
            ldr     R3, =SET21
            ldr     R4, =TOGGLE21
            ldr     R5, =SEL2
            ldr     R6, =SEL1
            @ Must push to stack in this order
            str     R2, [sp, #-4]!      @ Push SPEED
            str     R0, [sp, #-4]!      @ Push SET
            str     R5, [sp, #-4]!      @ Push SEL(1 or 2)
            str     R4, [sp, #-4]!      @ Push TOGGLE(n)
            str     R6, [sp, #-4]!      @ Push SEL(1 or 2)
            str     R3, [sp, #-4]!      @ Push SET(n)
            str     R1, [sp, #-4]!      @ Push CLR
            bl      LIGHT
            @ Leave procedure
            mov     sp, fp                  @ release local frame pointer
            ldmfd   sp!, {R0-R6, fp, pc}   @ Restore regs and return

            .globl  TURNON25
TURNON25:
@     @     @     @     @     @     @     @     @     @     @     

@     LIGHT 25

@     @     @     @     @     @     @     @     @     @     @
            stmfd   sp!, {R0-R6, fp, lr}   @ preserve regs and return address  
            mov     fp, sp
            LIGHTUP25:
            ldr     R0, =SET0
            ldr     R1, =CLR0
            ldr     R2, =SPEED2
            @ SET(n), TOGGLE(n), and SEL(1 or 2) are specific to their call
        @ Turn on first light
            ldr     R3, =SET25
            ldr     R4, =TOGGLE25
            ldr     R5, =SEL2
            ldr     R6, =SEL1
            @ Must push to stack in this order
            str     R2, [sp, #-4]!      @ Push SPEED
            str     R0, [sp, #-4]!      @ Push SET
            str     R5, [sp, #-4]!      @ Push SEL(1 or 2)
            str     R4, [sp, #-4]!      @ Push TOGGLE(n)
            str     R6, [sp, #-4]!      @ Push SEL(1 or 2)
            str     R3, [sp, #-4]!      @ Push SET(n)
            str     R1, [sp, #-4]!      @ Push CLR
            bl      LIGHT
            LIGHTUP2X: @ Dummy call for phantom button, this was quick and lazy
            @ and I just noticed I never did it better as I documented. Sorry.
            ldr     R0, =SET0
            ldr     R1, =CLR0
            ldr     R2, =SPEED2
            @ SET(n), TOGGLE(n), and SEL(1 or 2) are specific to their call
        @ Turn on first light
            ldr     R3, =SET25
            ldr     R4, =TOGGLE25
            ldr     R5, =SEL1
            ldr     R6, =SEL2
            @ Must push to stack in this order
            str     R2, [sp, #-4]!      @ Push SPEED
            str     R0, [sp, #-4]!      @ Push SET
            str     R5, [sp, #-4]!      @ Push SEL(1 or 2)
            str     R4, [sp, #-4]!      @ Push TOGGLE(n)
            str     R6, [sp, #-4]!      @ Push SEL(1 or 2)
            str     R3, [sp, #-4]!      @ Push SET(n)
            str     R1, [sp, #-4]!      @ Push CLR
            bl      LIGHT
            @ Leave procedure
            mov     sp, fp                  @ release local frame pointer
            ldmfd   sp!, {R0-R6, fp, pc}   @ Restore regs and return

            .globl  TURNON26
TURNON26:
@     @     @     @     @     @     @     @     @     @     @     

@     LIGHT 26

@     @     @     @     @     @     @     @     @     @     @
            stmfd   sp!, {R0-R6, fp, lr}   @ preserve regs and return address  
            mov     fp, sp
            LIGHTUP26:
            ldr     R0, =SET0
            ldr     R1, =CLR0
            ldr     R2, =SPEED

            @ SET(n), TOGGLE(n), and SEL(1 or 2) are specific to their call

        @ Turn on first light
            ldr     R3, =SET26
            ldr     R4, =TOGGLE26
            ldr     R5, =SEL2
            ldr     R6, =SEL1
            @ Must push to stack in this order
            str     R2, [sp, #-4]!      @ Push SPEED
            str     R0, [sp, #-4]!      @ Push SET
            str     R5, [sp, #-4]!      @ Push SEL(1 or 2)
            str     R4, [sp, #-4]!      @ Push TOGGLE(n)
            str     R6, [sp, #-4]!      @ Push SEL(1 or 2)
            str     R3, [sp, #-4]!      @ Push SET(n)
            str     R1, [sp, #-4]!      @ Push CLR
            bl      LIGHT
            @ Leave procedure
            mov     sp, fp                  @ release local frame pointer
            ldmfd   sp!, {R0-R6, fp, pc}   @ Restore regs and return

            .data
@ TOGGLE (N) are masks to set pins to output
TOGGLE12:   .word       0b00000000000000000000000001000000
TOGGLE16:   .word       0b00000000000001000000000000000000
TOGGLE20:   .word       0b00000000000000000000000000000001
TOGGLE21:   .word       0b00000000000000000000000000001000
TOGGLE25:   .word       0b00000000000000001000000000000000
TOGGLE26:   .word       0b00000000000001000000000000000000
@ SET(N) are maskes to set the bits on
SET12:      .word       0b00000000000000000001000000000000
SET16:      .word       0b00000000000000010000000000000001
SET20:      .word       0b00000000000100000000000000000001
SET21:      .word       0b00000000001000000000000000000001
SET25:      .word       0b00000010000000000000000000000001
SET26:      .word       0b00000100000000000000000000000001
@ SPEED variables used to keep lives blink slow, and to retain
@ initial value of SPEED used in game mode.
SPEED2:     .word       0x00100000
SPEED:      .word       0x00100000

@ EOF --- Keep New Line After This
