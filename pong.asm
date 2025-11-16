.eqv KEY_CRTL 0xffff0000   	# o endereço do MMIO simulator que detecta tecla pressionada
.eqv KEY_DATA 0xffff0004   	# o endereço do MMIO simultaor que armazena a ultima tecla pressionada
.eqv KEY_DISPLAY 0x10040000 	# o endereço do Bitmap Display

.data
		ColorTable:
				.word 0x000000  # preto
				.word 0x0000FF  # azul
				.word 0x00FF00  # verde
				.word 0xFF0000  # vermelho
				.word 0xFFFFFF  # branco
			
		Raquete:	.word 0x000007 # tamanho da raquete, atualmente funciona apenas para 7...
		angulos:
					.word -2
					.word -1
					.word -1
					.word 0
					.word 1
					.word 1
					.word 2


		Dimensao: 	.word 32 # dimensões x e y do jogo
#===================================================================#
		p1Raquete: 	
				.word 1  # posicao y do topo
				.word 1 # posicao x
		p1_up: 		.word 0
		p1_down: 	.word 0
		p1_score:  	.word 0
#===================================================================#
		p2Raquete:
				.word 1  # posicao y do topo
				.word 30 # posicao x
		p2_up:  	.word 0
		p2_down: 	.word 0
		p2_score:  	.word 0
#===================================================================#			
		Bola:
			.word 16  #v y da bola
			.word 16 # x da bola
		direcao:
			.word 0 # componente y
			.word -1 # component x
		velocidadeMax: .word 3 
#===================================================================#	
		beep: .byte 72
		duration: .byte 100
		volume: .byte 127
#===================================================================#	
        gameMode:
            .word 1  # ia falsa/verdadeira
						
.text   
.globl main	

config:
jal playBeep
 #jal clearScreen
 jal showScore
 jal DrawRaquetes # desenha as raquetes no display
 
# loop incial, por enquanto
main:
	lw $a0, p1_score
	lw $a1, p2_score
	beq $a0, 10, gameWin1
	beq $a1, 10, gameWin2
	jal encostaCanto
	
	
	## frames
	addi $v0, $zero, 32
	addi $a0, $zero, 144 # ms entre frames
	syscall
	#jal dotLine
	
    	j handleInput
    		 	
quit:
    li $v0, 10
    syscall


playBeep:

	subi $sp, $sp, 12
	sw $a0, 0($sp)
	sw $a2, 4($sp)
	sw $a3, 8($sp)
	
	li $v0,31
	la $a0, beep
	#lw $a0 0($a0)
	la $a1, duration
	li $a2, 120
	la $a3, volume
	# lw $a1, 0($a1)
	syscall
	
	lw $a0, 0($sp)
	lw $a2, 4($sp) 
	lw $a3, 8($sp) 
	addi $sp, $sp, 12
	jr $ra

# ===================  Dinamica da Bola  ==================== #
# a3 - y da raquete 
# a2 - qual raquete (1 ou 2)
# a1 - y da bola
# Ver se o y da bola encosta em algum y da raquete
encostaBola:
	lw $s3, Raquete  # tamanho da raquete
	li $t0,0
	
	loopEncosta:
		beq $t0, $s3, resetBola  # nao encostou, mas esta no canto, ent volta pro meio
		beq $a3, $a1, rebateBola
		addi $a3, $a3, 1
		addi $t0, $t0, 1
		j loopEncosta

	
rebateBola:
	addi $sp, $sp, -4
	sw $ra, 0($sp)
	jal playBeep
	lw $ra , 0($sp)
	addi $sp, $sp, 4
	lw $t1, direcao # componente y
	lw $t2, direcao + 4 # component x
	la $t3, angulos  # lookup table das reflexoes
	sll $t0, $t0, 2
	add $t0, $t3, $t0
	lw $t0, 0($t0)
	sw $t0, direcao
	
	
	lw $t4, velocidadeMax
	bgtz $t2, aceleraBola
	subi $t2, $t2, 1 # bola fica mais rapida (quando eh negativa a direcao)
	add $t3, $t2, $t4
	li $v0, -1
	beqz $t3, resetVelocidade
	sub $t2, $zero, $t2
	sw $t2, direcao + 4 
	j moveBola
	
	aceleraBola:
		addi $t2, $t2, 1 # bola fica mais rapida (quando eh negativa a direcao)
		sub $t3, $t2, $t4
		li $v0, 1
		beqz $t3, resetVelocidade
		sub $t2, $zero, $t2
		sw $t2, direcao + 4 
		j moveBola
	resetVelocidade:
		la $t2, ($v0)
		sub $t2, $zero, $t2
		sw $t2, direcao + 4 
		j moveBola	

