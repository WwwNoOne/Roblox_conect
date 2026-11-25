# Generación de niveles: cuevas submarinas por salas

> Diseño acordado (2026-11-14/15). **Sustituye** a los niveles fijos Level_1/2/3 y a las paradas (guías antiguas en `archive/levels_fijos_2026-11-11/`).
> Estado de implementación y tareas pendientes: [`../ESTADO.md`](../ESTADO.md). Criaturas: [`Criaturas.md`](Criaturas.md).

## 0. Giro de diseño (2026-11-15): de mapa masivo a **laberinto frenético**
> Decidido tras probar la generación: a la escala actual el mapa se siente enorme y vacío. **Pasa a ser un laberinto estrecho con un enemigo agresivo y ritmo rápido.** Lo de abajo (secciones 1-8) describe la primera versión (grafo de salas grandes unidas por pasillos largos); lo que contradiga esta sección queda **superado**. Se aprovechan sin cambios: sala_0 + submarino fijo y seco, semilla, agua por `FillBlock`, estándar `Conexiones/Cara_*`, escala por `Config.Level.Scale`, `LevelService` y la pantalla de carga.

**Decisiones**
1. **Salas medianas de 90-120 studs** (caja exterior) en vez de 160-290; la sala grande deja de ser un espacio enorme (decidir si se mantiene como arena del jefe o desaparece).
2. **Salas y pasillos más estrechos**. El ancho de pasillo (hoy 36 × 36 a escala 0,6) se fija al modelarlo; la puerta de la sala debe coincidir con el pasillo.
3. **Pasillos con distintas formas** (piezas modulares): **lineal**, **codo** (giro de 90°), **T** (3 salidas) y **cuádruple / cruce** (4 salidas). Se modelan a mano y el generador las ensambla.
4. **Zonas para esconderse** (nichos, alcobas, huecos tras estructuras) en salas y pasillos.
5. **Movimiento más rápido** (velocidad de nado/dash por encima de los 20 studs/s actuales; calibrar en pruebas).
6. **Enemigo agresivo** que caza de forma constante por todo el laberinto (no queda confinado a una sala). Jugabilidad más **frenética**: huir, esconderse y rodear al enemigo en lugar de explorar con calma.
7. **El usuario modela** los pasillos (4 formas), el nuevo enemigo y una sala; luego se prueba este gameplay.

**Consecuencias para el generador (propuesta, por implementar)**
- Los **pasillos pasan a ser piezas con 2-4 puertos** (todas, salas y pasillos, con el mismo estándar `Conexiones/Cara_*`), no un único tubo recto entre dos salas. El grafo se construye con piezas (sala o tramo) unidas puerto con puerto, sin hueco intermedio, o con tramos lineales de longitud fija.
- Conviene una **rejilla modular** (tamaño de celda = largo del tramo lineal; sala = n × n celdas) para que los puertos de piezas distintas alineen y puedan cerrarse **bucles** (hoy el generador solo hace árbol).
- Regla anti-callejón: poca presencia de puntos muertos; los puertos sin usar se tapan.
- Marcadores nuevos: `Escondite` (volumen donde el jugador queda oculto) además de los existentes.

**Consecuencias para el enemigo**
- Navegación por el **grafo de piezas** (BFS entre piezas y waypoints en los puertos), mejor que esquivar a ciegas con raycasts en pasillos estrechos.
- Detección: vista/luz/ruido; el jugador **escondido** no es visible salvo muy cerca; la lámpara encendida delata. Persecución constante con breves pausas, más rápido que el nado normal pero alcanzable con dash.
- Mecánica del agarre/muerte a definir con el nuevo modelo (el kraken actual puede quedar como jefe o descartarse).

