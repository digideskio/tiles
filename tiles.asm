    opt l-h+f-
    icl 'hardware.asm'
    org $80
coarse org *+2
fine org *+1
mappos org *+2
mapfrac org *+1
tilepos org *+2
mapy org *+1
edgeoff org *+1
tmp org *+1
framecount org *+1
pmbank org *+1
inflate_zp equ $f0

main equ $2000
dlist equ $3000
pm equ $3400
song equ $4000
player equ $6000
scr equ $9000
map equ $b000
chset equ $c000
buffer equ $8000
linewidth equ $40
hx equ 100
hy equ 100

    org main
relocate
    sei
    lda #0
    sta IRQEN
    sta NMIEN
    sta DMACTL
    cmp:rne VCOUNT
    ldx buffer+4
    lda banks,x
    sta PORTB
    mwa #buffer+5 ld+1
    mwa buffer st+1
ld  lda $ffff
st  sta $ffff
    inc ld+1
    sne:inc ld+2
    inc st+1
    sne:inc st+2
    lda st+1
    cmp buffer+2
    bne ld
    lda st+2
    cmp buffer+3
    bne ld
    mva #$83 PORTB
    rts
banks
    :64 dta $82+[[#%4]<<2]
    ;:64 dta [[#*4]&$e0] | [[#*2]&$f] | $01
inflate
    icl 'inflate.asm'

    org dlist
    :30 dta $54,a(scr+#<<6)
    dta $41,a(dlist)
    icl 'assets.asm'
    icl 'sprites.asm'
    org song
    ins 'ruffw1.tm2',6
    org player
    icl 'tmc2play.asm'

    org main
    sei
    lda #0
    sta IRQEN
    sta NMIEN
    sta DMACTL
    sta COLBK
    sta fine
    sta edgeoff
    sta COLPF3
    sta SIZEP0
    sta SIZEP1
    sta SIZEP2
    sta SIZEP3
    mva #$ff SIZEM
    mva #$11 PRIOR
    mva #3 GRACTL
    mva #$3a COLPM0
    sta COLPM1
    sta COLPM2
    sta COLPM3
    mva #hx HPOSP0
    sta HPOSM3
    mva #hx+8 HPOSP1
    sta HPOSM2
    mva #hx+16 HPOSP2
    sta HPOSM1
    mva #hx+24 HPOSP3
    sta HPOSM0

    mva #$82 PORTB
    lda #$70
    ldy <song
    ldx >song
    jsr player+$300 ; init
    lda #0
    tax
    jsr player+$300 ; init
    mwa #scr coarse
    mva >chset CHBASE
initdraw
    jsr drawedgetiles
    inc coarse
    lda coarse
    cmp #49
    bne initdraw
    mva <scr coarse

    ;mva #$22 DMACTL
    ;mva #$2d DMACTL
    mva #$3e DMACTL
showframe
    lda #3
    cmp:rne VCOUNT
    sta WSYNC
    mva pmbank PORTB
    mva <dlist DLISTL
    mva >dlist DLISTH
    ldx #0
image
    ldx #$72
    ldy #$d2
    lda #$32
    :3 nop
    sta COLPF0
    stx COLPF1
    sta WSYNC
    sty COLPF2
    sta WSYNC
    mva #$6 COLPF0
    mva #$8 COLPF1
    mva #$c COLPF2
    lda VCOUNT
    cmp #124
    bne image
    ldx #0
blank
    mva #$82 PORTB
    inc:lda framecount
    and #$1f
    bne nosfx
    lda framecount
    and #$3f
    seq:ldy #$b
    sne:ldy #$c
    lda #$23
    ldx #1
    ;jsr player+$300 ; play sfx
nosfx
    and #$C
    ora >chset
    sta CHBASE
    lda framecount
    and #$3C
    :1 asl @
    ora #$40
    sta PMBASE
    jsr player+$303 ; play music
    lda PORTA
    and #$c
    ora fine
    tax
    lda joydirtable,x
    sta pmbank
    lda joyedgetable,x
    sta edgeoff
    lda joyfinetable,x
    sta HSCROL
    sta fine
    lda joycoarsetable,x
    beq updlist
    bpl coarseup
coarsedown
    lda coarse
    sne:dec coarse+1
    dec coarse
    jmp updlist
coarseup
    inc coarse
    sne:inc coarse+1

updlist
    ldx #0
    lda coarse
    :8 sta dlist+1+12*#
    add #linewidth
    scc:ldx #3
    :8 sta dlist+4+12*#
    add #linewidth
    scc:ldx #2
    :8 sta dlist+7+12*#
    add #linewidth
    scc:ldx #1
    :7 sta dlist+10+12*#

    lda coarse+1
    and #$f
    :2 asl @
    sta tmp
    txa
    ora tmp
    tax
    :31 dta {lda a:,x},a(coarsehitable),{sta a:},a(dlist+2+3*#),{inx}

    jsr drawedgetiles
    jmp showframe

drawedgetiles
    lda coarse
    add edgeoff
    sta drawpos+1
    lda coarse+1
    adc #0
    sta drawpos+2

    lda drawpos+1
    sta mappos
    and #3
    sta mapfrac
    lda drawpos+2
    and #$f
    lsr @
    sta mappos+1
    ror mappos
    lsr mappos+1
    ror mappos
    lsr @
    add >[map+8*linewidth]
    sta mappos+1

    mva #10 mapy
edge
    ldy #0
    lda (mappos),y
    tax
    lda tilex16,x
    ldx mapfrac
    add tilefrac,x
    tax
drawpos
    stx:inx scr
    lda drawpos+1
    add #linewidth
    sta drawpos+1
    bcc skiphi
    lda drawpos+2
    adc #0
    cmp >[scr+4096]
    bne donehi
    lda >scr
donehi
    sta drawpos+2
skiphi
    iny
    cpy #4
    bne drawpos
    inc mappos+1
    dec mapy
    bne edge
    rts

    ; RIGHT,LEFT,FINE -> DCOARSE,FINE
    ; 0,0,X -> 0,X
    ; 0,1,X -> (X==0),(X-1)%4
    ; 1,0,X -> -(X==3),(X+1)%4
    ; 1,1,X -> 0,X
joycoarsetable
    :4 dta 0
    dta 1,0,0,0
    dta 0,0,0,$ff
    :4 dta 0
joyfinetable
    :4 dta #
    :4 dta [#+3]%4
    :4 dta [#+1]%4
    :4 dta #
joyedgetable
    :8 dta 48
    :8 dta 0
joydirtable
    dta $86,$86,$86,$86
    dta $86,$86,$86,$86
    dta $8A,$8A,$8A,$8A
    dta $8E,$8E,$8E,$8E
tilex16
    :8 dta #*16
tilefrac
    :4 dta #*4
coarsehitable
    :128 dta >[scr+[[#*linewidth]&$fff]]
    run main