inverteY:
	lw $t1, direcao # componente y
	sub $t1, $zero, $t1
	sw $t1, direcao
	addi $sp, $sp, -4
	sw $ra, 0($sp)
	jal playBeep
	lw $ra , 0($sp)
	j moveBola

encostaCanto:
	lw $a0, Bola+4  # x da bola
	lw $a1, Bola # y da bola
	
	lw $t2, p1Raquete + 4 # x da raquete 1
	addi $t2, $t2, 1 # borda da raquete 1
	lw $a3, p1Raquete  # y da raquete 1
	
	sub $t2, $a0, $t2
	li $a2, 0
	blez $t2, encostaBola
	
	lw $t2, p2Raquete + 4 # x da raquete 2
	subi $t2, $t2, 1 # borda da raquete 2
	lw $a3, p2Raquete  # y da raquete 2
	
	sub $t2, $a0, $t2
	li $a2, 1
	bgez $t2, encostaBola
	# nn encosta no canto, mas pode encostar no teto/chao

encostaVertical:
	lw $a1, Bola # y da bola
	lw $t2, Dimensao
	beq $a1, $zero, inverteY
	beq $a1, $t2, inverteY
	# nao encosta em nada		
	
# a0 - x da bola
# a1 - y da bola
moveBola:
	addi $sp, $sp, -4
	sw $ra, 0($sp)
	lw $a0, Bola+4  # x da bola
	lw $a1, Bola # y da bola
	li $a2, 0
	jal DrawDot
moveImmediateBola:
	lw $a0, Bola+4  # x da bola
	lw $a1, Bola # y da bola
	lw $t2, direcao # direcao y
	add $a1, $a1, $t2
	sw $a1, Bola
	lw $t1, direcao + 4 # direcao x
	add $a0, $a0, $t1
	lw $t2, p1Raquete + 4 # x da raquete 1
	sub $t2, $a0, $t2
	li $v0, 1
	blez $t2, corrigeUltrapasso
	lw $t2, p2Raquete + 4 # x da raquete 2
	sub $t2, $a0, $t2
	li $v0, -1
	bgez $t2, corrigeUltrapasso

	desenha:
	sw $a0, Bola + 4		
	li $a2, 1
	jal DrawDot
	
	lw $ra, 0($sp)
	addi $sp, $sp, 4
	
	jr $ra
corrigeUltrapasso:
	add $a0, $a0, $v0
	j desenha
	
	
resetBola:
	addi $sp, $sp, -4
	sw $ra, 0($sp)
	
	move $s7, $a2
	li $a2, 0
	jal DrawDot
	jal playBeep
	
	li $t0, 16
	sw $t0, Bola
	sw $t0, Bola +4
	lw $t1, direcao # componente y
	li $t1, 0
	sw $t1, direcao
	
	move $a0, $t0 # x da bola
	move $a1, $t0  # y da bola
	
	lw $ra, 0($sp)
	addi $sp, $sp, 4
	beqz $s7, ponto2
	j ponto1
	
ponto2:
	lw $t0, p2_score
	addi $t0, $t0,1
	sw $t0, p2_score
	lw $t1, direcao + 4 # componente x
	li $t1, 1
	sw $t1, direcao + 4
	j donePonto

ponto1:
	lw $t0, p1_score
	addi $t0, $t0,1
	sw $t0, p1_score
	lw $t1, direcao + 4 # componente x
	li $t1, -1
	sw $t1, direcao + 4
	j donePonto
	