**Piezas de pasillo modeladas (2026-11-15)** — `Workspace.Pasillo.Pasillos`: `Pasillo_Lineal` (90 partes, 3 luces, 20 × 20 × 48), `Pasillo_L` (codo, 100, 3), `Pasillo_T` (130, 4), `Pasillo_Cruz_4` (170, 5). Sección **20 × 20 por fuera, 16 × 16 por dentro** (paredes de 2); el pivote está en el cruce y todas las ramas miden **24** desde el pivote (extremos abiertos a media altura, y = 8). Cada pieza lleva `Estructura`, `Tuberias_Y_Musgo` y una **`Caja_Industrial_Rectangular`** (escondite). Se les añadió una carpeta `Conexiones` (marcas `Cara_Este/Oeste/Sur/Norte` en cada extremo abierto) y `Escondites` con un volumen `Escondite` (atributo `Kind = "CajaIndustrial"`) alrededor de cada caja. Pegado a la pared de 2 de grosor el agua no se puede contener: el laberinto va **sumergido entero** (un solo `FillBlock` hasta la altura del pozo).

**Generador de laberinto** (`MazeGenerator.luau`, modo `Config.Level.Mode = "maze"`, parámetros `Config.Maze`):
- Pieza = Model con `Conexiones`; todas se unen puerto con puerto (sin hueco) y misma sección. `Plan(semilla)` es determinista y reintenta con semillas derivadas si se bloquea; `Validate` comprueba solapes, alcanzabilidad y racha de lineales.
- **El pasillo lineal se puede encadenar una vez** (máx. 2 seguidos, `Config.Maze.MaxLinearRun`). La primera pieza bajo el pozo nunca es lineal (quedaría vertical y sin salida).
- Si dos extremos libres coinciden enfrentados se **cierra un bucle** (0,6 por nivel de media); los extremos libres se tapan con un tapón de 20 × 20.
- El pozo de 40 × 40 de la sala_0 se une con la primera pieza mediante un **marco** de 4 barras con hueco de 16 × 16.
- Pruebas: 300 semillas, 0 problemas, 28 piezas siempre, racha lineal máxima 2, lado mayor medio ≈ 430 studs (el laberinto es plano: ~34-48 de alto). Una partida real (Play) genera 28 piezas en 0,1 s, unas 3200 partes, y el agua queda en el laberinto y en el pozo (la sala_0 y el submarino, secos).
- Limitaciones: solo piezas horizontales (pasillo plano; no hay piezas verticales); las salas aún no se integran (la sala existente tiene puertas de 36 ≠ 20; hay que modelar la sala con **hueco de puerta de 16 × 16** (el interior libre del pasillo; el pasillo mide 20 × 20 por fuera con sus paredes de 2, que quedan apoyadas contra la pared de la sala) y `Conexiones` en el plano exterior de la pared).

**Pozos verticales y sala integrados (2026-11-15)** — `Workspace.Pasillo.Pasillos_V` (`Pozo_Recto_48`, `Pozo_L`, `Pozo_T`, `Pozo_Cruz_4`: mismas piezas en el plano X-Y, 20 × 20 de sección, ramas de 24 desde el pivote; sin caja industrial) y `Workspace.Salas.Estructura_1` (sala de **100 × 60 × 90**, 305 partes, 13 luces, 6 huecos de **16 × 16** verificados, pivote a ras de suelo, puertas a media altura y), ambas con `Conexiones`. El generador (`Config.Maze.Pieces`) las mezcla: un pozo/sala bajo la sala_0, **máx. 5 pozos verticales** y **2 salas** por nivel, y los tramos rectos (lineal o pozo recto) siguen limitados a 2 seguidos. Prueba con 300 semillas: 0 problemas, 28 piezas siempre, ~4,9 pozos y ~1,7 salas por nivel, altura de hasta ~312 studs. Las plantillas (`Pasillo`, `Salas`, `Creatures`) salen del mundo a `ServerStorage.Plantillas` al arrancar.

