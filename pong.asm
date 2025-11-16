# ============================================================================
# JOGO PONG EM ASSEMBLY MIPS
# ============================================================================
# Descrição: Implementação clássica do jogo Pong para MIPS
# Autores: [Seus nomes aqui]
# Data: 2025
# ============================================================================

# ----------------------------------------------------------------------------
# DEFINIÇÕES DE ENDEREÇOS DE MEMÓRIA (MMIO)
# ----------------------------------------------------------------------------
.eqv KEY_CRTL 0xffff0000      # Endereço MMIO para detectar tecla pressionada
.eqv KEY_DATA 0xffff0004      # Endereço MMIO que armazena a última tecla pressionada
.eqv KEY_DISPLAY 0x10040000   # Endereço base do Bitmap Display (32x32 pixels)

# ----------------------------------------------------------------------------
# SEGMENTO DE DADOS
# ----------------------------------------------------------------------------
.data
    # ========================================================================
    # TABELA DE CORES (formato RGB hex)
    # ========================================================================
    ColorTable:
        .word 0x000000  # Índice 0: Preto (fundo)
        .word 0x0000FF  # Índice 1: Azul (não usado)
        .word 0x00FF00  # Índice 2: Verde (não usado)
        .word 0xFF0000  # Índice 3: Vermelho (raquetes)
        .word 0xFFFFFF  # Índice 4: Branco (bola e placar)
    
    # ========================================================================
    # CONFIGURAÇÕES DAS RAQUETES
    # ========================================================================
    Raquete: .word 0x000007     # Tamanho da raquete (7 pixels de altura)
    
    # Tabela de ângulos de reflexão da bola ao colidir com diferentes partes da raquete
    # Cada posição representa uma parte diferente da raquete (de cima para baixo)
    angulos:
        .word -2    # forte para cima
        .word -1    # médio para cima
        .word -1    # suave para cima
        .word 0     # reta
        .word 1     # suave para baixo
        .word 1     # médio para baixo
        .word 2     # forte para baixo

    # ========================================================================
    # DIMENSÕES DO CAMPO DE JOGO
    # ========================================================================
    Dimensao: .word 32          # Tamanho do campo (32x32 pixels)

    # ========================================================================
    # DADOS DO JOGADOR 1 (ESQUERDA)
    # ========================================================================
    p1Raquete: 
        .word 1     # Posição Y do topo da raquete
        .word 1     # Posição X da raquete
    p1_up:      .word 0         # Flag: 1 se está movendo para cima
    p1_down:    .word 0         # Flag: 1 se está movendo para baixo
    p1_score:   .word 0         # Pontuação do jogador 1

    # ========================================================================
    # DADOS DO JOGADOR 2 (DIREITA)
    # ========================================================================
    p2Raquete:
        .word 1     # Posição Y do topo da raquete
        .word 30    # Posição X da raquete (próximo à borda direita)
    p2_up:      .word 0         # Flag: 1 se está movendo para cima
    p2_down:    .word 0         # Flag: 1 se está movendo para baixo
    p2_score:   .word 0         # Pontuação do jogador 2

    # ========================================================================
    # DADOS DA BOLA
    # ========================================================================
    Bola:
        .word 16    # Posição Y da bola (centro da tela)
        .word 16    # Posição X da bola (centro da tela)
    
    # Direção de movimento da bola
    direcao:
        .word 0     # Componente Y da direção (-2 a +2)
        .word -1    # Componente X da direção (negativo = esquerda, positivo = direita)
    
    velocidadeMax: .word 3      # Velocidade máxima horizontal da bola

    # ========================================================================
    # CONFIGURAÇÕES DE ÁUDIO (MIDI)
    # ========================================================================
    duration:   .byte 100       # Duração do som em milissegundos
    volume:     .byte 127       # Volume do som (0-127)

    beep:       .byte 72        # Nota MIDI para som de rebatida (C5)
    boop:       .byte 12        # Instrumento alternativo

    bounce:     .byte 120       # Instrumento MIDI (120 = Reverse Cymbal)
    point:      .byte 8         # Instrumento para pontuação

    # ========================================================================
    # MODO DE JOGO
    # ========================================================================
    gameMode:   .word 1         # 1 = Jogador vs IA, 0 = Jogador vs Jogador

# ============================================================================
# SEGMENTO DE CÓDIGO
# ============================================================================
.text   
.globl main

# ----------------------------------------------------------------------------
# TELA INICIAL - SELEÇÃO DE MODO DE JOGO
# ----------------------------------------------------------------------------
mainScreen:
    jal clearScreen             # Limpa a tela
    lbu $s2, point              # Carrega instrumento de pontuação
    lbu $s0, beep               # Carrega pitch
    jal playBeep                # Toca som inicial
    
    # Desenha "1P" (modo 1 jogador)
    li $a0, 12                  # Posição X
    li $a1, 5                   # Posição Y
    li $a2, 4                   # Cor (branco)
    jal draw1                   # Desenha "1"
    li $a0, 17
    li $a1, 5
    jal drawP                   # Desenha "P"
    
    # Desenha "2P" (modo 2 jogadores)
    li $a0, 12
    li $a1, 15
    li $a2, 4
    jal draw2                   # Desenha "2"
    li $a0, 17
    li $a1, 15
    li $a2, 4
    jal drawP                   # Desenha "P"
    
    
    # Aguarda seleção do jogador
    waitForInput:
        addi $v0, $zero, 32     # Syscall 32: sleep
        addi $a0, $zero, 1000   # 1000 ms (1 segundo) entre verificações
        syscall
        
        lw $t3, KEY_DATA        # Lê tecla pressionada
        li $t0, 1
        beq $t3, 49, set1P      # Se pressionou '1' (ASCII 49)
        beq $t3, 50, set2P      # Se pressionou '2' (ASCII 50)
        j waitForInput          # Continua aguardando
    
    # Configura modo 1 jogador (vs IA)
    set1P:
        li $t1, 1
        sw $t1, gameMode        # Define modo = 1
        j config
    
    # Configura modo 2 jogadores
    set2P:
        li $t1, 0
        sw $t1, gameMode        # Define modo = 0
        j config

# ----------------------------------------------------------------------------
# CONFIGURAÇÃO INICIAL DO JOGO
# ----------------------------------------------------------------------------
config:
    jal clearScreen             # Limpa a tela
    jal showScore               # Mostra placar inicial (0 - 0)
    jal DrawRaquetes            # Desenha as raquetes nas posições iniciais

