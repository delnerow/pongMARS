# pongMARS
Classic PONG game implemented in MIPS on MARS

## TODO
* Add bolinha que andar com uma direção e se bater numa raquete inverte direção
* Fazer velocidade da bolinha aumentar com base no numero de batidas
* Fazer quinas da raquete angularem a bolinha
* Fazer bolinha resetar quando ultrapassar os limites do display
* Atribuir pontuação aos players
* Mostrar no display a pontuação
* Fazer IA do 2nd player
* Tela de inicio para escolher o modo de jogo
* Opcional: botos de halt (parada da raquete) para cada jogador

## Workings
Uses Bitmap Display and MMIMO Simulator. Remember to connect both to MIPS.


Deixe as configurações do Bitmap do MIPS como
* Unit Width in Pixels : 8
* Unit Height in Pixels: 8
* Display Width in Pixels: 256
* Display Height in Pixels: 256
* Base address: heap

O jogo contém duas opções de modo de jogo:
* Single Player (contra a máquina, com movimento automático da segunda
raquete). #TODO
* Multiplayer (dois jogadores utilizando o mesmo teclado). #TODO

O jogo deve exibir a bola se movendo pelo campo, rebatendo nas bordas e nas
raquetes.
* Sempre que ocorrer uma colisão da bola com uma borda ou com uma raquete, o
sistema deverá emitir um som de “beep”.
* O jogo deve ser exibido utilizando o Bitmap Display Tool do MARS e controlado via
teclado.

O controle das raquetes deve ser feito através das teclas:
* Jogador 1: W / S (para cima / para baixo)
* Jogador 2: ↑ / ↓ (para cima / para baixo)

Deve ser reproduzido um som de “beep” sempre que a bola colidir com a borda
ou com uma raquete.

A bola deve se mover automaticamente, alterando sua direção ao colidir com as bordas superior e inferior.




• Ao atingir as laterais esquerda ou direita, o ponto deve ser atribuído ao
adversário e a bola deve retornar ao centro.

A paleta é dividida em oito segmentos, com o segmento central retornando a bola em um ângulo de 90º em relação a paleta e os segmentos externos retornando a bola em ângulos cada vez menores.
A bola aumenta de velocidade cada vez que é rebatida, reiniciando a velocidade caso algum dos jogadores não acerte a bola. O objetivo é fazer mais pontos que seu oponente, fazendo com que o oponente não consiga retornar a bola para o outro lado.