**Enemigo: Pez Pelícano Abisal (hecho 2026-11-15)** — `MonsterService.server.luau` + `Config.Monster`. Modelo `Workspace.Creatures.Pez_Pelicano_Abisal` (rig de 11 Motor6D, 586 partes soldadas, 9,7 × 5,7 × 35,2 escalado a 24 de largo; animaciones en `AnimSaves`: Patrullaje, Nado_Horizontal, Nado_Vertical_Ascenso/Descenso, Ataque_Horizontal/Ascenso/Descenso). **Patrulla** siguiendo la red de pasillos (`MazeGenerator.NavGraph`, un vértice por centro de pieza y por puerto; Dijkstra) a 10 studs/s; **al detectarte corre hacia ti a 24 studs/s** (más rápido que el nado de 20). Detección: vista con línea de visión hasta 80 (×1,5 con lámpara), oído a 14, y **escondido solo a ≤ 5**; ignora a quien está en el submarino o fuera del laberinto. Muerde a ≤ 8 (50 de daño, 2 s de enfriamiento, animación de ataque según la altura relativa); si pierde de vista 4 s busca el último punto y vuelve a patrullar. Aparece 15 s tras entrar al nivel, a ≥ 90 del pozo. Probado en Play: patrulla a 9,8 studs/s, pasa a «Chase» en < 0,25 s al verte a 36 studs, muerde (200 → 150 → 112), y un jugador escondido a 30 studs con línea de visión es ignorado hasta que está a < 5. **Limitaciones:** movimiento cinemático sin colisión (el cuerpo rígido de 24 corta las esquinas del pasillo), las animaciones solo se registran en Studio (hay que publicarlas), un único enemigo.

**Esconderse (hecho 2026-11-15)** — `Hiding.luau` + `HidingHandlers.server.luau`, parámetros en `Config.Hiding`. Cada volumen `Escondite` (caja industrial) lleva un `ProximityPrompt` («Esconderse / Salir», tecla **E**, mantener 0,4 s, a ≤ 7 studs). Pulsar E te mete en la caja: quedas **anclado en el centro de la caja e invisible** y el jugador tiene el atributo `Hidden = true`; pulsar E otra vez te devuelve a donde entraste. Kraken, mandíbula y cangrejo ignoran a los jugadores con `Hidden`. Se suelta a todos al terminar la partida o cambiar de etapa y al morir. El oxígeno sigue bajando (no se puede esconder uno para siempre). Probado en Play con el jugador (28 prompts, Hide/Release correctos); **no probado**: pulsar E con teclado real, la cámara dentro de la caja y con 2 clientes. Pendiente para el enemigo nuevo: «salvo muy cerca» (detección a corta distancia) y que la lámpara encendida delate.

**Presupuesto de piezas (laberinto)** — un nivel tendrá unas 10 salas y 30-40 tramos de pasillo, así que el pasillo manda:
| Pieza | Partes (máx.) | Con colisión (máx.) | Luces |
| :-- | :-- | :-- | :-- |
| Pasillo lineal | 80 | 10 | 0-1 |
| Codo | 120 | 14 | 1 |
| T | 150 | 18 | 1 |
| Cuádruple (cruce) | 180 | 22 | 1 |
| Sala mediana (90-120) | 800-1000 | 300 | 12-16 |
- Techo por nivel: **~14 000 partes** y **~200 luces** (el pasillo anterior tenía 446 partes: 68 + 378 de tuberías, de las cuales ya fusionadas con `UnionAsync`).
- Paredes: **≥ 6 studs** de grosor (a escala 1) en toda pieza que contenga agua. Decoración sin colisión (`CanCollide`/`CanQuery`/`CanTouch` apagados); fusionar con uniones o usar mallas repetidas.

**Pendiente de decidir al modelar:** ancho exacto del pasillo, tamaño final de salas (90-120), tamaño y velocidad del enemigo, cuántos escondites por sala, y si se mantiene una sala de jefe.

## 1. Idea (primera versión)
Modo infinito: cada nivel es una cueva submarina distinta, **ensamblada con salas prefabricadas** unidas por **pasillos fijos**. El equipo baja nivel tras nivel; gana quien llega más profundo (profundidad = puntuación, con ranking). No se generan formas: se ensamblan piezas modeladas a mano, y el azar solo decide cuáles, dónde y con qué rotación.