donePonto:
	addi $sp, $sp, -4
	sw $ra, 0($sp)
	jal showScore
	lw $ra, 0($sp)
	addi $sp, $sp, 4
	addi $sp, $sp, -4
	sw $ra, 0($sp)
	j moveImmediateBola
	
# ===================  Dinamica dos inputs ==================== #	
	
# Lida com as teclas pressionadas
handleInput:
	lw $t3, KEY_DATA      # armazena teclas escritas
	li $t0, 1
	beq $t3, 119, p1_is_up    # se for 'w'
	beq $t3, 115, p1_is_down # se for 's'
    beq $t3, 100, quit     # se for 'd'
    lw $t2, gameMode
    bnez $t2, handleIA
    handleInput2P:
	beq $t3, 56, p2_is_up    # se for '↑'
	beq $t3, 50, p2_is_down # se for '↓'	
	j handleRaquetes
handleIA:
    lw $t0, Bola #y
    lw $t1, p2Raquete # Y do topo

    # achando o ponto medio da raquete
    lw $t3, Raquete
    srl $t3, $t3, 1
    add $t1, $t1, $t3

    sub $t3, $t0, $t1  # eixo y eh invertido
    bgtz $t3, p2_is_down   #raquete ta em cima da bola
    j p2_is_up  # default seria a raquete estar em baixo da bola

p1_is_up:
	sw $t0, p1_up
	sw $zero, p1_down
	lw $t2, gameMode
	bnez $t2, handleIA
	j handleRaquetes
p1_is_down:
	sw $t0, p1_down
	sw $zero, p1_up
	lw $t2, gameMode
	bnez $t2, handleIA
	j handleRaquetes
	
p2_is_up:
	sw $t0, p2_up
	sw $zero, p2_down
	j handleRaquetes
p2_is_down:
	sw $t0, p2_down
	sw $zero, p2_up
	j handleRaquetes


# Transforma os estados das raquetes em movimento, na tela e na variavel de posicao
handleRaquetes:
	p1Status:
	lw $t0, p1_up
	beq $t0, $zero, p1MoveDown	
	j p1MoveUp
	p2Status:
	lw $t0, p2_up
	beq $t0, $zero, p2MoveDown
	j p2MoveUp

p1MoveUp:
	lw $t0, p1Raquete
	beqz $t0, p2Status 
	lw $t2, Raquete
	add $t1, $t0, $t2  # ponto mais final y
	subi $t1, $t1, 1
	subi $t0, $t0, 1
	sw $t0, p1Raquete
	lw $a0, p1Raquete + 4
	
	la $a1, ($t0)
	li $a2, 3
	jal DrawDot
	la $a1, ($t1)
	li $a2, 0
	jal DrawDot
    	j p2Status
p1MoveDown:
	lw $t0, p1Raquete
	add $t1, $zero, $t0
	lw $t2, Raquete
	lw $t3, Dimensao
	add $t4, $t0, $t2
	beq $t4, $t3, p2Status 
	addi $t0, $t0, 1
	sw $t0, p1Raquete
	lw $a0, p1Raquete + 4
	
    	add $t0, $t0, $t2
	subi $t0, $t0, 1
	la $a1, ($t0)
	li $a2, 3
	jal DrawDot
	la $a1, ($t1)
	li $a2, 0
	jal DrawDot
    	j p2Status
p2MoveUp:
	lw $t0, p2Raquete
	beqz $t0, main 
	lw $t2, Raquete
	add $t1, $t0, $t2  # ponto mais final y
	subi $t1, $t1, 1
	subi $t0, $t0, 1
	sw $t0, p2Raquete
	lw $a0, p2Raquete + 4
	
	la $a1, ($t0)
	li $a2, 3
	jal DrawDot
	la $a1, ($t1)
	li $a2, 0
	jal DrawDot
    	j main
p2MoveDown:
	lw $t0, p2Raquete
	add $t1, $zero, $t0
	
	
	lw $t2, Raquete
	lw $t3, Dimensao
	add $t4, $t0, $t2
	beq $t4, $t3,main 
	addi $t0, $t0, 1
	sw $t0, p2Raquete
	lw $a0, p2Raquete + 4
	
	add $t0, $t0, $t2
	subi $t0, $t0, 1
	la $a1, ($t0)
	li $a2, 3
	jal DrawDot
	la $a1, ($t1)
	li $a2, 0
	jal DrawDot
    	j main