# ============================================================================
# LOOP PRINCIPAL DO JOGO
# ============================================================================
main:
    # Controle de framerate
    addi $v0, $zero, 32         # Syscall 32: sleep
    addi $a0, $zero, 74         # 74 ms entre frames (~13.5 FPS)
    syscall

    # Verifica condições de vitória
    lw $a0, p1_score            # Carrega pontuação do jogador 1
    lw $a1, p2_score            # Carrega pontuação do jogador 2
    beq $a0, 10, gameWin1       # Se P1 tem 10 pontos, P1 venceu
    beq $a1, 10, gameWin2       # Se P2 tem 10 pontos, P2 venceu
    
    # Verifica colisões da bola
    jal encostaCanto            
    
    # Processa entrada do usuário/IA
    j handleInput 

# ----------------------------------------------------------------------------
# ENCERRAMENTO DO JOGO
# ----------------------------------------------------------------------------
quit:
    li $v0, 10                  # Syscall 10: exit
    syscall

# ============================================================================
# FUNÇÃO: playBeep
# Descrição: Toca um som MIDI
# Entradas: $s2 = instrumento MIDI, $s0 = nota (pitch)
# Saídas: Nenhuma
# ============================================================================
playBeep:
    # Salva registradores na pilha
    subi $sp, $sp, 12
    sw $a0, 0($sp)
    sw $a2, 4($sp)
    sw $a3, 8($sp)
    
    # Configura parâmetros do som
    move $a2, $s2               # Instrumento
    move $a0, $s0               # Nota
    li $v0, 31                  # Syscall 31: MIDI out
    la $a1, duration            # Duração
    la $a3, volume              # Volume
    syscall
    
    # Restaura registradores da pilha
    lw $a0, 0($sp)
    lw $a2, 4($sp) 
    lw $a3, 8($sp) 
    addi $sp, $sp, 12
    jr $ra

# ============================================================================
# DINÂMICA DA BOLA - COLISÕES E FÍSICA
# ============================================================================

# ----------------------------------------------------------------------------
# FUNÇÃO: encostaBola
# Descrição: Verifica se a bola, apos detectar um canto da tela, colidiu com uma raquete
# Entradas: $a3 = Y da raquete, 
#           $a2 = qual raquete (0 ou 1, 1p ou 2p), 
#           $a1 = Y da bola
# Saídas: Rebate a bola ou reseta se errou
# ----------------------------------------------------------------------------
encostaBola:
    lw $s3, Raquete             # Tamanho da raquete (7 pixels)
    li $t0, 0                   # Contador de pixels da raquete
    
    # Loop para verificar cada pixel da raquete
    loopEncosta:
        beq $t0, $s3, resetBola     # Se percorreu todo a raquete, nn encostou e reseta bola
        beq $a3, $a1, rebateBola    # Se Y da raquete == Y da bola, rebate
        addi $a3, $a3, 1            # Próximo pixel da raquete
        addi $t0, $t0, 1            # Incrementa contador
        j loopEncosta

# ----------------------------------------------------------------------------
# FUNÇÃO: rebateBola
# Descrição: Rebate a bola quando ela colide com a raquete
# Modifica a direção baseado em onde a bola acertou a raquete
# ----------------------------------------------------------------------------
rebateBola:
    # Salva endereço de retorno e toca som
    addi $sp, $sp, -4
    sw $ra, 0($sp)
    lbu $s2, bounce             
    lbu $s0, beep               
    jal playBeep                
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    
    # Calcula novo ângulo baseado na posição de impacto
    lw $t1, direcao             # Componente Y atual
    lw $t2, direcao + 4         # Componente X atual
    la $t3, angulos             # Endereço da tabela de ângulos
    sll $t0, $t0, 2             # Multiplica índice por 4 (tamanho da word)
    add $t0, $t3, $t0           # Calcula endereço do ângulo
    lw $t0, 0($t0)              # Carrega novo ângulo Y
    sw $t0, direcao             # Atualiza direção Y
    
    # Esse bloco amortece a velocidade se bateu no meio da raquete
        bgtz $t2, praDireita        # Se X positivo, bola vai para direita  
        # Bola indo para esquerda
        praEsquerda:
            li $v0, -1              # Direção base: esquerda
            j amortecer        
        # Bola indo para direita
        praDireita:
            li $v0, 1               # Direção base: direita     
        # Sistema de aceleração da bola
        amortecer:
            beqz $t3, resetVelocidade   # Se ângulo é 0, não acelera
        
    # Esse bloco acelera a velocidade, com um limite
    lw $t4, velocidadeMax       # Carrega velocidade máxima
    bgtz $t2, aceleraBola       # Se X > 0, acelera para direita
    # Acelera para direita
    aceleraBola:
        addi $t2, $t2, 1            # Aumenta velocidade
        sub $t3, $t2, $t4           # Verifica se atingiu máximo
        li $v0, 2
        beqz $t3, resetVelocidade   # Se atingiu máximo, reseta
        sub $t2, $zero, $t2         # Inverte direção
        sw $t2, direcao + 4         # Salva nova velocidade
        j moveBola    
    # Acelera para esquerda
    subi $t2, $t2, 1            # Aumenta velocidade (mais negativo)
    add $t3, $t2, $t4           # Verifica se atingiu máximo
    li $v0, -2
    beqz $t3, resetVelocidade   # Se atingiu máximo, reseta
    sub $t2, $zero, $t2         # Inverte direção
    sw $t2, direcao + 4         # Salva nova velocidade
    j moveBola

    # Reseta velocidade ao máximo permitido
    resetVelocidade:
        la $t2, ($v0)               # Carrega velocidade base
        sub $t2, $zero, $t2         # Inverte para direção correta
        sw $t2, direcao + 4         # Salva velocidade
        j moveBola

# ----------------------------------------------------------------------------
# FUNÇÃO: inverteY
# Descrição: Inverte a direção vertical da bola (colisão com teto/chão)
# ----------------------------------------------------------------------------
inverteY:
    lw $t1, direcao             # Carrega componente Y
    sub $t1, $zero, $t1         # Inverte sinal
    sw $t1, direcao             # Salva nova direção
    
    # Toca som de rebatida
    addi $sp, $sp, -4
    sw $ra, 0($sp)
    lbu $s2, bounce
    lbu $s0, beep
    jal playBeep
    lw $ra, 0($sp)
    j moveBola

# ----------------------------------------------------------------------------
# FUNÇÃO: encostaCanto
# Descrição: Verifica se a bola está próxima das raquetes ou das bordas
# ----------------------------------------------------------------------------
encostaCanto:
    lw $a0, Bola+4              # X da bola
    lw $a1, Bola                # Y da bola
    
    # Verifica colisão com raquete 1 (esquerda)
    lw $t2, p1Raquete + 4       # X da raquete 1
    addi $t2, $t2, 1            # Borda direita da raquete 1
    lw $a3, p1Raquete           # Y da raquete 1
    sub $t2, $a0, $t2           # Calcula distância
    li $a2, 0                   # Identifica como raquete 1
    blez $t2, encostaBola       # Se bola alcançou raquete, verifica colisão
    
    # Verifica colisão com raquete 2 (direita)
    lw $t2, p2Raquete + 4       # X da raquete 2
    subi $t2, $t2, 1            # Borda esquerda da raquete 2
    lw $a3, p2Raquete           # Y da raquete 2
    sub $t2, $a0, $t2           # Calcula distância
    li $a2, 1                   # Identifica como raquete 2
    bgez $t2, encostaBola       # Se bola alcançou raquete, verifica colisão