## 2. Estructura de un nivel
- **11 salas**: 1 grande (central, con el jefe) + 10 pequeñas, más la **sala_0** fija (donde está el submarino) arriba del todo.
- Forma de **grafo de nodos** (no un cubo), colocado sobre una **rejilla 3D**: cada sala nueva se pega a una puerta libre de una ya colocada, en una de las 6 direcciones, con un pasillo recto de longitud fija. En una rejilla no puede haber solapes; se descarta cualquier posición ocupada.
- **Construcción por árbol** (conectividad garantizada, sin generar y descartar):
  1. Sala_0 arriba; su único pasillo baja (vertical) a la **sala grande**.
  2. La grande abre **3-4 puertas** y cuelga salas pequeñas (regla: ≥ 3 salas conectadas a la grande).
  3. Se siguen añadiendo salas pequeñas a puertas libres hasta tener 10.
  4. Se añaden **1-2 pasillos extra** entre salas vecinas (bucles; evita callejones obligados).
  5. Se eligen biomas, variantes, rotaciones, jefe y marcadores con la **semilla** (la genera el servidor; todos los jugadores ven el mismo mapa).
- **Ninguna sala por encima de la sala_0.** Pasillos verticales: máximo 1-2 por nivel además del de la sala_0 (la decoración de suelo del pasillo —esqueletos— no sirve girada: usar una variante sin decoración de suelo).
- El nivel completo debe quedar por debajo de la mitad del antiguo Nivel 2 (481 × 659 × 481).

## 3. Reglas del generador
1. Toda sala tiene ≥ 1 salida en una cara interior (se cumple por construcción).
2. ≥ 3 salas conectan directamente con la grande.
3. Todas las salas son alcanzables desde el submarino.
4. ≥ 3 biomas distintos por nivel; no el mismo bioma/variante en dos salas contiguas (y, si se puede, sin repetir variante dentro de un nivel).
5. Las salas se pueden rotar 0°/90°/180°/270° sobre el eje vertical (las 4 puertas laterales son equivalentes); la sala_0 no se rota.

## 4. Estándar de sala (lo que necesita el generador)
Cada sala es un `Model` con **pivote en el centro de su caja** y:
1. **Cáscara cerrada** de **8 studs** de grosor, con colisión y sin fugas, con **un agujero de 60 × 60 centrado en cada una de las 6 caras** (paredes a mitad de altura).
2. **`Conexiones`** (Folder) con 6 Parts invisibles de 0,2: `Cara_Norte` (−Z), `Cara_Sur` (+Z), `Cara_Oeste` (−X), `Cara_Este` (+X), `Cara_Piso` (−Y), `Cara_Techo` (+Y), en el centro de cada puerta **a mitad del grosor de la pared**. (Convención de la sala pequeña `Sala_De_Bombeo_160`, que es la que usa el generador; el pasillo usa `Port_A` (+Z) y `Port_B` (−Z) en sus extremos.) El generador **deduce el centro de la sala** como la media de las 6 marcas, así que el pivote del modelo puede estar en cualquier sitio (aunque con rotación identidad).
3. **`Bounds`**: Part con el volumen interior libre (relleno de agua con `Terrain:FillBlock`; límite de las criaturas).
4. **Tapón**: un prefab `Tapon` común (roca 60 × 60 × 8) que el generador clona en cada puerta no usada.
5. **Marcadores**: `TreasureSpawn` (Attachment), `CrabPlatform` (Part plano ~19 × 20 sobre suelo), `CreatureSpawn` (Attachment con atributo `Kind`); en la grande, `BossSpawn`.
6. **`BiomeZone`** (Part con atributo `Biome`) para niebla/luz del cliente; `HazardZone`/`DarkZone` opcionales (atributo del peligro).
7. **Presupuesto**: pequeña < 1500 partes y < 40 luces; grande < 2500 y < 60. Decoración sin colisión (`CanCollide`/`CanQuery`/`CanTouch` apagados).
8. **Pasillo**: necesita además un `Bounds` de 60 × 60 × 140 (agua).

**Las puertas están a mitad de altura**, así que el agua de toda sala (menos la sala_0) debe llegar por encima del borde alto de la puerta; en la práctica, las salas van totalmente inundadas.

## 5. Piezas modeladas (en Studio, no versionadas)

