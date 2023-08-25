;------------------------------
; Animated Checkerboard
; Based on the orginal code by Gemanix - http://aminet.net/package/demo/intro/Gemanix
; Bug fixed for AGA by Robert Price - https://www.robertprice.co.uk/
;
; This uses a raw image on a single bitplane that has vertical stripes 
; radiating from the centre downwards alternating between two colours.
; The copper is used to change the colour of these stripes on different
; lines, giving the checkerboard effect. An interrupt moves the lines
; the colour changes occur on, giving the illusion of movement.
;
; image used is 368x290 pixels.

;---------- Includes ----------
            INCDIR   "include"
            INCLUDE  "hw.i"
            INCLUDE  "funcdef.i"
            INCLUDE  "exec/exec_lib.i"
            INCLUDE  "graphics/graphics_lib.i"
            INCLUDE  "hardware/cia.i"
;---------- Const ----------

            SECTION  "Checkers",CODE_C

            lea      CUSTOM,a5
            move.l   4.w,a6
            jsr      -132(a6)       ; Forbid

            move.w   DMACONR(a5),d0
            or.w     #$8000,d0
            move.w   d0,OldDMACON

            move.w   INTENAR(a5),d0		
            or.w     #$c000,d0
            move.w   d0,IntEna

; move the address of the checkerboard image into the copperlist BPL1PTH and BPL1PTL registers.
            move.l   #ChkData,d0
            lea      BPL(pc),a0
            move.w   d0,6(a0)
            swap     d0
            move.w   d0,2(a0)

; setup the interrupt that will animate the checkerboard image.
            move.w   #$7fff,INTENA(a5)
            move.w   #$7fff,INTREQ(a5)
            move.l   $6c.w,OldIRQ               ; save the old interrupt address so we can restore it later.
            move.l   #NewIRQ,$6c.w              ; place our interrupt address in the level 3 interrupt vector.
            move.w   #$c020,INTENA(a5)          ; Enable VERTB interrupts (vertical blank).

; enable the copperlist.
            move.w   #$00a0,DMACON(a5)          ; disable the Copper and sprites.
            move.l   #CList,COP1LC(a5)          ; point the Copper at our new CopperList.
            move.w   #$0000,COPJMP1(a5)
            move.w   #$8180,DMACON(a5)          ; enable Bitplanes and the Copper.
            move.l   #0,SPR0DATA(a5)

; wait for the left mouse button to be clicked.
WaitMse     btst     #6,$bfe001
            bne      WaitMse

; restore the original copper list.
            move.l   $9c(a6),a0
            move.w   #$0080,DMACON(a5)
            move.l   38(a0),COP1LC(a5)
            move.w   #$0000,COPJMP1(a5)
            move.w   #$80a0,DMACON(a5)

; restore the original vblank interrupt.
            move.w   #$7fff,INTENA(a5)
            move.w   #$7fff,INTREQ(a5)
            move.l   OldIRQ(PC),$6c.w               ; restore the old systen level 3 interrupt address.
            move.w   IntEna(PC),INTENA(a5)

; restore multitasking.
            jsr      -138(a6)       ; Permit

; return 0 in D0 to tell the OS we successfully finished.
            moveq    #0,d0
            rts

;--------------------------------------;
; the interrupt handler that is run to animate the checkerboard.
NewIRQ      movem.l  d0-a6,-(a7)
            bsr      Chckers
            bsr      Chckers
            movem.l  (a7)+,d0-a6
            move.w   #$0020,INTREQ(a5)      ; clear VERTB interrupt flag
            move.w   #$0020,INTREQ(a5)      ; and again for compatibility reasons.
            rte

;--------------------------------------;
; the actual checkerboard animation.
Chckers     subq.b   #1,PsTbCnt
            bne.b    NClrGrp
            move.b   #16,PsTbCnt
            move.l   #PosTble,PsTbPnt

            moveq    #8,d2
            lea      ChkrPos+6(pc),a0
            lea      ChkrPos+10(pc),a1
ColChng     moveq    #0,d0
            moveq    #0,d1
            move.w   (a0),d0
            move.w   (a1),d1
            move.w   d1,(a0)
            move.w   d0,(a1)
            lea      12(a0),a0
            lea      12(a1),a1
            dbf      d2,ColChng
    
NClrGrp     lea      ChkrPos(pc),a0
            move.l   PsTbPnt(pc),a1
            move.w   #8,d0
NewPosC     move.b   (a1)+,(a0)
            add.l    #12,a0
            dbf      d0,NewPosC
            add.l    #9,PsTbPnt
            rts	

;--------------------------------------;

OldDMACON	dc.w     0
IntEna      dc.w     0
OldIRQ      dc.l     0
PsTbPnt     dc.l     PosTble
PsTbCnt     dc.b     1