# Converte coordeanda (x,y) para endereço de memoria
# a0 é coordenada x (0-31)
# a1 é coordenada y (0-31)
# v0 é o endereço de memoria retornado
CalculateAddress:

	# endereço da memoria = 0x10040000 +4x +4y + 32, o y eh pra proxima linha
	li $v0, KEY_DISPLAY  #display
	sll $t2, $a0, 2    # t2= x*4
	sll $t3, $a1, 7   # t2= y*32
	add $v0, $v0, $t2
	add $v0, $v0, $t3
	jr $ra
	
# usa lookup table das cores
# a2 eh numero da cor (0-4)
# v1 eh valor mapeado real da cor	
GetColor:
	la $t0, ColorTable
	sll $a3, $a2, 2
	add $a3, $a3, $t0
	lw $v1, 0($a3)
	
	jr $ra
# desenha ponto nas coordenadas (x,y) com cor especifica
# a0 x
# a1 y
# a2 cor
DrawDot:

	# checar coordenadas invalidas
	bltz $a0, doneDrawingDot # x<0
	bltz $a1, doneDrawingDot
	bgt $a0, 31, doneDrawingDot
	bgt $a1, 31, doneDrawingDot
	
	
	addi $sp, $sp, -4
	sw $ra, 0($sp)
	
	jal CalculateAddress
	jal GetColor
	
	sw $v1, 0($v0)
	
	lw $ra, 0($sp)
	addi $sp, $sp, 4
	
	doneDrawingDot:
		jr $ra


# Desenha no Display as raquetes no frame atual
DrawRaquetes:
	addi $sp, $sp, -4
	sw $ra, 0($sp)
	lw $s1, p1Raquete # p1 y
	lw $s2, p1Raquete + 4 # p1 x
	li $a2, 3
	lw $s3, p2Raquete	# p2 y
	lw $s4, p2Raquete + 4  	# p2 x
	
	lw $s7, Raquete  # tamanho da raquete
	li $s0, 0  # contador
	#desenha y's a partir do ponto de inicio
	loop:
		beq $s0,$s7, doneRaquete
		
		#raquete esquerda
		la $a0, ($s2)
		add $a1, $s1, $s0
		jal DrawDot 
		
		#raquete direita
		la $a0, ($s4)
		add $a1, $s3, $s0
		jal DrawDot 
		
		addi $s0,$s0, 1	
		
		j loop

	doneRaquete:
		lw $ra, 0($sp)
		addi $sp, $sp, 4
		jr $ra
clearScreen:
	addi $sp, $sp, -4
	sw $ra, 0($sp)
	lw $s7, Dimensao
	li $s0, 0
	li $s1, 0
	loopx:
		beq $s0, $s7, somaY
		move $a0, $s0
		move $a1, $s1
		li $a2, 0
		jal DrawDot
		addi $s0,$s0, 1
		j loopx
	somaY:
		addi $s1,$s1, 1
		beq $s1, $s7, doneClear
		li $s0, 0
		j loopx
	doneClear:
		lw $ra, 0($sp)
		addi $sp, $sp, 4
		jr $ra
dotLine:
	addi $sp, $sp, -4
	sw $ra, 0($sp)
	lw $s7, Dimensao
	srl $s0, $s7, 1
	li $s1, 0
	loopDot:
		bge $s1, $s7, doneLine
		la $a0, ($s0)
		la $a1, ($s1)
		li $a2, 4
		jal DrawDot
		addi $s1,$s1, 1
		la $a1, ($s1)
		li $a2, 4
		jal DrawDot
		addi $s1,$s1, 2
		j loopDot
	doneLine:
	lw $ra, 0($sp)
	addi $sp, $sp, 4
	jr $ra