# ----------------------------------------------------------------------------
# FUNÇÃO: encostaVertical
# Descrição: Verifica colisão com teto ou chão
# ----------------------------------------------------------------------------
encostaVertical:
    lw $a1, Bola                # Y da bola
    lw $t2, Dimensao            # Tamanho do campo
    subi $t2, $t2, 1            # Última linha válida
    beq $a1, $zero, inverteY    # Se Y = 0 (topo), inverte
    beq $a1, $t2, inverteY      # Se Y = máximo (chão), inverte
    # Se não colidiu, continua normalmente

# ----------------------------------------------------------------------------
# FUNÇÃO: moveBola
# Descrição: Move a bola na direção atual e desenha na nova posição
# ----------------------------------------------------------------------------
moveBola:
    # Salva endereço de retorno
    addi $sp, $sp, -4
    sw $ra, 0($sp)
    
    # Apaga posição anterior da bola
    lw $a0, Bola+4              # X da bola
    lw $a1, Bola                # Y da bola
    li $a2, 0                   # Cor preta (apaga)
    jal DrawDot

# Move a bola sem apagar rastro ( caso do reset )
moveImmediateBola:
    lw $a0, Bola+4              # X da bola
    lw $a1, Bola                # Y da bola
    moveY:
        # Atualiza posição Y
        lw $t2, direcao             # Direção Y
        add $a1, $a1, $t2           # Nova posição Y
        
        # Verifica limites verticais
        lw $s7, Dimensao
        li $v0, 1
        bltz $a1, corrigeUltrapassoY    # Se Y < 0, corrige
        li $v0, -1
        bge $a1, $s7, corrigeUltrapassoY # Se Y >= dimensão, corrige
        
    # Atualiza posição X
    moveX:
        lw $t1, direcao + 4         # Direção X
        add $a0, $a0, $t1           # Nova posição X
        
        # Verifica limites horizontais (raquetes)
        lw $t2, p1Raquete + 4       # X da raquete 1
        sub $t2, $a0, $t2
        li $v0, 1
        blez $t2, corrigeUltrapassoX # Se passou da raquete 1
        
        lw $t2, p2Raquete + 4       # X da raquete 2
        sub $t2, $a0, $t2
        li $v0, -1
        bgez $t2, corrigeUltrapassoX # Se passou da raquete 2
    
    # Desenha bola na nova posição
    desenha:
        sw $a1, Bola                # Salva novo Y
        sw $a0, Bola + 4            # Salva novo X
        li $a2, 1                   # Cor azul (bola)
        jal DrawDot
        
        # Restaura registradores
        lw $ra, 0($sp)
        addi $sp, $sp, 4
        jr $ra

# Correções de ultrapassagem de limites
corrigeUltrapassoX:
    add $a0, $a0, $v0           # Ajusta X
    j desenha

corrigeUltrapassoY:
    add $a1, $a1, $v0           # Ajusta Y
    j moveX

# ----------------------------------------------------------------------------
# FUNÇÃO: resetBola
# Descrição: Reseta a bola ao centro e registra ponto
# Entrada: $a2 = qual lado errou (0 = esquerda, 1 = direita)
# ----------------------------------------------------------------------------
resetBola:
    # Salva contexto
    addi $sp, $sp, -4
    sw $ra, 0($sp)
    
    move $s7, $a2               # Guarda qual jogador errou
    
    # Apaga bola da posição atual
    li $a2, 0
    jal DrawDot
    
    # Toca som de ponto
    lbu $s2, bounce
    lbu $s0, boop
    jal playBeep
    
    # Reseta posição da bola ao centro
    li $t0, 16
    sw $t0, Bola                # Y = 16 (centro)
    sw $t0, Bola +4             # X = 16 (centro)
    
    # Reseta direção Y (horizontal pura)
    lw $t1, direcao
    li $t1, 0
    sw $t1, direcao
    
    move $a0, $t0               # X da bola
    move $a1, $t0               # Y da bola
    
    # Restaura contexto
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    
    # Registra ponto para o jogador apropriado
    beqz $s7, ponto2            # Se errou esquerda, ponto para P2
    j ponto1                    # Se errou direita, ponto para P1

# Registra ponto para jogador 2
ponto2:
    lw $t0, p2_score
    addi $t0, $t0, 1            # Incrementa pontuação
    sw $t0, p2_score
    
    lw $t1, direcao + 4
    li $t1, 1                   # Bola vai para direita
    sw $t1, direcao + 4
    j donePonto

# Registra ponto para jogador 1
ponto1:
    lw $t0, p1_score
    addi $t0, $t0, 1            # Incrementa pontuação
    sw $t0, p1_score
    
    lw $t1, direcao + 4
    li $t1, -1                  # Bola vai para esquerda
    sw $t1, direcao + 4
    j donePonto

# Finaliza registro de ponto
donePonto:
    # Atualiza placar na tela
    addi $sp, $sp, -4
    sw $ra, 0($sp)
    jal showScore
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    
    # Move bola imediatamente
    addi $sp, $sp, -4
    sw $ra, 0($sp)
    j moveImmediateBola

# ============================================================================
# DINÂMICA DE ENTRADA - CONTROLES DOS JOGADORES
# ============================================================================

# ----------------------------------------------------------------------------
# FUNÇÃO: handleInput
# Descrição: Processa teclas pressionadas pelos jogadores
# ----------------------------------------------------------------------------
handleInput:
    lw $t3, KEY_DATA            # Lê tecla pressionada
    li $t0, 1
    
    # Verifica controles do Jogador 1
    beq $t3, 119, p1_is_up      # 'w' = subir
    beq $t3, 115, p1_is_down    # 's' = descer
    beq $t3, 100, quit          # 'd' = sair
    
    # Verifica modo de jogo
    lw $t2, gameMode
    bnez $t2, handleIA          # Se modo IA, processa IA
    
    # Modo 2 jogadores - verifica controles do Jogador 2
    handleInput2P:
        beq $t3, 56, p2_is_up       # '8' (seta cima) = subir
        beq $t3, 50, p2_is_down     # '2' (seta baixo) = descer
        j handleRaquetes

