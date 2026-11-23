# Decoración modular de salas de Abismo

Importa [Kit_Decoracion_Salas_Ligero.rbxmx](Kit_Decoracion_Salas_Ligero.rbxmx) con **Insertar desde archivo** en Roblox Studio. El kit se abre como un catálogo de seis modelos independientes y editables. Cada modelo tiene su pivote en la base.

| Modelo | Ancho × alto × fondo (studs) | Partes | Colocación |
| --- | ---: | ---: | --- |
| `Contrafuerte_De_Mamparo` | 4,6 × 13,2 × 3,4 | 11 | Unión de pared y suelo. |
| `Colector_De_Refrigeracion` | 11 × 6,3 × 2,7 | 16 | Pared de sala técnica. |
| `Rejilla_De_Retorno` | 9 × 6,4 × 1,6 | 14 | Paño de pared cerrado. |
| `Alga_Cinta_De_Zocalo` | 4,8 × 5,0 × 2,9 | 16 | Al pie de un muro o bajo una tubería. |
| `Coral_Gorgonia_De_Grieta` | 5,3 × 5,9 × 1,1 | 12 | En una esquina, paralelo a la pared. |
| `Esponjas_De_Conducto` | 4,2 × 3,5 × 2,5 | 16 | Al pie de una rejilla o apoyadas en una repisa. |

En los tres módulos industriales, la cara de montaje está en `Z = 0` local y el volumen sobresale hacia `+Z`. En el contrafuerte, la zapata parte del suelo. Coloca las colonias con el pivote a ras de la superficie donde crecen.

Para una primera pasada, prueba **dos módulos industriales y dos colonias por sala**. Son hasta **64 partes adicionales por sala** y **192 en un nivel de tres salas**. En bombeo, combina colector, contrafuerte, algas y esponjas. En mantenimiento, usa contrafuerte, rejilla, gorgonia y esponjas.

Deja libres los huecos de **16 × 16 studs** de `Conexiones/Cara_*`, incluidos los de piso y techo. Comprueba que toda la silueta de cada modelo quede fuera del hueco y de la trayectoria inmediata de entrada. Mantén despejados los accesos a escondites.

Las **85 partes** del catálogo están ancladas y tienen desactivadas las colisiones, los contactos, las consultas espaciales y la proyección de sombras. El kit usa geometría y materiales de Studio y suma **0 luces, 0 partículas y 0 dependencias de assets remotos**. El presupuesto anterior es un conteo de instancias. El rendimiento del nivel completo se mide en Play tras colocar las piezas.
