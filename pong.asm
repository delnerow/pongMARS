.data
		ColorTable:
			.word 0x000000
			.word 0x0000FF
			.word 0x00FF00
			.word 0xFF0000
			.word 0xFFFFFF
		Raquete:
			.word 0x000008 #tamanho da raquete
			
.text   
.globl main

main:
    li $a0, 4
    li $a1, 10
    li $a2, 3
    jal DrawLeftRaquete
    
    li $v0, 10
    syscall

# Converte coordeanda (x,y) para endereço de memoria
# a0 é coordenada x (0-31)
# a1 é coordenada y (0-31)
# v0 é o endereço de memoria retornado
CalculateAddress:

	# endereço da memoria = 0x10040000 +4x +4y + 32, o y eh pra proxima linha
	li $v0, 0x10040000   #display
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


# desenhar raquete esquerda
# a1 posicao mais do topo da raquete (y)
DrawLeftRaquete:
	addi $sp, $sp, -4
	sw $ra, 0($sp)

	lw $s7, Raquete
	la $s7, 0($s7) #pega tamaho em y
	la $s1, ($a1) #y original
	
	
	li $s0, 0  # dy
	#desenha y's a partir do ponto de inicio
	loop:
		beq $s0,$s7, doneRaquete
		li $a0, 0  #raquete fica colada na parede
		add $a1, $s1, $s0
		li $a2, 3
		jal DrawDot 
		addi $s0,$s0, 1
		j loop
	
	doneRaquete:
		lw $ra, 0($sp)
		addi $sp, $sp, 4
		jr $ra