### 5.1 Pasillo — `Workspace.Pasillo.Pasillo`
> **2026-11-15:** las 4 paredes del tubo eran planos de **1 stud**; el agua del terreno (vóxeles de 4) se salía por fuera y se veía como burbujas azules alrededor de los pasillos. Ahora tienen **7 de grosor** (caras interiores sin cambiar: sigue libre 60 × 60; esquinas cubiertas). Respaldo del pasillo antiguo en `ServerStorage.Pasillo_respaldo_paredes_finas`. **Regla general: toda pared que contenga agua debe tener ≥ 6 studs.** Además lleva `Tuberias_pasillo` (378 partes).
Módulo recto de **140 studs** (eje Z; pivote en el centro `(701, 31, 243)`), sección libre **≈ 60 × 60**, **ambos extremos abiertos**, 68 partes con colisión, con decoración (coral, esponjas, esqueletos, jaula de huesos). `Port_A` en `(701, 31, 313)` (mira +Z) y `Port_B` en `(701, 31, 173)` (mira −Z), de 60 × 60 × 1. Para uso vertical se gira 90° sobre X. Distancia entre centros de dos salas contiguas = mitad de cada sala en ese eje + 140.

### 5.2 Sala_0 — `Workspace.Sala_0`
Sala fija con el submarino (**siempre arriba**; la salida **siempre abajo**). Caja 82 × 41 × 108 (x 526…607, y 8…49, z −41…67). Suelo seco a y≈14 con un **pozo de 40 × 40** en `(563, 13, 38)` (x 544…583, z 18…57) por el que se baja; el agua solo existe del pozo hacia abajo, con la superficie al nivel del suelo. `SubDock` (Part invisible) en `(561, 22, −36)`, orientación 0° (**escotilla hacia +Z**): es el pivote exacto del submarino. Submarino de referencia: 26,6 × 15,4 × 36,9; `InteriorZone` 22,35 × 12 × 29,1.
Detalles por revisar: el hueco del muro en z=−23 mide ~23,2 de ancho frente a 26,6 del submarino (el casco solapa 1-2 studs); la proa sobresale ~11 studs por detrás de la caja; el suelo interior del submarino queda ~3,5 sobre el suelo de la sala. El pasillo (60 × 60) se une bajo el pozo (40 × 40): el suelo alrededor del hueco debe cubrir 60 × 60 (hoy faltan ~3 studs por el lado +Z).

### 5.3 Sala grande del kraken — `Workspace.Salas_grandes.Kraken_map` (Folder → Model)
- **Cáscara `Sala_kraken`**: 6 caras (`Techo`, `Suelo`, `Pared_X±`, `Pared_Z±`), cada una de **4 bloques** `CeramicTiles` de 8 de grosor alrededor de un **agujero de 60 × 60 verificado** con rayos. Caja exterior **286 × 288 × 280** (puerta a puerta: X 278, Y 280, Z 272), centro ≈ `(266, 280, −416)`. Centros de las puertas: X± `(127|405, 276, −416)`, Z± `(268, 276, −280|−552)`, Y± `(268, 140|420, −416)`. Respaldo de las losas originales (sin agujeros): `ServerStorage.Sala_kraken_original_respaldo`.
- **Tuberías (`Krakem tuberias`)**: 6 paredes × 21 módulos del kit (codo, T, tramos, válvula, remate) = 24 864 partes (el nivel suma 29 235). **Optimización probada** con `UnionAsync` (conductos y musgo de cada módulo → 1 unión cada uno): **378 partes**; copia en `ServerStorage.Krakem_tuberias_optimizado`, aún sin sustituir. Dejan libre un hueco de ~88 × 88 junto a cada puerta; restan 27 studs de grosor útil por lado.
- **Naufragio** (167 × 137 × 184, 3063 partes) en `(271, 247, −417)`; su isla queda ~34 studs sobre el suelo, encima de la puerta de abajo (quien entre por el suelo sale justo debajo de la isla). ~100 studs libres sobre él.
- 30 luces. Faltan: `Port_*`, `Bounds`, `Tapon`, marcadores, `BossSpawn` y poner el pivote del modelo en el centro. El kit de tuberías suelto está dentro del modelo cerca del origen y falsea su `BoundingBox`: moverlo fuera.
- `Salas_grandes.Plantilla_Sala_grande`: plantilla de 6 losas de 280 × 8 × 280 **sin agujeros** (replicar la técnica de 4 bloques de `Sala_kraken` para las otras 3 salas de jefe).
- Nota técnica: una `UnionOperation` con agujero necesita `CollisionFidelity = PreciseConvexDecomposition`; con `Default` la colisión puede cerrar el hueco aunque se vea abierto (y la propiedad no se puede cambiar por script una vez creada la unión: hay que recrearla con `SubtractAsync(partes, Enum.CollisionFidelity.PreciseConvexDecomposition)`). `Sala_kraken_nueva` (6 uniones del usuario) ya está reconstruida así; respaldo en `ServerStorage.Sala_kraken_nueva_respaldo`.