# ----------------------------------------------------------------------------
# FUNÇÃO: handleIA
# Descrição: Controla a raquete do jogador 2 automaticamente (IA)
# ----------------------------------------------------------------------------
handleIA:
    lw $t0, Bola                # Y da bola
    lw $t1, p2Raquete           # Y do topo da raquete
    
    # Calcula ponto médio da raquete
    lw $t3, Raquete             # Tamanho da raquete
    srl $t3, $t3, 1             # Divide por 2
    add $t1, $t1, $t3           # Centro da raquete
    
    # Decide direção baseado na posição da bola
    sub $t3, $t0, $t1           # Diferença Y (bola - raquete)
    bgtz $t3, p2_is_down        # Se bola está abaixo, desce
    j p2_is_up                  # Se bola está acima, sobe

# Estados de movimento - Jogador 1
p1_is_up:
    sw $t0, p1_up               # Marca que está subindo
    sw $zero, p1_down           # Limpa flag de descida
    lw $t2, gameMode
    bnez $t2, handleIA          # Se tem IA, processa P2
    j handleRaquetes

p1_is_down:
    sw $t0, p1_down             # Marca que está descendo
    sw $zero, p1_up             # Limpa flag de subida
    lw $t2, gameMode
    bnez $t2, handleIA          # Se tem IA, processa P2
    j handleRaquetes

# Estados de movimento - Jogador 2
p2_is_up:
    sw $t0, p2_up               # Marca que está subindo
    sw $zero, p2_down           # Limpa flag de descida
    j handleRaquetes

p2_is_down:
    sw $t0, p2_down             # Marca que está descendo
    sw $zero, p2_up             # Limpa flag de subida
    j handleRaquetes

# ----------------------------------------------------------------------------
# FUNÇÃO: handleRaquetes
# Descrição: Atualiza posição das raquetes baseado nos estados de movimento
# ----------------------------------------------------------------------------
handleRaquetes:
    # Verifica estado do Jogador 1
    p1Status:
        lw $t0, p1_up
        beq $t0, $zero, p1MoveDown  # Se não está subindo, verifica descida
        j p1MoveUp
    
    # Verifica estado do Jogador 2
    p2Status:
        lw $t0, p2_up
        beq $t0, $zero, p2MoveDown  # Se não está subindo, verifica descida
        j p2MoveUp

# Move raquete 1 para cima
p1MoveUp:
    lw $t0, p1Raquete           # Y atual da raquete
    beqz $t0, p2Status          # Se já está no topo, não move
    
    lw $t2, Raquete             # Tamanho da raquete
    add $t1, $t0, $t2           # Último pixel da raquete
    subi $t1, $t1, 1
    subi $t0, $t0, 1            # Nova posição (sobe)
    sw $t0, p1Raquete           # Salva nova posição
    
    lw $a0, p1Raquete + 4       # X da raquete
    
    # Desenha novo topo
    la $a1, ($t0)
    li $a2, 3                   # Cor vermelha
    jal DrawDot
    
    # Apaga base antiga
    la $a1, ($t1)
    li $a2, 0                   # Cor preta
    jal DrawDot
    j p2Status

# Move raquete 1 para baixo
p1MoveDown:
    lw $t0, p1Raquete           # Y atual
    add $t1, $zero, $t0         # Guarda Y antigo
    
    lw $t2, Raquete             # Tamanho
    lw $t3, Dimensao            # Limite da tela
    add $t4, $t0, $t2           # Y final da raquete
    beq $t4, $t3, p2Status      # Se já está no chão, não move
    
    addi $t0, $t0, 1            # Nova posição (desce)
    sw $t0, p1Raquete           # Salva nova posição
    
    lw $a0, p1Raquete + 4       # X da raquete
    
    # Desenha nova base
    add $t0, $t0, $t2
    subi $t0, $t0, 1
    la $a1, ($t0)
    li $a2, 3                   # Cor vermelha
    jal DrawDot
    
    # Apaga topo antigo
    la $a1, ($t1)
    li $a2, 0                   # Cor preta
    jal DrawDot
    j p2Status

# Move raquete 2 para cima
p2MoveUp:
    lw $t0, p2Raquete           # Y atual da raquete
    beqz $t0, main              # Se já está no topo, volta ao loop principal
    
    lw $t2, Raquete             # Tamanho da raquete
    add $t1, $t0, $t2           # Último pixel da raquete
    subi $t1, $t1, 1
    subi $t0, $t0, 1            # Nova posição (sobe)
    sw $t0, p2Raquete           # Salva nova posição
    
    lw $a0, p2Raquete + 4       # X da raquete
    
    # Desenha novo topo
    la $a1, ($t0)
    li $a2, 3                   # Cor vermelha
    jal DrawDot
    
    # Apaga base antiga
    la $a1, ($t1)
    li $a2, 0                   # Cor preta
    jal DrawDot
    j main

# Move raquete 2 para baixo
p2MoveDown:
    lw $t0, p2Raquete           # Y atual
    add $t1, $zero, $t0         # Guarda Y antigo
    
    lw $t2, Raquete             # Tamanho
    lw $t3, Dimensao            # Limite da tela
    add $t4, $t0, $t2           # Y final da raquete
    beq $t4, $t3, main          # Se já está no chão, volta ao loop principal
    
    addi $t0, $t0, 1            # Nova posição (desce)
    sw $t0, p2Raquete           # Salva nova posição
    
    lw $a0, p2Raquete + 4       # X da raquete
    
    # Desenha nova base
    add $t0, $t0, $t2
    subi $t0, $t0, 1
    la $a1, ($t0)
    li $a2, 3                   # Cor vermelha
    jal DrawDot
    
    # Apaga topo antigo
    la $a1, ($t1)
    li $a2, 0                   # Cor preta
    jal DrawDot
    j main

# ============================================================================
# FUNÇÕES DE DESENHO - SISTEMA DE GRÁFICOS
# ============================================================================

# ----------------------------------------------------------------------------
# FUNÇÃO: CalculateAddress
# Descrição: Converte coordenadas (x,y) para endereço de memória do display
# Entradas: $a0 = coordenada X (0-31), $a1 = coordenada Y (0-31)
# Saídas: $v0 = endereço de memória calculado
# Fórmula: endereço = 0x10040000 + (4 * X) + (128 * Y)
# ----------------------------------------------------------------------------
CalculateAddress:
    li $v0, KEY_DISPLAY         # Endereço base do display
    sll $t2, $a0, 2             # t2 = X * 4 (cada pixel = 4 bytes)
    sll $t3, $a1, 7             # t3 = Y * 128 (32 pixels * 4 bytes por linha)
    add $v0, $v0, $t2           # Adiciona offset X
    add $v0, $v0, $t3           # Adiciona offset Y
    jr $ra

