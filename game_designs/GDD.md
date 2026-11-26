# GDD — Backrooms Coop (título provisional)

> **Cambio de dirección (2026-11-25):** la temática deja de ser submarina/oceánica y pasa a **espacios liminales tipo Backrooms**, con distintas ambientaciones por nivel. Se elimina todo lo relacionado con el océano (agua, presión, oxígeno, profundidad, fauna marina). El diseño anterior está archivado en [`docs/archivo_oceano/`](../docs/archivo_oceano/) y **no es vigente**.
>
> **Fusión (2026-11-25):** este documento unifica el GDD anterior con el "Documento de Diseño: Exploración Liminal en Ascensor". Es la única versión vigente.
>
> Las secciones marcadas **[POR DEFINIR]** se detallarán más adelante. No implementarlas hasta que se definan.

## 1. Concepto
De **1 a 5 jugadores** (solitario y cooperativo) descienden por biomas liminales (oficinas vacías, fábricas, almacenes, pantanos, piscinas sin agua, etc.) usando un **Ascensor** que es la **única zona segura** y el centro de operaciones. Buscan tesoros, reparan máquinas y resuelven puzzles mientras criaturas tipo nextbot los persiguen. Terror, suspenso y extracción, con ritmo frenético.

## 2. Game Loop
1. **Lobby:** un jugador (host) crea una sala; los demás entran por código o invitación (hasta 5). El host inicia.
2. **Traslado:** el equipo aparece dentro del **Ascensor**, una cabina sellada transitable. Al cerrar la puerta hay crujidos/vibración, fundido a negro y el servidor lo lleva al `ElevatorDock` del siguiente nivel.
3. **Preparación en el Ascensor:** se revelan las condiciones del piso (cuota de tesoros, mutador de bioma, estado de sistemas). El jugador puede consultar radar y cámaras (ver §6).
4. **Exploración y riesgo:** el equipo sale, recorre el mapa, busca tesoros y completa objetivos (generadores, terminales, cajas fuertes, puzzles) mientras evita amenazas.
5. **Extracción por viajes:** los tesoros se depositan en el Ascensor hasta alcanzar la **cuota** del piso.
6. **Desbloqueo:** al completar los objetivos clave (reparar generadores, hackear terminales) se habilita el descenso.
7. **Clímax y escape:** al cumplirse cuota y objetivos aumenta la peligrosidad del bioma (luces de alerta, enemigos en búsqueda activa). Todos deben regresar al Ascensor y **cerrar las puertas** para bajar.
8. **Parada (tienda):** entre niveles hay un **mapa de tienda** seguro (`Parada`) donde se venden tesoros y se compra equipo con el fondo común.
9. **Final:** victoria al completar el último nivel (cuota + objetivos clave + descenso final). **[POR DEFINIR]** número de niveles. Derrota: todos los jugadores muertos o el tiempo del nivel agotado sin cumplir lo exigido.

Secuencia de prueba: `Level_1 → Parada → Level_2 → Parada → Level_3`.

## 3. Mecánicas

### Movimiento y cámara
* PC: `WASD` mover, `Shift` **correr** (con estamina), `Espacio` saltar, `E` interactuar, `F` linterna. Mobile: joystick táctil + botones.
* **Primera persona fija:** sin zoom, cuerpo visible (brazos, manos, torso, piernas) pero sin cabeza; puntito central; el cursor se libera solo en menús (tienda, panel del Ascensor) o con `Alt` izquierdo.
* **Sprint con estamina:** mantener `Shift`; la estamina se gasta al correr y se recupera tras una pausa; al vaciarse queda agotado hasta recuperar un mínimo. **Correr hace ruido** y atrae enemigos. Cargar tesoros pesados reduce ligeramente la velocidad de carrera u ocupa las manos: hay que decidir si soltar el botín para huir.
* **Linterna** (`F`): única luz del jugador; influye en la detección por las criaturas.
* **Eliminado:** nadar, oxígeno, agua de Terrain, flotación, niebla por profundidad, dash.

### Temporizador
* **5 minutos por nivel** (`Config.Run.LevelSeconds = 300`), con avisos a 2 min, 1 min, 30 s y 10 s. Reloj arriba al centro (ámbar < 2 min, rojo < 1 min).
* **[POR DEFINIR]** qué pasa al agotarse (hipótesis: el Ascensor parte solo; sin cuota u objetivos cumplidos, derrota) y su interacción con el clímax.