;--------------------------------------;
; The Copper list
; image used is 368x290 pixels.
			CNOP	 0,8									; Align to 64 bit boundary

CList       
			dc.w	 $106,$c00								; AGA sprites, palette and dual playfield reset - bplcon3
			dc.w	 $1FC,0									; AGA sprites and burst reset - fmode

			dc.w     DIWSTRT,$0568                          ; v=5,  h=104
            dc.w     DIWSTOP,$40d1                          ; v=64, h=209
            dc.w     DDFSTRT,$0028,DDFSTOP,$00d8
            dc.w     BPL1MOD,$0000,BPL2MOD,$0000

            dc.w     $b609,$fffe                            ; Wait for vpos >= 0xb6 and hpos >= 0x8
            dc.w     BPLCON0,$1200                          ; 1 bit plane, enable colour burst.
BPL         dc.w     BPL1PTH,$0000,BPL1PTL,$0000
            dc.w     COLOR00,$0000,COLOR01,$0000

ChkrPos     dc.w     $b509,$fffe                            ; Wait for vpos >= 0xb5 and hpos >= 0x8
            dc.w     COLOR00,$0000,COLOR01,$0333
            dc.w     $b609,$fffe                            ; Wait for vpos >= 0xb6 and hpos >= 0x8
            dc.w     COLOR00,$0555,COLOR01,$0000
            dc.w     $b909,$fffe                            ; Wait for vpos >= 0xb9 and hpos >= 0x8
            dc.w     COLOR00,$0000,COLOR01,$0777
            dc.w     $bd09,$fffe                            ; Wait for vpos >= 0xbd and hpos >= 0x8
            dc.w     COLOR00,$0999,COLOR01,$0000
            dc.w     $c109,$fffe                            ; Wait for vpos >= 0xc1 and hpos >= 0x8
            dc.w     COLOR00,$0000,COLOR01,$0bbb
            dc.w     $c709,$fffe                            ; Wait for vpos >= 0xc7 and hpos >= 0x8
            dc.w     COLOR00,$0ddd,COLOR01,$0000
            dc.w     $ce09,$fffe                            ; Wait for vpos >= 0xce and hpos >= 0x8
            dc.w     COLOR00,$0000,COLOR01,$0fff
            dc.w     $d809,$fffe                            ; Wait for vpos >= 0xd8 and hpos >= 0x8
            dc.w     COLOR00,$0fff,COLOR01,$0000
            dc.w     $e509,$fffe                            ; Wait for vpos >= 0xe5 and hpos >= 0x8
            dc.w     COLOR00,$0000,COLOR01,$0fff

            dc.w     $f409,$fffe                            ; Wait for vpos >= 0xf4 and hpos >= 0x8
            dc.w     BPLCON0,$0200
            dc.w     COLOR00,$0000,COLOR01,$0000

            dc.w     $ffff,$fffe                            ; End of CopperList

;--------------------------------------;
; PosTable is a list of vertical positions to use in the copperlist
; for the colour changes.
PosTble     dc.b     $b5,$b6,$b9,$bd,$c1,$c7,$ce,$d8,$e5
            dc.b     $b5,$b6,$b9,$bd,$c1,$c7,$cf,$d9,$e6
            dc.b     $b5,$b6,$b9,$bd,$c2,$c8,$d0,$da,$e8
            dc.b     $b5,$b6,$ba,$be,$c2,$c8,$d0,$db,$e9
            dc.b     $b5,$b7,$ba,$be,$c3,$c9,$d1,$db,$ea
            dc.b     $b5,$b7,$ba,$be,$c3,$c9,$d2,$dc,$eb
            dc.b     $b5,$b7,$bb,$bf,$c3,$ca,$d3,$dd,$ec
            dc.b     $b5,$b7,$bb,$bf,$c4,$ca,$d3,$de,$ed

            dc.b     $b6,$b8,$bb,$bf,$c4,$cb,$d4,$de,$ee
            dc.b     $b6,$b8,$bb,$bf,$c5,$cb,$d4,$df,$ef
            dc.b     $b6,$b8,$bc,$c0,$c5,$cc,$d5,$e0,$f0
            dc.b     $b6,$b8,$bc,$c0,$c6,$cc,$d6,$e1,$f1
            dc.b     $b6,$b9,$bc,$c0,$c6,$cd,$d6,$e3,$f2
            dc.b     $b6,$b9,$bd,$c1,$c6,$cd,$d7,$e3,$f3
            dc.b     $b6,$b9,$bd,$c1,$c7,$ce,$d8,$e4,$f4
            dc.b     $b6,$b9,$bd,$c1,$c7,$ce,$d8,$e5,$f4

;--------------------------------------;
; our checkerboard image.
			EVEN
ChkData     incbin   "Checkers.raw"