# ----------------------------------------------------------------------------
# FUNÇÃO: GetColor
# Descrição: Obtém valor RGB de uma cor usando lookup table
# Entradas: $a2 = índice da cor (0-4)
# Saídas: $v1 = valor RGB da cor
# ----------------------------------------------------------------------------
GetColor:
    la $t0, ColorTable          # Endereço da tabela de cores
    sll $a3, $a2, 2             # Multiplica índice por 4 (tamanho da word)
    add $a3, $a3, $t0           # Calcula endereço da cor
    lw $v1, 0($a3)              # Carrega valor RGB
    jr $ra

# ----------------------------------------------------------------------------
# FUNÇÃO: DrawDot
# Descrição: Desenha um pixel na tela com a cor especificada
# Entradas: $a0 = X, $a1 = Y, $a2 = índice da cor
# Saídas: Nenhuma
# ----------------------------------------------------------------------------
DrawDot:
    # Valida coordenadas (evita desenhar fora da tela)
    bltz $a0, doneDrawingDot    # Se X < 0, não desenha
    bltz $a1, doneDrawingDot    # Se Y < 0, não desenha
    bgt $a0, 31, doneDrawingDot # Se X > 31, não desenha
    bgt $a1, 31, doneDrawingDot # Se Y > 31, não desenha
    
    # Salva endereço de retorno
    addi $sp, $sp, -4
    sw $ra, 0($sp)
    
    jal CalculateAddress        # Calcula endereço de memória
    jal GetColor                # Obtém cor RGB
    
    sw $v1, 0($v0)              # Escreve cor na memória (desenha pixel)
    
    # Restaura endereço de retorno
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    
    doneDrawingDot:
        jr $ra

# ----------------------------------------------------------------------------
# FUNÇÃO: DrawRaquetes
# Descrição: Desenha as duas raquetes na tela
# ----------------------------------------------------------------------------
DrawRaquetes:
    # Salva contexto
    addi $sp, $sp, -4
    sw $ra, 0($sp)
    
    # Carrega dados das raquetes
    lw $s1, p1Raquete           # Y da raquete 1
    lw $s2, p1Raquete + 4       # X da raquete 1
    li $a2, 3                   # Cor vermelha
    lw $s3, p2Raquete           # Y da raquete 2
    lw $s4, p2Raquete + 4       # X da raquete 2
    
    lw $s7, Raquete             # Tamanho da raquete
    li $s0, 0                   # Contador de pixels
    
    # Loop para desenhar cada pixel das raquetes
    loop:
        beq $s0, $s7, doneRaquete   # Se desenhou todos os pixels, termina
        
        # Desenha pixel da raquete esquerda (P1)
        la $a0, ($s2)               # X da raquete 1
        add $a1, $s1, $s0           # Y = topo + offset
        jal DrawDot 
        
        # Desenha pixel da raquete direita (P2)
        la $a0, ($s4)               # X da raquete 2
        add $a1, $s3, $s0           # Y = topo + offset
        jal DrawDot 
        
        addi $s0, $s0, 1            # Próximo pixel
        j loop

    doneRaquete:
        # Restaura contexto
        lw $ra, 0($sp)
        addi $sp, $sp, 4
        jr $ra

# ----------------------------------------------------------------------------
# FUNÇÃO: clearScreen
# Descrição: Limpa toda a tela (preenche com preto)
# ----------------------------------------------------------------------------
clearScreen:
    # Salva contexto
    addi $sp, $sp, -4
    sw $ra, 0($sp)
    
    lw $s7, Dimensao            # Tamanho da tela (32x32)
    li $s0, 0                   # Contador X
    li $s1, 0                   # Contador Y
    
    # Loop para cada coluna
    loopx:
        beq $s0, $s7, somaY         # Se terminou coluna, próxima linha
        move $a0, $s0               # X atual
        move $a1, $s1               # Y atual
        li $a2, 0                   # Cor preta
        jal DrawDot                 # Desenha pixel preto
        addi $s0, $s0, 1            # Próximo X
        j loopx
    
    # Próxima linha
    somaY:
        addi $s1, $s1, 1            # Próximo Y
        beq $s1, $s7, doneClear     # Se terminou tela, finaliza
        li $s0, 0                   # Reseta X para nova linha
        j loopx
    
    doneClear:
        # Restaura contexto
        lw $ra, 0($sp)
        addi $sp, $sp, 4
        jr $ra

# ----------------------------------------------------------------------------
# FUNÇÃO: dotLine
# Descrição: Desenha linha pontilhada no centro (não utilizada no jogo atual)
# ----------------------------------------------------------------------------
dotLine:
    # Salva contexto
    addi $sp, $sp, -4
    sw $ra, 0($sp)
    
    lw $s7, Dimensao            # Tamanho da tela
    srl $s0, $s7, 1             # X = centro (divide por 2)
    li $s1, 0                   # Y inicial
    
    # Loop para desenhar linha pontilhada
    loopDot:
        bge $s1, $s7, doneLine      # Se chegou ao fim, termina
        
        # Desenha 2 pixels brancos
        la $a0, ($s0)               # X = centro
        la $a1, ($s1)               # Y atual
        li $a2, 4                   # Cor branca
        jal DrawDot
        
        addi $s1, $s1, 1            # Próximo Y
        la $a1, ($s1)
        li $a2, 4
        jal DrawDot
        
        addi $s1, $s1, 2            # Pula 2 pixels (efeito pontilhado)
        j loopDot
    
    doneLine:
        # Restaura contexto
        lw $ra, 0($sp)
        addi $sp, $sp, 4
        jr $ra

# ============================================================================
# SISTEMA DE PLACAR
# ============================================================================

# ----------------------------------------------------------------------------
# FUNÇÃO: showScore
# Descrição: Desenha os placares dos dois jogadores na tela
# ----------------------------------------------------------------------------
showScore:
    # Salva contexto
    addi $sp, $sp, -8
    sw $ra, 4($sp)
    sw $s0, 0($sp)

    # Desenha placar do Jogador 1 (canto superior esquerdo)
    lw $s0, p1_score            # Carrega pontuação P1
    li $a0, 4                   # X = 4
    li $a1, 2                   # Y = 2
    move $a3, $s0               # Dígito a desenhar
    jal drawDigit               # Desenha número

    # Desenha placar do Jogador 2 (canto superior direito)
    lw $s0, p2_score            # Carrega pontuação P2
    li $a0, 24                  # X = 24 (lado direito)
    li $a1, 2                   # Y = 2
    move $a3, $s0               # Dígito a desenhar
    jal drawDigit               # Desenha número

    # Restaura contexto
    lw $s0, 0($sp)
    lw $ra, 4($sp)
    addi $sp, $sp, 8
    jr $ra