### Ascensor
* Cabina transitable compartida: puerta, estación de depósito/venta, indicador de estado y **Estación de Control** (§6). Se conserva el modelo `submarine_A01_v2` renombrado a **Ascensor** (ver `creation_models.md`).
* **Indicador del Ascensor:** rombo con la distancia sobre el Ascensor o flecha al borde de la pantalla si está fuera de vista; se oculta cuando se está cerca. Solo en niveles.
* **Eliminado:** casco compartido, presión, implosión. **[POR DEFINIR]** si el Ascensor tiene algún valor compartido nuevo (p. ej. energía) y qué hace `RepairStation`.

### Niveles: mapas fijos por bioma
Cada nivel es un **mapa fijo diseñado a mano**, con identidad visual y navegación limpia para el *pathfinding*. La rejugabilidad viene de los sistemas de §5, no de generación procedural.

Principios de diseño espacial:
* **El Ascensor en el centro del mapa**, con **3 o 4 salidas** distintas para que un enemigo no bloquee la única entrada/salida.
* **Circuitos cerrados (*loops*):** pasillos y salas forman anillos alrededor de estructuras sólidas. Sin callejones sin salida largos en rutas principales, para poder rodear a los enemigos.
* **Verticalidad táctica:** pasarelas, escaleras y plataformas altas como rutas de escape o zonas de riesgo/recompensa.
* **Escondites** repartidos en pasillos y salas.

Ejemplos de biomas (**[POR DEFINIR]** número final y temática; ver `creation_models.md`):
* **Cerrado (Fábrica / Complejo industrial):** pasillos estrechos, luz artificial controlada, puertas de seguridad electrónicas, pasarelas metálicas sobre maquinaria.
* **Abierto ilusorio (Pantano / Exterior):** mapa delimitado por obstáculos naturales y niebla densa (`Lighting.Atmosphere`); pasarelas de madera sobre agua que ralentiza y hace ruido; **perímetro exterior de castigo** donde una criatura embosca a quien salga de los límites. (Es un charco de ambientación, no el sistema de agua oceánico eliminado.)

Cada nivel contiene: `ElevatorDock`, `TreasureSpawn`, `MachineSpawn`, `PuzzleDoor`/`PuzzleChest`, `CreatureSpawn` y `Patrol`, con **varios puntos posibles** por tipo (ver §5).

### Objetivos e interacción
* **Tesoros:** objetos con valor y peso, capacidad de carga limitada. Se depositan en el Ascensor para alcanzar la cuota.
* **Generadores de energía / máquinas de comunicación:** se reparan manteniendo `E` o con minijuego; al repararse emiten ruido mecánico progresivo que atrae patrullas cercanas. **[POR DEFINIR]** pasos, piezas necesarias y si exigen cooperación.
* **Terminales y cajas fuertes (hackeo):** minijuego breve que requiere concentración; fallar activa una alerta local.
* **Puzzles:** desbloquean puertas y tesoros. **[POR DEFINIR]** tipos (códigos, palancas, interruptores, secuencias).
* **Escondites:** `E` en una caja industrial para ocultarse; una criatura que se queda cerca te descubre tras unos segundos.

### Criaturas (nuevo, sin combate)
* Criaturas **mezcladas estilo nextbot** (híbridos de objetos, personas y formas distorsionadas). No hay armas: se sobrevive huyendo, escondiéndose y evitando ruido y luz.
* **IA: pendiente de definir.** Existe una primera versión heredada (`MonsterService`: patrulla, persecución con anticipación, zarpazo, rastreo al perderte, aviso entre enemigos). **[POR DEFINIR]** tipos, velocidades, detección, cómo se evaden y cómo se adapta a mapas fijos.
* **Reglas técnicas ya fijadas:**
  * **Anti-camping en el Ascensor:** al estar todos los jugadores dentro del volumen seguro, los enemigos limpian su objetivo (`Target = nil`) y patrullan hacia nodos lejanos para no bloquear la puerta. Dentro del Ascensor no se puede ser detectado ni atacado.
  * **`PathfindingModifier`:** costos de terreno (agua profunda, zonas oscuras) para diferenciar enemigos que siguen caminos normales de criaturas que emboscan por atajos.
* Muerto → **espectador**. Al recibir daño: sacudida corta de cámara y destello rojo; temblor leve creciente con la cercanía de un enemigo que persigue.

### Economía (solo dentro de la partida)
* Fondo común: se venden tesoros y se compra equipo (mejor linterna, velocidad de carrera, etc.) en el **mapa de tienda** (`Parada`). Sin persistencia entre partidas ni DataStore.

## 4. Arquitectura de Datos & Eventos (Roblox Spec)