### 5.4 Salas pequeñas
- **`Workspace.Salas_normales.Sala_De_Bombeo_160`** (primera): caja exterior **174³** (interior libre **160³**, paredes de 7), cáscara `Cubo_Estructural` (6 caras de 24 piezas, **6 agujeros de 60 × 60 centrados verificados**), `Conexiones` con las 6 marcas, **990 partes** (391 con colisión) y **16 luces**; pivote a ras de suelo (el generador lo compensa). Presupuesto cumplido.
- **Estándar**: cubo con interior de 160 (exterior 174). Puertas de 60 × 60 en el centro de cada cara. Paso entre centros de dos salas pequeñas = 174 + 140 = **314 en los tres ejes**. Solo se rotan sobre el eje vertical (0°/90°/180°/270°).
- Si el nivel resulta demasiado largo, acortar el pasillo (140 → ~100) reduce más que bajar el tamaño de las salas.

### 5.5 Generador (`src/ServerScriptService/Services/RoomGenerator.luau`)
Primera versión hecha y **probada en Studio (modo Edit)** con la sala_0, el pasillo, la sala grande (con `Conexiones` añadidas y pivote en el centro) y la sala pequeña (reutilizada 10 veces con rotaciones):
- `ReadDef(model, kind, wall, water)`: lee las marcas y calcula centro, caja y puertos.
- `Plan(seed, defs, origin, options)`: grafo sin solapes (comprobación por cajas), sala_0 → grande por el pozo, las 3 primeras pequeñas pegadas a la grande, resto al azar, nada por encima de la sala_0, máx. 2 pasillos verticales extra. **Aún no añade bucles extra ni exige 3 biomas** (solo hay una sala pequeña).
- `Validate(plan)`: solapes y alcanzabilidad. `Build(plan, templates, container, withWater)`: clona salas y pasillos alineados por marcas (desviación medida 0,00 studs), pone tapones provisionales (Part de 70 × 70) en puertas sin usar y rellena de agua salas y pasillos con `Terrain:FillBlock`.
- Prueba con semilla 12345: 10 salas pequeñas colocadas, 11 pasillos, 45 tapones, **0 problemas**, agua correcta (pozo y salas con agua; sala_0 y submarino en aire). **Extensión del nivel ≈ 899 × 768 × 894 studs y ~17 900 partes** (sin optimizar la sala grande, ver 5.3).
- **Escala (2026-11-15):** la prueba de juego mostró que los tamaños modelados eran demasiado grandes (la sala pequeña actual se sentía como la grande). `Config.Level.Scale = 0.6` se aplica **al instanciar** (las plantillas no cambian): sala grande ≈ 172 de caja (interior ≈ 162), sala pequeña ≈ 104 (interior 96), puertas y pasillo de **36 × 36**, pasillo de 84 de largo, kraken de 42 de alto. Nivel de ejemplo ≈ 724 × 475 × 720 studs. Cuando se modelen salas al tamaño definitivo, poner `Scale = 1` (o ajustar). Regla de agua: con escala 0,6 las paredes pasan a ~4,2 (hay que vigilar fugas; probado sin fugas a 24 del eje).
- **Aislamiento:** al arrancar, `LevelService` aparta a `ServerStorage.Plantillas` lo listado en `Config.Level.Stash` (`Assets`, `Zona_Prueba`, `LeadPipes`) para que no se cargue ni interfiera (la losa de `Zona_Prueba`, a y=0,5, cortaba el primer pasillo vertical).
- **En partida:** `LevelService.server.luau` genera el nivel **al arrancar el servidor** (semilla aleatoria, `Config.Level`; queda en el atributo `Workspace.LevelSeed`), mueve las plantillas (`Salas_grandes`, `Salas_normales`, `Pasillo`) a `ServerStorage.Plantillas`, deja el resultado en `Workspace.NivelGenerado` y pone `Workspace.WorldReady = true`. La **pantalla de carga** (`ReplicatedFirst/LoadingScreen`) espera a ese atributo ("Generando el mundo..."; tope `Config.Loading.MaxSeconds` = 90 s). Cada sala generada lleva su `Bounds` (volumen interior).
- **Kraken:** `KrakenService` ya no usa las etapas fijas: al entrar en el estado `Level` busca `NivelGenerado.big_<n>` y ronda **solo dentro de su `Bounds`** (aparece en el centro tras `FirstDelay`).
- El generador acepta **varias variantes de sala pequeña** (todas las `Model` de `Workspace.Salas_normales`); elige una al azar por sala y evita repetir la del padre.
- Para probarlo: `require` de una **copia** del ModuleScript (la caché de `require` no ve los cambios), plantillas en `ServerStorage.Plantilla_big_prueba` y resultado en `Workspace.NivelGenerado` (+ `Terrain:Clear()` antes de repetir).