# ----------------------------------------------------------------------------
# FUNÇÃO: drawDigit
# Descrição: Desenha um dígito (0-9) na posição especificada
# Entradas: $a0 = X, $a1 = Y, $a3 = dígito (0-9)
# Usa matriz 3x6 pixels para cada número
# ----------------------------------------------------------------------------
drawDigit:
    # Salva contexto
    addi $sp, $sp, -4
    sw $ra, 0($sp)

    li $t0, 0
    li $a2, 4                   # Cor branca para dígitos
    
    # Switch case para cada dígito
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

# Chamadas para funções de desenho de cada dígito
call0: 
    jal drawNull                # Limpa área
    jal draw0                   # Desenha 0
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
    # Restaura contexto
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    jr $ra

# ============================================================================
# FUNÇÕES DE DESENHO DOS NÚMEROS 0-9 E LETRA P
# Cada número é desenhado em uma matriz de 3x6 pixels
# Pivot = (a0, a1) = canto superior esquerdo
# a2 = índice da cor
# ============================================================================

# ----------------------------------------------------------------------------
# FUNÇÃO: drawNull
# Descrição: Apaga/limpa a área de um dígito (preenche com preto)
# ----------------------------------------------------------------------------
drawNull:
    li $a2, 0                   # Cor preta
    
    # Salva contexto
    addi $sp, $sp, -4
    sw $ra, 0($sp)
    
    add $s0, $a0, $zero         # X inicial
    add $s1, $a1, $zero         # Y inicial
    li $s5, 0                   # Contador de linhas
    
    # Loop para apagar cada linha do dígito
    drawNulloop:
        add $a1, $s1, $s5       # Y = inicial + offset
        jal DrawDot             # Coluna 0
        
        addi $a0, $s0, 1        # Coluna 1
        jal DrawDot
        
        addi $a0, $s0, 2        # Coluna 2
        jal DrawDot
        
        addi $s5, $s5, 1        # Próxima linha
        move $a0, $s0           # Restaura X inicial
        blt $s5, 6, drawNulloop # Repete para 6 linhas
    
    li $a2, 4                   # Restaura cor branca
    
    # Restaura contexto
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    move $a1, $s1               # Restaura Y inicial
    jr $ra

# ----------------------------------------------------------------------------
# FUNÇÃO: draw0
# Padrão:  ###
#          # #
#          # #
#          # #
#          # #
#          ###
# ----------------------------------------------------------------------------
draw0:
    # Salva contexto
    addi $sp, $sp, -4
    sw $ra, 0($sp)
    
    addi $s0, $a0, 0            # X base
    addi $s1, $a1, 0            # Y base
    
    # Linha 0 (topo): ###
    jal DrawDot
    addi $a0, $s0, 1
    move $a1, $s1
    jal DrawDot
    addi $a0, $s0, 2
    move $a1, $s1
    jal DrawDot
    
    # Linhas 1-4 (meio): # #
    addi $a1, $s1, 1
    li $s5, 0
    draw0_loop1:
        addi $a0, $s0, 0        # Coluna esquerda
        jal DrawDot
        addi $a0, $s0, 2        # Coluna direita
        jal DrawDot
        addi $a1, $a1, 1
        addi $s5, $s5, 1
        bne $s5, 5, draw0_loop1

    # Linha 5 (base): ###
    addi $a0, $s0, 0
    addi $a1, $s1, 5
    jal DrawDot
    addi $a0, $s0, 1 
    jal DrawDot
    addi $a0, $s0, 2
    jal DrawDot
    
    # Restaura contexto
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    jr $ra

# ----------------------------------------------------------------------------
# FUNÇÃO: draw1
# Padrão:   #
#           #
#           #
#           #
#           #
#           #
# ----------------------------------------------------------------------------
draw1:
    # Salva contexto
    addi $sp, $sp, -4
    sw $ra, 0($sp)
    
    add $s0, $a0, $zero         # X base
    add $s1, $a1, $zero         # Y base
    li $s5, 0                   # Contador
    
    # Loop para desenhar linha vertical
    draw1_loop:
        addi $a0, $s0, 1        # X = base + 1 (coluna do meio)
        add $a1, $s1, $s5       # Y = base + offset
        jal DrawDot
        addi $s5, $s5, 1        # Próxima linha
        blt $s5, 6, draw1_loop  # Repete 6 vezes
    
    # Restaura contexto
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    jr $ra

# ----------------------------------------------------------------------------
# FUNÇÃO: draw2
# Padrão:  ###
#            #
#            #
#          ###
#          #
#          ###
# ----------------------------------------------------------------------------
draw2:
    # Salva contexto
    addi $sp, $sp, -4
    sw $ra, 0($sp)
    
    add $s0, $a0, $zero
    add $s1, $a1, $zero

    # Linha 0: ###
    addi $a1, $s1, 0
    addi $a0, $s0, 0 
    jal DrawDot
    addi $a0, $s0, 1 
    jal DrawDot
    addi $a0, $s0, 2 
    jal DrawDot

    # Linha 1: #
    addi $a1, $s1, 1
    addi $a0, $s0, 2  
    jal DrawDot

    # Linha 2: #
    addi $a1, $s1, 2
    addi $a0, $s0, 2  
    jal DrawDot

    # Linha 3: ###
    addi $a1, $s1, 3
    addi $a0, $s0, 0 
    jal DrawDot
    addi $a0, $s0, 1 
    jal DrawDot
    addi $a0, $s0, 2 
    jal DrawDot

    # Linha 4: #
    addi $a1, $s1, 4
    addi $a0, $s0, 0 
    jal DrawDot

    # Linha 5: ###
    addi $a1, $s1, 5
    addi $a0, $s0, 0  
    jal DrawDot
    addi $a0, $s0, 1 
    jal DrawDot
    addi $a0, $s0, 2 
    jal DrawDot
    
    # Restaura contexto
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    jr $ra

# ----------------------------------------------------------------------------
# FUNÇÃO: draw3
# Padrão:  ###
#            #
#            #
#          ###
#            #
#          ###
# ----------------------------------------------------------------------------
draw3:
    # Salva contexto
    addi $sp, $sp, -4
    sw $ra, 0($sp)
    
    add $s0, $a0, $zero
    add $s1, $a1, $zero

    # Linha 0: ###
    addi $a1, $s1, 0
    addi $a0, $s0, 0  
    jal DrawDot
    addi $a0, $s0, 1  
    jal DrawDot
    addi $a0, $s0, 2 
    jal DrawDot

    # Linha 1: #
    addi $a1, $s1, 1
    addi $a0, $s0, 2 
    jal DrawDot

    # Linha 2: #
    addi $a1, $s1, 2
    addi $a0, $s0, 2  
    jal DrawDot

    # Linha 3 (meio): ###
    addi $a1, $s1, 3
    addi $a0, $s0, 0  
    jal DrawDot
    addi $a0, $s0, 1  
    jal DrawDot
    addi $a0, $s0, 2 
    jal DrawDot

    # Linha 4: #
    addi $a1, $s1, 4
    addi $a0, $s0, 2 
    jal DrawDot

    # Linha 5: ###
    addi $a1, $s1, 5
    addi $a0, $s0, 0 
    jal DrawDot
    addi $a0, $s0, 1 
    jal DrawDot
    addi $a0, $s0, 2  
    jal DrawDot
    
    # Restaura contexto
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    jr $ra

