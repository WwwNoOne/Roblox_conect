# Medidas del kit gris modular

El archivo [Kit_Gris_Modular.rbxmx](../assets_build/exports/Kit_Gris_Modular.rbxmx) reúne siete modelos independientes hechos con piezas editables de Studio. Están separados al importarlos para que puedas duplicar, mover y rotar cada módulo. Las medidas son de prototipo y están en studs. Las huellas se expresan como ancho en X × fondo en Z.

## Medidas y conexiones

| Parámetro | Medida |
| --- | --- |
| Cuadrícula de planta | Celdas de 16 × 16. Usa incrementos de 1 stud para ajustar anclajes desplazados. |
| Piso terminado | Y local = 0 en la planta baja de cada módulo. |
| Altura interior horizontal | 12 desde el piso hasta la cara inferior del techo. |
| Espesor de piso, techo y muros | 1. |
| Abertura libre de puerta | 10 de ancho × 9 de alto. En piezas horizontales, el dintel ocupa los 3 studs superiores. |
| Ancho interior entre muros | 14 en pasillos de 16 y 30 en la sala de 32. |
| Desnivel estándar entre plantas | 16. |
| Rotación de módulos | Múltiplos de 90° alrededor de Y. |

Cada modelo tiene `Origin` como pivote y `PrimaryPart`. Los Attachments `Conexion_*` están dentro de `Origin`, en el centro del umbral, a nivel del piso y con el frente local `-Z` mirando hacia afuera. Norte equivale a `-Z`, sur a `+Z`, este a `+X` y oeste a `-X`.

Para unir dos módulos, haz coincidir la posición de sus Attachments, con los frentes opuestos y la vertical de ambos en `+Y`. En las piezas horizontales, los pisos se encuentran en la cara exterior del módulo. Una sala y un pasillo alineados quedan a 24 studs entre pivotes y dos pasillos a 16. Si se añade una puerta, su marco debe conservar el paso libre de 10 × 9 y tomar el Attachment como referencia de montaje.

## Piezas

| Modelo | Huella | Conexiones en coordenadas locales (X, Y, Z) |
| --- | --- | --- |
| `Sala_Vacia` | 32 × 32 | N `(0, 0, -16)`; S `(0, 0, 16)`. |
| `Pasillo_Recto` | 16 × 16 | N `(0, 0, -8)`; S `(0, 0, 8)`. |
| `Pasillo_L` | 16 × 16 | N `(0, 0, -8)`; E `(8, 0, 0)`. |
| `Pasillo_T` | 16 × 16 | N `(0, 0, -8)`; E `(8, 0, 0)`; O `(-8, 0, 0)`. |
| `Pasillo_Cruce` | 16 × 16 | N `(0, 0, -8)`; E `(8, 0, 0)`; S `(0, 0, 8)`; O `(-8, 0, 0)`. |
| `Escalera_Recta` | 10 × 32 | Baja S `(0, 0, 16)`; alta N `(0, 16, -16)`. |
| `Escalera_Espiral` | 32 × 32 | Baja O `(-16, 0, -11)`; alta O `(-16, 16, -11)`. |

El sufijo `W` identifica los conectores del oeste. Ambas escaleras tienen 10 studs de ancho y 24 peldaños de ⅔ de stud de alto. La **recta** tiene huellas de 1 stud y descansos de 4 studs de fondo. La **espiral cuadrada** rodea un hueco central de 12 × 12. Tiene cuatro tramos de seis peldaños, huellas de 2 studs, descansos de 10 × 10 y 15 studs libres entre los descansos superpuestos. Sus dos conexiones quedan desplazadas 11 studs respecto al centro de la cara oeste. Alinea esas conexiones por el Attachment.

Las escaleras se entregan abiertas. Reserva un tramo vertical libre y añade protecciones en bordes y huecos cuando cierres el diseño del mapa.

## Aplicación por bioma

| Nivel | Tema | Uso del kit |
| --- | --- | --- |
| 1 | Industrial | Distribución fija para el primer playtest. Las piezas sirven para armar corredores y salas cerradas. |
| 2 | Pantano | Mapa abierto con rutas reconocibles. La niebla, el relieve y las siluetas lejanas pueden ocultar el límite visual. Límites físicos, como taludes o vegetación densa con colisión, mantienen a los jugadores en el área transitable. La máquina puede ir en un refugio o sobre una plataforma accesible. |
| 3 | Cueva | Los corredores pueden tomar forma de túnel y las salas de cámara natural. Mantén los 10 × 9 studs libres donde conecten piezas y deja la roca decorativa fuera del recorrido. |

Todos los mapas tendrán **tesoros, casilleros para esconderse y una máquina interactiva reparable**. La propuesta para el prototipo es conservar fija la posición de la máquina y diseñar su sala como un módulo propio. Su geometría, entrada y espacio de interacción quedan definidos a mano. El resto de las salas puede variar con juegos de decoración por bioma. Los tesoros y casilleros pueden ocupar anclajes revisados previamente, con espacio para acercarse e interactuar. Los anclajes de tesoro y máquina seguirán `TreasureSpawn` y `MachineSpawn` del [manifiesto](../creation_models.md). El contrato del casillero queda pendiente de definir con Claude.

## Prueba en una base vacía de Studio

1. Importa el kit y duplica `Sala_Vacia` y `Pasillo_Recto`. En el mismo eje y con Y = 0, coloca el pasillo a 24 studs de la sala y enfrenta ambos umbrales.
2. Conecta `Pasillo_L`, `Pasillo_T` y `Pasillo_Cruce` en distintos giros de 90°. Recorre los umbrales en ambos sentidos y prueba el cruce simultáneo de dos avatares.
3. Conecta un pasillo a cada extremo de ambas escaleras. La planta alta va a Y = 16. Sube y baja caminando y corriendo, gira en los descansos de la espiral y verifica el paso con la cámara en primera y tercera persona.