# --------------------------------------------------------
# showScore - desenha os placares dos jogadores
# --------------------------------------------------------
showScore:
    addi $sp, $sp, -8
    sw $ra, 4($sp)
    sw $s0, 0($sp)

    # ----- desenhar P1 -----
    lw $s0, p1_score      # s0 = p1_score
    li $a0, 4             # x
    li $a1, 2             # y
    move $a3, $s0         # dígito
    jal drawDigit

    # ----- desenhar P2 -----
    lw $s0, p2_score
    li $a0, 24            # x (lado direito)
    li $a1, 2             # y
    move $a3, $s0
    jal drawDigit

    lw $s0, 0($sp)
    lw $ra, 4($sp)
    addi $sp, $sp, 8
    jr $ra
	
# --------------------------------------------------------
# drawDigit(a0=a_x, a1=a_y, a3=dígito de 0 a 9)
# --------------------------------------------------------
drawDigit:
    addi $sp, $sp, -4
    sw $ra, 0($sp)

    li $t0, 0
	li $a2, 4
    beq $a3, $t0, call0
    li $t0, 1
    beq $a3, $t0, call1
    li $t0, 2
    beq $a3, $t0, call2
    li $t0, 3
    beq $a3, $t0, call3
    li $t0, 4
    beq $a3, $t0, call4
    li $t0, 5
    beq $a3, $t0, call5
    li $t0, 6
    beq $a3, $t0, call6
    li $t0, 7
    beq $a3, $t0, call7
    li $t0, 8
    beq $a3, $t0, call8
    li $t0, 9
    beq $a3, $t0, call9

    j digit_end

call0: 
jal drawNull
jal draw0
 j digit_end
call1: 
jal drawNull
jal draw1
 j digit_end
call2:
jal drawNull
 jal draw2 
j digit_end
call3:
jal drawNull
 jal draw3
 j digit_end
call4:
jal drawNull
 jal draw4 
j digit_end
call5: 
jal drawNull
jal draw5 
j digit_end
call6:
jal drawNull
 jal draw6 
j digit_end
call7:
jal drawNull
 jal draw7 
j digit_end
call8: 
jal drawNull
jal draw8 
j digit_end
call9: 
jal drawNull
jal draw9 
j digit_end

digit_end:
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    jr $ra
	

#############################################################
#   FUNÇÕES DE DESENHO DOS NÚMEROS 0–9 (6x3 pixels)
#   pivot = (a0,a1) = canto superior esquerdo
#   a2 = cor
#############################################################
# ========== DIGITO BRANCO==========
drawNull:
	li $a2, 0
	addi $sp, $sp, -4
    	sw $ra, 0($sp)
	add $s0,$a0,$zero
    	add $s1,$a1,$zero
    	li $s5,0
	drawNulloop:
	add  $a1,$s1,$s5
	jal DrawDot
    	addi $a0,$s0,1
    	jal DrawDot
    	addi $a0,$s0,2
    	jal DrawDot
   	addi $s5,$s5,1
   	move $a0, $s0
  	 blt $s5,6,drawNulloop
  	 li $a2, 4
  	 lw $ra, 0($sp)
    addi $sp, $sp, 4
    move $a1, $s1
   	 jr $ra
# ========== DIGITO 0 ==========
draw0:
    #  ###
    #  # #
    #  # #
    #  # #
    #  # #
    #  ###
    addi $sp, $sp, -4
    sw $ra, 0($sp)
    
    addi $s0,$a0,0     # coluna 0-2
    addi $s1,$a1,0     # linha 0-5
	
    # linha 0
    jal DrawDot
    addi $a0,$s0,1
    move $a1, $s1
     jal DrawDot
    addi $a0,$s0,2
    move $a1, $s1
    jal DrawDot
    # linhas 1–4
    addi $a1,$s1,1
    li $s5, 0
    draw0_loop1:
        # coluna 0
        addi $a0,$s0,0
         jal DrawDot
        # coluna 2
        addi $a0,$s0,2
        jal DrawDot
        addi $a1,$a1,1
        addi $s5, $s5, 1
        bne $s5,5 draw0_loop1

    # linha 5
    addi $a0,$s0,0
    addi $a1,$s1,5
    jal DrawDot
    addi $a0,$s0,1 
     jal DrawDot
    addi $a0,$s0,2
    jal DrawDot
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    jr $ra



