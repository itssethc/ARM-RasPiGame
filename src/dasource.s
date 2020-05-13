            .equ    FEN0, 0x3F200058    @GPIO_GPFEN0

            .text
            .global _start

_start:
            @ Initialize stack pointer
            ldr     sp, =_stack_start
            @ Turn button to falling edge detect (GPIO_13)
            ldr     R0, =FEN0
            mov     R1, #0b00000000000000000010000000000000
            str     R1, [R0]
        @ General Notes --------------------------------------------------------------------------
            @ R6 is always a boolean setter, never touch outside of setting and checking        --
            @ R8 is always for keeping score, never touch outside of setting and resetting      --
            @ All procedures TURNON(N) clear all current lights and toggle pin N                --
            @ Button call checks for a press and return 1 for a press and 0 for no press to R6  --
        @ ----------------------------------------------------------------------------------------

@ Start the game
GAME:
            @ Start/clear boolean for press
            mov     R6, #0
            @ Start/clear score
            mov     R8, #0 
@ ! ! ! @ ------ > Every cmp R6, #1 is checking for a button press via the boolean
            @ Check for button to start game
            bl      BUTTON 
            cmp     R6, #1
            beq     LIGHTS
            b       GAME

@ Cycle through the lights and look for button press
LIGHTS:
            @ Clear boolean of stepping button press
            mov     R6, #0

            @ Turn the lights on one by one, checking for button presses in between          
            bl      TURNON26
            bl      BUTTON 
            cmp     R6, #1
            beq     MISS

            bl      TURNON12
            bl      BUTTON 
            cmp     R6, #1
            beq     MISS
            
            bl      TURNON16
            bl      BUTTON 
            cmp     R6, #1
            beq     SCORE
            
            bl      TURNON20
            bl      BUTTON 
            cmp     R6, #1
            beq     MISS
            
            bl      TURNON21
            bl      BUTTON 
            cmp     R6, #1
            beq     MISS
            
            bl      TURNON20
            bl      BUTTON 
            cmp     R6, #1
            beq     MISS
            
            bl      TURNON16
            bl      BUTTON 
            cmp     R6, #1
            beq     SCORE
            
            bl      TURNON12
            bl      BUTTON 
            cmp     R6, #1
            beq     MISS
            
            @ Loop back up, reset stack so it doesn't ever overflow
            ldr     sp, =_stack_start
            b       LIGHTS
SCORE:  
            @ Increase score by one
            add     R8, #1
            b       LIGHTS
MISS: 
            @ Take a life, decreasing by 1
            ldr     R1, =LIVES
            ldr     R2, [R1]
            sub     R2, #1
            str     R2, [R1] 
            @ Flash once per remaining life, if any
            CHECKLIVES:
            cmp     R2, #0 
            @ Go to game over if we have 0 lives
            beq     GAMEOVER
            @ Otherwise blink yellow light once per life
            SHOWLIVES:
            bl      TURNON25
            sub     R2, #1
            cmp     R2, #0
            beq     LIGHTS     
            b       SHOWLIVES
GAMEOVER:
            @ Little animation
            bl      RESETSPEED
            bl      TURNON26
            bl      TURNON16
            bl      TURNON21
            @ Show score
            bl      SHOWSCORE
            @ Clear lives to original
            mov     R3, #5
            str     R3, [R1]
            b       GAME

            .data

LIVES:      .word       0x00000005
_stack_end: .skip       4096 @ allocate 4096 bytes of stack space
_stack_start:

@ EOF --- Keep New Line After This