# ----------------------------------------------------------------------------
# FUNÇÃO: draw4
# Padrão:  # #
#          # #
#          # #
#          ###
#            #
#            #
# ----------------------------------------------------------------------------
draw4:
    # Salva contexto
    addi $sp, $sp, -4
    sw $ra, 0($sp)
    
    add $s0, $a0, $zero
    add $s1, $a1, $zero

    # Linhas 0-2: # #
    li $s5, 0
    draw4_loop1:
        add $a1, $s1, $s5 
        jal DrawDot             # Coluna esquerda
        addi $a0, $s0, 2  
        jal DrawDot             # Coluna direita
        addi $s5, $s5, 1
        move $a0, $s0
        blt $s5, 3, draw4_loop1

    # Linha 3 (meio): ###
    addi $a1, $s1, 3 
    jal DrawDot
    addi $a0, $s0, 1  
    jal DrawDot
    addi $a0, $s0, 2  
    jal DrawDot

    # Linhas 4-5: #
    addi $a1, $s1, 4
    addi $a0, $s0, 2  
    jal DrawDot
    addi $a1, $s1, 5
    addi $a0, $s0, 2  
    jal DrawDot
    
    # Restaura contexto
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    jr $ra

# ----------------------------------------------------------------------------
# FUNÇÃO: draw5
# Padrão:  ###
#          #
#          #
#          ###
#            #
#          ###
# ----------------------------------------------------------------------------
draw5:
    # Salva contexto
    addi $sp, $sp, -4
    sw $ra, 0($sp)
    
    add $s0, $a0, $zero
    add $s1, $a1, $zero

    # Linha 0: ###
    addi $a1, $s1, 0
    addi $a0, $s0, 0  
    jal DrawDot
    addi $a0, $s0, 1  
    jal DrawDot
    addi $a0, $s0, 2  
    jal DrawDot

    # Linha 1: #
    addi $a1, $s1, 1
    addi $a0, $s0, 0  
    jal DrawDot

    # Linha 2: #
    addi $a1, $s1, 2
    addi $a0, $s0, 0  
    jal DrawDot

    # Linha 3: ###
    addi $a1, $s1, 3
    addi $a0, $s0, 0  
    jal DrawDot
    addi $a0, $s0, 1  
    jal DrawDot
    addi $a0, $s0, 2  
    jal DrawDot

    # Linha 4: #
    addi $a1, $s1, 4
    addi $a0, $s0, 2  
    jal DrawDot

    # Linha 5: ###
    addi $a1, $s1, 5
    addi $a0, $s0, 0  
    jal DrawDot
    addi $a0, $s0, 1  
    jal DrawDot
    addi $a0, $s0, 2  
    jal DrawDot
    
    # Restaura contexto
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    jr $ra

# ----------------------------------------------------------------------------
# FUNÇÃO: draw6
# Padrão:  ###
#          #
#          #
#          ###
#          # #
#          ###
# ----------------------------------------------------------------------------
draw6:
    # Salva contexto
    addi $sp, $sp, -4
    sw $ra, 0($sp)
    
    add $s0, $a0, $zero
    add $s1, $a1, $zero

    # Linha 0: ###
    addi $a1, $s1, 0
    addi $a0, $s0, 0 
    jal DrawDot
    addi $a0, $s0, 1  
    jal DrawDot
    addi $a0, $s0, 2  
    jal DrawDot

    # Linha 1: #
    addi $a1, $s1, 1
    addi $a0, $s0, 0 
    jal DrawDot

    # Linha 2: #
    addi $a1, $s1, 2
    addi $a0, $s0, 0  
    jal DrawDot

    # Linha 3 (meio): ###
    addi $a1, $s1, 3
    addi $a0, $s0, 0  
    jal DrawDot
    addi $a0, $s0, 1  
    jal DrawDot
    addi $a0, $s0, 2 
    jal DrawDot

    # Linha 4: # #
    addi $a1, $s1, 4
    addi $a0, $s0, 0  
    jal DrawDot
    addi $a0, $s0, 2  
    jal DrawDot

    # Linha 5: ###
    addi $a1, $s1, 5
    addi $a0, $s0, 0  
    jal DrawDot
    addi $a0, $s0, 1 
    jal DrawDot
    addi $a0, $s0, 2 
    jal DrawDot
    
    # Restaura contexto
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    jr $ra

# ----------------------------------------------------------------------------
# FUNÇÃO: draw7
# Padrão:  ###
#            #
#            #
#           #
#          #
#          #
# ----------------------------------------------------------------------------
draw7:
    # Salva contexto
    addi $sp, $sp, -4
    sw $ra, 0($sp)
    
    add $s0, $a0, $zero
    add $s1, $a1, $zero

    # Linha 0: ###
    addi $a1, $s1, 0
    addi $a0, $s0, 0 
    jal DrawDot
    addi $a0, $s0, 1 
    jal DrawDot
    addi $a0, $s0, 2 
    jal DrawDot

    # Linha 1: #
    addi $a1, $s1, 1
    addi $a0, $s0, 2  
    jal DrawDot

    # Linha 2: #
    addi $a1, $s1, 2
    addi $a0, $s0, 2  
    jal DrawDot

    # Linha 3: # (meio)
    addi $a1, $s1, 3
    addi $a0, $s0, 1  
    jal DrawDot

    # Linha 4: #
    addi $a1, $s1, 4
    addi $a0, $s0, 0 
    jal DrawDot

    # Linha 5: #
    addi $a1, $s1, 5
    addi $a0, $s0, 0  
    jal DrawDot
    
    # Restaura contexto
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    jr $ra