## 6. Contenido: salas fijas
**4 biomas × 3 variantes = 12 salas pequeñas**, modeladas a mano con toda su decoración; el generador las elige y rota. **4 jefes → 4 salas grandes** (misma cáscara, interior distinto); empezar con el kraken. Total a largo plazo: 12 + 4 + sala_0 + pasillo. **Orden para probar el generador**: sala_0, pasillo, sala grande del kraken y 1 bioma × 2 variantes.
La variedad viene de: qué salas salen, la ramificación, la rotación, los marcadores usados y el jefe. Mejora futura opcional: dispersión de decoración por `DecoSlot` en el cliente.

### Estética (directrices)
- Que un cubo parezca cueva: capa de roca por dentro (kit de roca: pared, cuña de esquina, estalactitas, **marco de puerta**), esquinas y aristas rellenas, niebla/oscuridad de ayuda. `Workspace.Kit_Rocas_De_Pared_Con_Algas` (1510 partes) es el punto de partida.
- Anti-saturación: 3 niveles por sala (1 pieza hero, pocos grupos medianos, detalle pequeño disperso), carriles de nado libres, paleta limitada por bioma (2 dominantes + 1 de acento).
- **Biomas** (propuesta): cueva natural de coral y roca; instalación industrial inundada (tuberías y azulejos tipo poolroom; aquí el cubo está justificado); cementerio de naufragios y huesos; bioluminiscente (hongos y medusas). Cada bioma con una **mecánica sencilla** (zonas oscuras, veneno, corrientes, baja visibilidad), 70 % de su estilo y 30 % de otro.

## 7. Submarino y progresión
- El submarino está **fijo y seco** en la sala_0 (se acabaron `carveCabin`, `restoreWater` y el viaje del submarino). Al empezar la partida se coloca en `Sala_0.SubDock`.
- Cada nivel mantiene la cuota de tesoros; al cumplirla (o derrotar al jefe) se regenera el mapa con semilla nueva y más dificultad.
- Oxígeno: se gasta en agua y se recarga en seco (`DryZone` / `InteriorZone`). Las criaturas tratan `DryZone` como zona segura y no entran a la sala_0.

## 8. Cambios de código previstos
- `Runs`: sin `carveCabin`/`restoreWater`/`moveSubTo`; colocar el submarino una vez; sustituir `Config.Run.Stages` por niveles generados. (`dockOf` ya usa `Sala_0.SubDock` como respaldo.)
- `OxygenService`: consumo por estar en agua + `DryZone`.
- `KrakenService`, `MandibulaService`, `CrabService`: `Bounds` de salas activas en vez del de un nivel; kraken solo en la sala grande; mandíbulas y cangrejos desde los marcadores de cada sala; `DryZone` como zona segura.
- Nuevo `RoomGenerator` (grafo, semilla, rotaciones, alineación de puertos, tapones, agua por `FillBlock`) y un servicio de agua/pasillos.