# ========== DIGITO 1 ==========
draw1:
    #   #
    #   #
    #   #
    #   #
    #   #
    #   #
    addi $sp, $sp, -4
    sw $ra, 0($sp)
    add $s0,$a0,$zero
    add $s1,$a1,$zero
    li $s5,0
draw1_loop:
    addi $a0,$s0,1
    add  $a1,$s1,$s5
    jal DrawDot
    addi $s5,$s5,1
    blt $s5,6,draw1_loop
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    jr $ra

# ========== DIGITO 2 ==========
draw2:
    #  ###
    #    #
    #    #
    #  ###
    #  #
    #  ###
    addi $sp, $sp, -4
    sw $ra, 0($sp)
    add $s0,$a0,$zero
    add $s1,$a1,$zero

    # linha 0
    addi $a1,$s1,0
    addi $a0,$s0,0 
     jal DrawDot
    addi $a0,$s0,1 
     jal DrawDot
    addi $a0,$s0,2 
     jal DrawDot

    # linha 1
    addi $a1,$s1,1
    addi $a0,$s0,2  
    jal DrawDot

    # linha 2
    addi $a1,$s1,2
    addi $a0,$s0,2  
    jal DrawDot

    # linha 3
    addi $a1,$s1,3
    addi $a0,$s0,0 
     jal DrawDot
    addi $a0,$s0,1 
     jal DrawDot
    addi $a0,$s0,2 
     jal DrawDot

    # linha 4
    addi $a1,$s1,4
    addi $a0,$s0,0 
     jal DrawDot

    # linha 5
    addi $a1,$s1,5
    addi $a0,$s0,0  
    jal DrawDot
    addi $a0,$s0,1 
     jal DrawDot
    addi $a0,$s0,2 
     jal DrawDot
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    jr $ra

# ========== DIGITO 3 ==========
draw3:
    #  ###
    #    #
    #    #
    #  ###
    #    #
    #  ###
    addi $sp, $sp, -4
    sw $ra, 0($sp)
    add $s0,$a0,$zero
    add $s1,$a1,$zero

    # linha 0
    addi $a1,$s1,0
    addi $a0,$s0,0  
    jal DrawDot
    addi $a0,$s0,1  
    jal DrawDot
    addi $a0,$s0,2 
     jal DrawDot

    # linha 1
    addi $a1,$s1,1
    addi $a0,$s0,2 
     jal DrawDot

    # linha 2
    addi $a1,$s1,2
    addi $a0,$s0,2  
    jal DrawDot

    # linha 3 (meio)
    addi $a1,$s1,3
    addi $a0,$s0,0  
    jal DrawDot
    addi $a0,$s0,1  
    jal DrawDot
    addi $a0,$s0,2 
     jal DrawDot

    # linha 4
    addi $a1,$s1,4
    addi $a0,$s0,2 
     jal DrawDot

    # linha 5
    addi $a1,$s1,5
    addi $a0,$s0,0 
     jal DrawDot
    addi $a0,$s0,1 
     jal DrawDot
    addi $a0,$s0,2  
    jal DrawDot
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    jr $ra

# ========== DIGITO 4 ==========
draw4:
    #  # #
    #  # #
    #  # #
    #  ###
    #    #
    #    #
    addi $sp, $sp, -4
    sw $ra, 0($sp)
    add $s0,$a0,$zero
    add $s1,$a1,$zero

    # linhas 0–2
    li $s5,0
draw4_loop1:
    add $a1,$s1,$s5 
    jal DrawDot
    addi $a0,$s0,2  
    jal DrawDot
    addi $s5,$s5,1
    move $a0, $s0
    blt $s5,3,draw4_loop1

    # linha 3 (meio)
    addi $a1,$s1,3 
    jal DrawDot
    addi $a0,$s0,1  
    jal DrawDot
    addi $a0,$s0,2  
    jal DrawDot

    # linhas 4–5
    addi $a1,$s1,4
    addi $a0,$s0,2  
    jal DrawDot
    addi $a1,$s1,5
    addi $a0,$s0,2  
    jal DrawDot
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    jr $ra