# ----------------------------------------------------------------------------
# FUNÇÃO: draw8
# Padrão:  ###
#          # #
#          # #
#          ###
#          # #
#          ###
# ----------------------------------------------------------------------------
draw8:
    # Salva contexto
    addi $sp, $sp, -4
    sw $ra, 0($sp)
    
    add $s0, $a0, $zero
    add $s1, $a1, $zero

    # Linha 0: ###
    jal DrawDot
    addi $a0, $s0, 1 
    jal DrawDot
    addi $a0, $s0, 2  
    jal DrawDot

    # Linhas 1-2: # #
    li $s5, 1
    draw8_loop1:
        add $a1, $s1, $s5
        addi $a0, $s0, 0  
        jal DrawDot
        addi $a0, $s0, 2 
        jal DrawDot
        addi $s5, $s5, 1
        blt $s5, 3, draw8_loop1

    # Linha 3 (meio): ###
    addi $a1, $s1, 3
    addi $a0, $s0, 0 
    jal DrawDot
    addi $a0, $s0, 1 
    jal DrawDot
    addi $a0, $s0, 2 
    jal DrawDot

    # Linhas 4-5: # #
    li $s5, 4
    draw8_loop2:
        add $a1, $s1, $s5
        addi $a0, $s0, 0  
        jal DrawDot
        addi $a0, $s0, 2  
        jal DrawDot
        addi $s5, $s5, 1
        blt $s5, 6, draw8_loop2
    
    # Linha 5 (base): ###
    addi $a1, $s1, 5
    addi $a0, $s0, 0  
    jal DrawDot
    addi $a0, $s0, 1 
    jal DrawDot
    addi $a0, $s0, 2 
    jal DrawDot
    
    # Restaura contexto
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    jr $ra

# ----------------------------------------------------------------------------
# FUNÇÃO: draw9
# Padrão:  ###
#          # #
#          # #
#          ###
#            #
#            #
# ----------------------------------------------------------------------------
draw9:
    # Salva contexto
    addi $sp, $sp, -4
    sw $ra, 0($sp)
    
    add $s0, $a0, $zero
    add $s1, $a1, $zero

    # Linha 0: ###
    addi $a1, $s1, 0
    addi $a0, $s0, 0 
    jal DrawDot
    addi $a0, $s0, 1 
    jal DrawDot
    addi $a0, $s0, 2  
    jal DrawDot

    # Linhas 1-2: # #
    li $s5, 1
    draw9_toploop:
        add $a1, $s1, $s5
        addi $a0, $s0, 0 
        jal DrawDot
        addi $a0, $s0, 2  
        jal DrawDot
        addi $s5, $s5, 1
        blt $s5, 3, draw9_toploop

    # Linha 3 (meio): ###
    addi $a1, $s1, 3
    addi $a0, $s0, 0  
    jal DrawDot
    addi $a0, $s0, 1  
    jal DrawDot
    addi $a0, $s0, 2  
    jal DrawDot

    # Linha 4: #
    addi $a1, $s1, 4
    addi $a0, $s0, 2  
    jal DrawDot

    # Linha 5: #
    addi $a1, $s1, 5
    addi $a0, $s0, 2  
    jal DrawDot
    
    # Restaura contexto
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    jr $ra

# ----------------------------------------------------------------------------
# FUNÇÃO: drawP
# Padrão:  ###
#          #  #
#          #  #
#          ###
#          #  
#          #  
# Desenha a letra 'P' para o placar (P1, P2)
# ----------------------------------------------------------------------------
drawP:
    # Salva contexto
    addi $sp, $sp, -4
    sw $ra, 0($sp)
    
    add $s0, $a0, $zero
    add $s1, $a1, $zero

    # Linha 0: ###
    addi $a1, $s1, 0
    addi $a0, $s0, 0 
    jal DrawDot
    addi $a0, $s0, 1 
    jal DrawDot
    addi $a0, $s0, 2  
    jal DrawDot

    # Linhas 1-2: # #
    li $s5, 1
    drawP_toploop:
        add $a1, $s1, $s5
        addi $a0, $s0, 0 
        jal DrawDot
        addi $a0, $s0, 3          # Espaço maior para a letra P
        jal DrawDot
        addi $s5, $s5, 1
        blt $s5, 3, drawP_toploop

    # Linha 3 (meio): ###
    addi $a1, $s1, 3
    addi $a0, $s0, 0  
    jal DrawDot
    addi $a0, $s0, 1  
    jal DrawDot
    addi $a0, $s0, 2  
    jal DrawDot

    # Linha 4: #
    addi $a1, $s1, 4
    addi $a0, $s0, 0 
    jal DrawDot

    # Linha 5: #
    addi $a1, $s1, 5
    addi $a0, $s0, 0  
    jal DrawDot
    
    # Restaura contexto
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    jr $ra

# ============================================================================
# TELAS DE VITÓRIA
# ============================================================================

# ----------------------------------------------------------------------------
# FUNÇÃO: gameWin1
# Descrição: Exibe mensagem de vitória do Jogador 1
# ----------------------------------------------------------------------------


gameWin1:
    jal clearScreen             # Limpa a tela
    lbu $s2, point              # Carrega instrumento de pontuação
    	lbu $s0, beep               # Carrega pitch
    	jal playBeep                # Toca som inicial
    	
    # Desenha "P1" no centro da tela
    li $a0, 12                  # X centralizado
    li $a1, 5                   # Y centralizado
    li $a2, 4                   # Cor branca
    jal drawP                   # Desenha 'P'
    
    li $a0, 17                  # X para o número
    li $a1, 5                   # Y
    li $a2, 4                   # Cor branca
    jal draw1                   # Desenha '1'
    
    j quit                      # Encerra o jogo

# ----------------------------------------------------------------------------
# FUNÇÃO: gameWin2
# Descrição: Exibe mensagem de vitória do Jogador 2
# ----------------------------------------------------------------------------
gameWin2:
    jal clearScreen             # Limpa a tela
    lbu $s2, point              # Carrega instrumento de pontuação
    	lbu $s0, beep               # Carrega pitch
    	jal playBeep                # Toca som inicial
    	
    # Desenha "P2" no centro da tela
    li $a0, 12                  # X centralizado
    li $a1, 5                   # Y centralizado
    li $a2, 4                   # Cor branca
    jal drawP                   # Desenha 'P'
    
    li $a0, 17                  # X para o número
    li $a1, 5                   # Y
    li $a2, 4                   # Cor branca
    jal draw2                   # Desenha '2'
    
    j quit                      # Encerra o jogo

# ============================================================================
# FIM DO CÓDIGO
# ============================================================================
# 
# RESUMO DAS FUNCIONALIDADES:
# - Dois modos de jogo: 1 jogador (vs IA) e 2 jogadores
# - Controles P1: W (cima), S (baixo)
# - Controles P2: 8 (cima), 2 (baixo)
# - Sistema de física com aceleração da bola
# - Ângulos de reflexão baseados na posição de impacto
# - Placar em tempo real
# - Efeitos sonoros MIDI
# - Condição de vitória: primeiro a 10 pontos
# - Resolução: 32x32 pixels
# - Taxa de atualização: ~13.5 FPS (74ms por frame)
# 
# CONFIGURAÇÃO NECESSÁRIA NO MARS:
# - Bitmap Display: 32x32, pixel size 16x16, base address 0x10040000
# - Keyboard MMIO Simulator
# - MIDI Output (opcional, para sons)
# ============================================================================