### Estado de sala/partida (en memoria)
| Variable | Tipo | Descripción |
| :-- | :-- | :-- |
| `RoomCode` | string | Código de la sala |
| `Players` | list | 1–5 jugadores |
| `LevelIndex` | number | Nivel actual |
| `TeamMoney` | number | Dinero común |
| `Quota` | number | Cuota de tesoros del piso (escala con el número de jugadores) |
| `ObjectivesDone` | number | Objetivos clave completados en el nivel |
| `Mutator` | string | Mutador de bioma activo (§5) |
| `State` | enum | Lobby / Traveling / Exploring / Stopover / Won / Lost |

### DataStore
* Sin guardado de economía.

### Eventos Cliente-Servidor
* `CreateRoom` / `JoinRoom` (RemoteFunction), `StartRun` (RemoteEvent).
* `RequestPurchase` (RemoteFunction) y `SellTreasure` (RemoteFunction): validados por el servidor con el fondo común.
* `RepairMachine` (RemoteEvent): progreso de reparación, validado por el servidor (distancia, estado).
* `SubmitPuzzle` / `SubmitHack` (RemoteFunction): el servidor valida la solución y abre la puerta/tesoro.
* `ControlAction` (RemoteEvent): acciones de la Estación de Control (abrir/cerrar puerta, alarma, código), con enfriamiento validado en servidor.
* `UpdateHUD` (RemoteEvent): dinero, nivel, cuota, objetivos, estado.
* `RunEnded` (RemoteEvent): victoria/derrota.
* Máximo 20 Hz por cliente (ver `Docs/CLAUDE.md`).

## 5. Rejugabilidad (sin generación procedural)
1. **Spawns variables:** varios puntos posibles para tesoros, cajas fuertes, generadores y terminales; en cada partida se activa un subconjunto aleatorio.
2. **Rutas variables:** alternar qué puertas están abiertas, cerradas con llave o bloqueadas por escombros.
3. **Mutadores de bioma** (condición aleatoria por piso):
   * *Apagón total:* puertas y computadoras sin energía hasta reparar un generador maestro.
   * *Fuga / inundación:* zonas bajas peligrosas o lentas que obligan a usar el segundo nivel.
   * *Cierre de emergencia:* compuertas que se sellan periódicamente y requieren hackeo rápido.
   * *Inestabilidad acústica:* sin música ambiental; pasos e interacciones atraen enemigos desde más lejos.
4. **Escalado de tensión:** al depositar la cuota completa o activar el último generador, las luces pasan a estado de alerta y los enemigos entran en búsqueda activa hasta que el Ascensor se cierra.
5. **Escalado por jugadores:** cuota de tesoros, número de generadores y agresividad de la IA se ajustan automáticamente al número de jugadores (1 a 5).

## 6. Estación de Control (cooperativo y solitario)
Estación integrada (o adyacente) dentro de la zona segura del Ascensor, para que un jugador asuma el rol de **Operador** mientras el resto explora.

* **Mapa radar táctico:** silueta del piso y puntos en movimiento, sin distinguir claramente aliados de enemigos (tensión en la comunicación).
* **Cámaras de seguridad (CCTV):** vigilar intersecciones clave y detectar amenazas silenciosas.
* **Soporte remoto (con enfriamiento/energía):** abrir o cerrar puertas de seguridad a distancia, activar alarmas o luces en salas lejanas para distraer, enviar códigos de desbloqueo para acelerar hackeos.
* **Modo solitario:** antes de salir se pueden revisar cámaras y radar para trazar una ruta. **[POR DEFINIR]** si hay **tableta portátil** (opcional/comprable, batería limitada) para consultar el radar fuera del Ascensor.

## 7. Hoja de ruta sugerida (MVP)
1. **Greybox jugable:** un único mapa fijo completo (ej. Fábrica) con bloques simples, validando distancias, alturas de salto y rutas circulares, con el Ascensor al centro.
2. **Bucle básico:** Ascensor (zona segura + depósito) con un tipo de objetivo (generadores) y un enemigo patrullando.
3. **Estación de Control:** radar y control remoto de puertas.
4. **Rejugabilidad:** spawns aleatorios, mutadores y ambientación final (iluminación, niebla, audio).

## 8. Alcance
**Se elimina:** todo lo oceánico (agua, nado, oxígeno, presión, casco, profundidad, fauna marina, naufragios, cuevas submarinas, baliza del fondo, combate con arpón), el dash, la generación procedural de salas (`MazeGenerator`, `RoomGenerator`, ya borrados del código) y la baliza final.

**Se mantiene:** lobby por códigos, tesoros, economía en memoria, linterna, sprint con estamina, escondites, primera persona fija, indicador del Ascensor, temporizador, espectador, cabina sellada con traslado entre niveles.
