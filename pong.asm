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
			
		Raquete:	.word 0x000004 # tamanho da raquete
		Dimensao: 	.word 32 # dimensões x e y do jogo
#===================================================================#
		p1Raquete: 	
				.word 4  # posicao y do topo
				.word 1 # posicao x
		p1_up: 		.word 0
		p1_down: 	.word 0
#===================================================================#
		p2Raquete:
				.word 4  # posicao y do topo
				.word 30 # posicao x
		p2_up:  	.word 0
		p2_down: 	.word 0
#===================================================================#			
		


						
.text   
.globl main	



# loop incial, por enquanto
main:
	jal DrawRaquetes # desenha as raquetes no display
	## frames
	addi $v0, $zero, 32
	addi $a0, $zero, 60 # ms entre frames
	syscall
    	j handleInput
    		 	
quit:
    li $v0, 10
    syscall

handleInput:
	lw $t3, KEY_DATA      # armazena teclas escritas
	li $t0, 1
	beq $t3, 119, p1_is_up    # se for 'w'
	beq $t3, 115, p1_is_down # se for 's'
	beq $t3, 56, p2_is_up    # se for '↑'
	beq $t3, 50, p2_is_down # se for '↓'
	beq $t3, 100, quit     # se for 'd'
	j handleRaquetes

p1_is_up:
	sw $t0, p1_up
	sw $zero, p1_down
	j handleRaquetes
p1_is_down:
	sw $t0, p1_down
	sw $zero, p1_up
	j handleRaquetes
	
p2_is_up:
	sw $t0, p2_up
	sw $zero, p2_down
	j handleRaquetes
p2_is_down:
	sw $t0, p2_down
	sw $zero, p2_up
	j handleRaquetes

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
	lw $t2, Raquete
	add $t1, $t0, $t2  # ponto mais final y
	subi $t1, $t1, 1
	beqz $t0, p2Status 
	subi $t0, $t0, 1
	sw $t0, p1Raquete
	
	li $a0, 0
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
	
	li $a0, 0
	la $a1, ($t1)
	li $a2, 0
	jal DrawDot
    	j p2Status
p2MoveUp:
	lw $t0, p2Raquete
	lw $t2, Raquete
	add $t1, $t0, $t2  # ponto mais final y
	subi $t1, $t1, 1
	beqz $t0, main 
	subi $t0, $t0, 1
	sw $t0, p2Raquete
	lw $s6, Dimensao  # onde colocar o x
	subi $s6, $s6, 1
	la $a0, ($s6)
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
	
	lw $s6, Dimensao  # onde colocar o x
	subi $s6, $s6, 1
	la $a0, ($s6)
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
	sll $a2, $a2, 2
	add $a2, $a2, $t0
	lw $v1, 0($a2)
	
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
		li $a2, 3
		jal DrawDot 
		
		#raquete direita
		la $a0, ($s4)
		add $a1, $s3, $s0
		li $a2, 3
		jal DrawDot 
		
		addi $s0,$s0, 1	
		
		j loop

	doneRaquete:
		lw $ra, 0($sp)
		addi $sp, $sp, 4
		jr $ra
