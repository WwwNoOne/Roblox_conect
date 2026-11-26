# Niveles generados (Level_1 y Level_2)

Los dos niveles salen de un generador en Python ([tools/levelgen](../tools/levelgen)) que escribe `assets_build/exports/Level_N.rbxmx` y la planta `Level_N_Planta.png`. Rehechos el 26/11/2026 porque los mapas anteriores eran pequeños, con forma de cuadrado y salas abiertas.

```
python3 tools/levelgen/gen.py all                # los dos
python3 tools/levelgen/gen.py level1 --seed 31   # otra variante de la fábrica
```

La misma semilla da siempre el mismo mapa. Por defecto, Level_1 usa la semilla 27 y Level_2 la 5.

## Forma: raíz y grafo, dos plantas

El generador trabaja sobre una rejilla de celdas con dos plantas (`layout.py`):
- **Raíz.** La red crece desde el acople del ascensor con pasillos que se alargan, giran y echan ramas laterales. En los extremos aparecen salas (los nodos del grafo), y de ellas salen más pasillos.
- **Separación.** Un espacio nuevo nunca toca de lado a otro, así que entre dos pasillos siempre queda un muro y las uniones son explícitas.
- **Bucles.** Se abren atajos de una celda entre zonas que quedan cerca en línea recta pero lejos en el recorrido. Así el mapa es un grafo y no solo un árbol.
- **Verticalidad.**
  - Hay escaleras de subida y de bajada; cada rellano se ocupa y se une en cuanto se crea la escalera.
  - Las naves o grandes claros tienen doble altura, con una pasarela o puente colgante que las cruza y una escalera propia desde el suelo.
  - En el segundo piso hay pasillos, salas, pasarelas sobre pilotes y casas del árbol.
- **Validación.** Al generar se poda lo que no se alcanza desde el ascensor. Hoy el 100% de las celdas pisables es alcanzable y todas las escaleras tienen sus dos extremos unidos.

| | Level_1 · Complejo Fabril | Level_2 · Pantano de la Esclusa |
| --- | --- | --- |
| Tamaño | 840 × 840 studs (celda 10) | 864 × 864 studs (celda 12) |
| Piezas | ~11.200 | ~16.600 |
| Escaleras y naves | 17 escaleras, 3 naves con pasarela | 15 escaleras, 2 grandes claros con puente colgante |
| Escondites | taquillas (vestuarios, cuartuchos, pasillos) | arbustos (claros, senderos) y armarios (cabañas) |

## Estilo y ambiente

- **Plástico.** SmoothPlastic, colores planos y Neon en las luces.
  - En la fábrica, el zócalo de los muros lleva el color del **sector**, es decir, de la salida del vestíbulo por la que se llega. Sirve para orientarse.
  - El pantano usa elipsoides (SpecialMesh) para copas y arbustos, colinas de bola hundida (se pueden subir), cabañas con tejado a dos aguas y casas del árbol con el tronco atravesándolas.
- **Siempre de noche y con niebla.** Lo aplica `LevelAtmosphere.client` según el mapa cargado en `Workspace.Maps`, con los perfiles de `Config.LevelAtmosphere`. Al volver al lobby restaura la luz del lugar.
- **Luces.** Fluorescentes, faroles y bombillas. Una parte lleva la etiqueta `LamparaInstalacion` y `Parpadeo = true`, que hace parpadear `FacilityAmbience`, y otra parte está fundida. `LightCuller` apaga las lejanas.

## Trucos visuales 2.5D (límites y ahorro)

- **Pasillos falsos (fábrica).** Algunos fondos de saco terminan en una reja tras la que sigue un pasillo en perspectiva forzada: las paredes convergen hacia un punto de fuga a la altura de los ojos, así que 40 studs parecen mucho más. No tienen colisión ni se consultan.
- **Relieves en las naves.** La maquinaria de la parte alta de los muros son siluetas planas (depósitos y tubos de órgano).
- **Bosque infinito (pantano).**
  - Fuera del mapa hay tres anillos de árboles-silueta (tronco y dos discos cruzados), cada uno más oscuro y más grande.
  - En el interior del bosque hay relleno con el mismo tipo de silueta, y una luna plana.
  - Con la niebla no se ve el borde.
- **Maleza.** El muro del pantano es una barrera invisible con árboles y arbustos delante. Bajo el segundo piso la barrera solo llega a la altura de la pasarela, para no cerrar las escaleras.

## Escondites

- Cada volumen `Escondite` lleva dos atributos:
  - `Kind`: `Locker` o `Bush`.
  - `Label`: Taquilla, Armario o Arbusto. Es el texto del aviso.
- Al esconderse, `Hiding` orienta al jugador hacia fuera (el −Z del volumen) y pone el atributo `HiddenKind`.
- `HidingView.client` dibuja la vista desde dentro:
  - en una taquilla, las rendijas;
  - en un arbusto, hojas que se mecen.
- Los arbustos buenos tienen unas flores pálidas que los delatan a quien se fija.

## Contrato con el código

- Marcadores (los mismos de siempre):
  - `ElevatorDock` (PrimaryPart) y `Platform`;
  - `MachineSpawn`, 12 contra muros y repartidos;
  - `PuzzleSpawn`, en `Cofre##` y en `Puerta##` (con `Width` y `Height`);
  - `TreasureSpawn`, `CreatureSpawn` y `Patrol#` (cruces de pasillos y cinco por escalera);
  - `Escondite`;
  - `Bounds`.
- `MapNav` lee `NavFloors` ("0,14") y `NavSpacing` (la celda) del modelo o de `Bounds`. Rojo descarta los atributos del modelo raíz de un `.rbxmx`; por eso también van en `Bounds`.
  - Muestrea las dos plantas y prueba desplazamientos dentro de la celda si hay un mueble.
  - Une los vecinos con una rejilla hash, y la construcción tarda unos 0,2 s.
- En Play, la red sale del 95 al 100% conectada. Lo que queda aparte son las salas tras las persianas con puzzle cerradas.

## Importar en Studio

`.rbxmx` no pasa por Open Cloud. Hay dos caminos:
- Insertarlo desde el archivo y moverlo a `Workspace.Maps`.
- Dejarlo un momento en una carpeta que sirva Rojo y clonarlo desde Studio. **Ojo:** borrar con `rm -r` una carpeta vigilada tumba `rojo serve` (error en `change_processor.rs`). Hay que borrar solo el archivo.

Los mapas antiguos están en `ServerStorage.MapsBackup`. Los mapas son ediciones del lugar (no van por Rojo), así que **hay que guardar el lugar en Studio**.