# ========== DIGITO 5 ==========
draw5:
    #  ###
    #  #
    #  #
    #  ###
    #    #
    #  ###
    addi $sp, $sp, -4
    sw $ra, 0($sp)
    add $s0,$a0,$zero
    add $s1,$a1,$zero

    # linha0
    addi $a1,$s1,0
    addi $a0,$s0,0  
    jal DrawDot
    addi $a0,$s0,1  
    jal DrawDot
    addi $a0,$s0,2  
    jal DrawDot

    # linha1
    addi $a1,$s1,1
    addi $a0,$s0,0  
    jal DrawDot

    # linha2
    addi $a1,$s1,2
    addi $a0,$s0,0  
    jal DrawDot

    # linha3
    addi $a1,$s1,3
    addi $a0,$s0,0  
    jal DrawDot
    addi $a0,$s0,1  
    jal DrawDot
    addi $a0,$s0,2  
    jal DrawDot

    # linha4
    addi $a1,$s1,4
    addi $a0,$s0,2  
    jal DrawDot

    # linha5
    addi $a1,$s1,5
    addi $a0,$s0,0  
    jal DrawDot
    addi $a0,$s0,1  
    jal DrawDot
    addi $a0,$s0,2  
    jal DrawDot
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    jr $ra

# ========== DIGITO 6 ==========
draw6:
    #  ###
    #  #
    #  #
    #  ###
    #  # #
    #  ###
    addi $sp, $sp, -4
    sw $ra, 0($sp)
    add $s0,$a0,$zero
    add $s1,$a1,$zero

    # linha0
    addi $a1,$s1,0
    addi $a0,$s0,0 
     jal DrawDot
    addi $a0,$s0,1  
    jal DrawDot
    addi $a0,$s0,2  
    jal DrawDot

    # linha1
    addi $a1,$s1,1
    addi $a0,$s0,0 
     jal DrawDot


    # linha2
    addi $a1,$s1,2
    addi $a0,$s0,0  
    jal DrawDot


    # linha3 (meio)
    addi $a1,$s1,3
    addi $a0,$s0,0  
    jal DrawDot
    addi $a0,$s0,1  
    jal DrawDot
    addi $a0,$s0,2 
    jal DrawDot

    # linha4
    addi $a1,$s1,4
    addi $a0,$s0,0  
    jal DrawDot
    addi $a0,$s0,2  
    jal DrawDot

    # linha5
    addi $a1,$s1,5
    addi $a0,$s0,0  
    jal DrawDot
    addi $a0,$s0,1 
     jal DrawDot
    addi $a0,$s0,2 
     jal DrawDot
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    jr $ra

# ========== DIGITO 7 ==========
draw7:
    #  ###
    #    #
    #    #
    #   #
    #  #
    #  #
    addi $sp, $sp, -4
    sw $ra, 0($sp)
    add $s0,$a0,$zero
    add $s1,$a1,$zero

    # linha0
    addi $a1,$s1,0
    addi $a0,$s0,0 
     jal DrawDot
    addi $a0,$s0,1 
     jal DrawDot
    addi $a0,$s0,2 
     jal DrawDot

    # linha1
    addi $a1,$s1,1
    addi $a0,$s0,2  
    jal DrawDot

    # linha2
    addi $a1,$s1,2
    addi $a0,$s0,2  
    jal DrawDot

    # linha3
    addi $a1,$s1,3
    addi $a0,$s0,1  
    jal DrawDot

    # linha4
    addi $a1,$s1,4
    addi $a0,$s0,0 
     jal DrawDot

    # linha5
    addi $a1,$s1,5
    addi $a0,$s0,0  
    jal DrawDot
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    jr $ra

# ========== DIGITO 8 ==========
draw8:
    #  ###
    #  # #
    #  # #
    #  ###
    #  # #
    #  ###
    addi $sp, $sp, -4
    sw $ra, 0($sp)
    add $s0,$a0,$zero
    add $s1,$a1,$zero

    # linha0
    jal DrawDot
    addi $a0,$s0,1 
     jal DrawDot
    addi $a0,$s0,2  
    jal DrawDot

    # linhas1–2
    li $s5,1
