# Niveles generados (Level_1 a Level_6)

Los dos niveles salen de un generador en Python ([tools/levelgen](../tools/levelgen)) que escribe `assets_build/exports/Level_N.rbxmx` y la planta `Level_N_Planta.png`. Rehechos el 26/11/2026 porque los mapas anteriores eran pequeños, con forma de cuadrado y salas abiertas.

```
python3 tools/levelgen/gen.py all                # los seis
python3 tools/levelgen/gen.py arch               # solo hospital, escuela, mansión y centro comercial
python3 tools/levelgen/gen.py level1 --seed 31   # otra variante de la fábrica
```

Los mapas son **fijos**: la semilla está en el código y el resultado se guarda en Studio. La variedad entre partidas la dan los biomas
(un nivel distinto por etapa), y sobre un mapa fijo se pueden añadir detalles a mano más adelante.

## Recorrido de la partida (Config.Run.Stages)

| Etapa | Mapa | Bioma | Cuota |
| --- | --- | --- | ---: |
| 1 | Level_1 | Complejo Fabril | 400 |
| 2 | Level_2 | Pantano de la Esclusa | 200 |
| 3 | Level_3 | Hospital San Judas | 500 |
| 4 | Level_4 | Escuela | 600 |
| 5 | Level_5 | Mansión Valcárcel | 700 |
| 6 | Level_6 | Centro comercial (final, `BeaconSite`) | — |

Hay una Parada entre cada nivel. Las cuotas son valores de prueba (T08).

## Niveles de arquitectura (Level_3 a Level_6)

Estos cuatro no crecen en raíz: se dibujan en `tools/levelgen/<mapa>.py` con el marco `arch.py`. El marco hace lo siguiente:
- Define el `Plan` con áreas, uniones y cajas de escalera en zigzag de 2 × 5 celdas que suben cualquier número de plantas.
- Construye alas de edificio con `wing()`: pasillo, bandas de salas, escaleras en los extremos y azotea con pretil.
- Valida que todo se alcance desde el ascensor (si no, falla con el nombre del espacio).
- Genera la geometría para N plantas (sótano negativo y ático de techo bajo incluidos), las fachadas con ventanas, vallas, setos, tapias y pretiles.
- Pone los marcadores del manifiesto.

Los muebles nuevos están en `props.py`.

| | Hospital (L3) | Escuela (L4) | Mansión (L5) | Centro comercial (L6) |
| --- | --- | --- | --- | --- |
| Forma | 4 pabellones de 4 plantas + azotea alrededor del parque; pasarelas acristaladas en las esquinas | Edificio en L de 3 plantas + azotea; patio cerrado por tapia | 3 plantas + sótano + ático; jardín con tapia | Dos edificios unidos en H; aparcamientos a ambos lados del cuerpo central |
| Lugares | Urgencias, pabellones, quirófanos, UCI, morgue, psiquiatría (celdas), radiología, farmacia, capilla, cafetería; helipuerto | Aulas, biblioteca, laboratorio, informática, música, arte, comedor, cocina, gimnasio, dirección | Vestíbulo de doble altura con escalera imperial y galería, comedor, biblioteca, salón de baile, bodega, calderas, celda, desván | Atrio con pasarelas y escaleras mecánicas, tiendas, supermercado, patio de comidas, cine |
| Exterior | Parque de rehabilitación: paralelas, rampas, fuente, puestos y carritos de comida, picnic | Pista de baloncesto, columpios, tobogán, balancín, arenero, **autobús abandonado** | **Laberinto de setos** (con bucles y templete central), **piscina** entre setos, fuente, estatuas | Aparcamientos con plazas pintadas, coches y carritos |
| Escondites | taquillas, cubículos de baño, cámaras de la morgue, arbustos | taquillas de pasillo, cubículos, arbustos, el autobús | armarios, cubículos, arbustos del laberinto y la piscina | probadores, cubículos, taquillas, arbustos |
| Límite 2.5D | ciudad de siluetas con ventanas encendidas | casas y árboles-silueta | bosque-silueta y verja | ciudad y valla publicitaria luminosa |

Los suelos exteriores decorativos rodean el mapa sin cruzarlo, para no atravesar el sótano.

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

## Pendiente de retocar (revisión del 2026-11-26)

Medido en Studio con los 6 mapas importados. No bloquea la partida, pero hay que limpiarlo en el generador.

**Zonas sueltas en la red de las criaturas.** Puntos de la malla de `MapNav` que no conectan con el resto. Una criatura que aparezca o persiga hasta ahí normalmente usa PathfindingService, pero si este falla se queda sin ruta.

| Mapa | Puntos | Componente mayor | Sueltos | Construcción |
|---|---|---|---|---|
| Level_1 Fábrica | 2664 | 2664 | 0 | 0,22 s |
| Level_2 Pantano | 2150 | 1810 | **340** (1 aislado) | 0,17 s |
| Level_3 Hospital | 7950 | 7945 | 5 | 2,43 s |
| Level_4 Escuela | 4374 | 4374 | 0 | 0,87 s |
| Level_5 Mansión | 7134 | 7134 | 0 | 1,29 s |
| Level_6 Centro comercial | 9004 | 8972 | 32 (14 aislados) | 1,57 s |

- El Pantano es el caso grave. Probablemente sean las casas del árbol y los puentes colgantes, o sus escaleras, que no enlazan con la malla del suelo (diferencia de altura > 10 studs o el rayo de la planta no los toca). Revisar `NavFloors` y las uniones.
- Para medirlo: en Play (servidor), sacar cada mapa de `ServerStorage.MapStorage` a `Workspace.Maps`, `MapNav.Build(map)` y contar el componente conexo mayor de `nav.adj`.

**Piezas superpuestas.** Piezas visibles con la misma posición y tamaño que otra (doble geometría, parpadeo y piezas de más):

| Mapa | Visibles | Duplicadas | Ejemplos |
|---|---|---|---|
| Level_1 | 9730 | 0 | — |
| Level_2 | 14133 | **764** | `Casa_del_árbol_*.Alacena.Tarro`, `Vegetacion.Siluetas.Silueta` |
| Level_3 | 16909 | 0 | — |
| Level_4 | 8018 | 151 | `Limites.Silueta` |
| Level_5 | 5950 | 430 | `Estructura.Vanos.Barandilla.Poste` |
| Level_6 | 14175 | 14 | `Estructura.Vanos.Barandilla.Poste` |

- Los postes de barandilla salen repetidos donde se juntan dos tramos. Se arregla en `arch.py` deduplicando por posición al emitir.
- Solo se contaron duplicados exactos. Faltan los solapes parciales (suelos o muros que se pisan a medias y parpadean); hay que revisarlos a ojo o con `GetPartsInPart`.
- Las cajas de los mapas 3 a 6 se solapan entre sí en el lugar. En partida no importa, porque solo hay uno cargado a la vez, pero en el editor se ven mezclados.