draw8_loop1:
    add $a1,$s1,$s5
    addi $a0,$s0,0  
    jal DrawDot
    addi $a0,$s0,2 
     jal DrawDot
    addi $s5,$s5,1
    blt $s5,3,draw8_loop1

    # linha3 (meio)
    addi $a1,$s1,3
    addi $a0,$s0,0 
     jal DrawDot
    addi $a0,$s0,1 
     jal DrawDot
    addi $a0,$s0,2 
     jal DrawDot

    # linhas 4–5
    li $s5,4
draw8_loop2:
    add $a1,$s1,$s5
    addi $a0,$s0,0  
    jal DrawDot
    addi $a0,$s0,2  
    jal DrawDot
    addi $s5,$s5,1
    blt $s5,6,draw8_loop2
    # linha 6
    addi $a1,$s1,5
    addi $a0,$s0,0  
    jal DrawDot
    addi $a0,$s0,1 
     jal DrawDot
    addi $a0,$s0,2 
     jal DrawDot
    
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    jr $ra

# ========== DIGITO 9 ==========
draw9:
    #  ###
    #  # #
    #  # #
    #  ###
    #    #
    #    #
    addi $sp, $sp, -4
    sw $ra, 0($sp)
    add $s0,$a0,$zero
    add $s1,$a1,$zero

    # linha0
    addi $a1,$s1,0
    addi $a0,$s0,0 
     jal DrawDot
    addi $a0,$s0,1 
     jal DrawDot
    addi $a0,$s0,2  
    jal DrawDot

    # linha1–2
    li $s5,1
draw9_toploop:
    add $a1,$s1,$s5
    addi $a0,$s0,0 
     jal DrawDot
    addi $a0,$s0,2  
    jal DrawDot
    addi $s5,$s5,1
    blt $s5,3,draw9_toploop

    # linha3 (meio)
    addi $a1,$s1,3
    addi $a0,$s0,0  
    jal DrawDot
    addi $a0,$s0,1  
    jal DrawDot
    addi $a0,$s0,2  
    jal DrawDot

    # linha4
    addi $a1,$s1,4
    addi $a0,$s0,2  
    jal DrawDot

    # linha5
    addi $a1,$s1,5
    addi $a0,$s0,2  
    jal DrawDot
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    jr $ra
# ========== P ==========
drawP:
    #  ###
    #  #  #
    #  #  #
    #  ###
    #  #  
    #  #  
    addi $sp, $sp, -4
    sw $ra, 0($sp)
    add $s0,$a0,$zero
    add $s1,$a1,$zero

    # linha0
    addi $a1,$s1,0
    addi $a0,$s0,0 
     jal DrawDot
    addi $a0,$s0,1 
     jal DrawDot
    addi $a0,$s0,2  
    jal DrawDot

    # linha1–2
    li $s5,1
drawP_toploop:
    add $a1,$s1,$s5
    addi $a0,$s0,0 
     jal DrawDot
    addi $a0,$s0,3  
    jal DrawDot
    addi $s5,$s5,1
    blt $s5,3,drawP_toploop

    # linha3 (meio)
    addi $a1,$s1,3
    addi $a0,$s0,0  
    jal DrawDot
    addi $a0,$s0,1  
    jal DrawDot
    addi $a0,$s0,2  
    jal DrawDot

    # linha4
    addi $a1,$s1,4
    addi $a0,$s0,0 
    jal DrawDot

    # linha5
    addi $a1,$s1,5
    addi $a0,$s0,0  
    jal DrawDot
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    jr $ra
    
gameWin1:
	jal clearScreen
	li $a0, 12
	li $a1, 5
	li $a2, 4
	jal drawP
	li $a0, 17
	li $a1, 5
	li $a2, 4
	jal draw1
	j quit
	
gameWin2:
	jal clearScreen
	li $a0, 12
	li $a1, 5
	li $a2, 4
	jal drawP
	li $a0, 17
	li $a1, 5
	li $a2, 4
	jal draw2
	j quit
