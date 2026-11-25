# GDD — Backrooms Coop (título provisional)

> **Cambio de dirección (2026-11-25):** la temática deja de ser submarina/oceánica y pasa a **espacios liminales tipo Backrooms**, con distintas ambientaciones por nivel. Se elimina todo lo relacionado con el océano (agua, presión, oxígeno, profundidad, fauna marina). El diseño anterior está archivado en [`docs/archivo_oceano/`](../docs/archivo_oceano/) y **no es vigente**.
>
> Las secciones marcadas **[POR DEFINIR]** se detallarán más adelante. No implementarlas hasta que se definan.

## 1. Concepto
De 2 a 4 jugadores exploran espacios liminales (pasillos infinitos, oficinas vacías, piscinas sin agua, almacenes, etc.), buscan tesoros, reparan máquinas de comunicación y resuelven puzzles para abrir puertas y cofres, mientras criaturas mezcladas tipo nextbot los persiguen. La partida es por sala, en primera persona o tercera, con ritmo frenético.

## 2. Game Loop
1. **Lobby:** un jugador (host) crea una sala; los demás entran por código o invitación (2–4). El host inicia.
2. **Traslado:** el equipo aparece dentro del **Ascensor** (antes "submarino"), una cabina sellada transitable. Al cerrar la puerta hay crujidos/vibración, fundido a negro y el servidor lo lleva al `ElevatorDock` del siguiente nivel.
3. **Exploración:** en cada nivel el equipo sale del Ascensor, recorre el mapa, recolecta tesoros, **repara máquinas de comunicación** y **resuelve puzzles** que abren puertas y tesoros. Las criaturas patrullan y persiguen.
4. **Parada (Parada):** mapa seguro entre niveles; nadie sale. Desde el Ascensor se venden tesoros y se compra equipo con el fondo común.
5. **Final:** **[POR DEFINIR]** condición de victoria. Hipótesis de trabajo: reparar todas las máquinas de comunicación del último nivel y activar la salida/baliza. Derrota: todos los jugadores muertos.

## 3. Mecánicas

### Movimiento
* PC: `WASD` mover, `Shift` **correr** (reemplaza a "nadar rápido"), `Espacio` saltar, `E` interactuar, `F` linterna.
* Mobile: joystick táctil + botones.
* Cámara: primera y tercera persona.
* **Eliminado:** nadar, oxígeno, agua de Terrain, flotación, niebla por profundidad.

### Ascensor (antes submarino)
* Cabina transitable compartida con puerta, estación de venta, tienda e indicador de estado. Se conserva el modelo `submarine_A01_v2` y se renombra a **Ascensor** (ver `creation_models.md`).
* **Eliminado:** casco (HP) compartido, presión, implosión. **[POR DEFINIR]** si el Ascensor tiene algún valor compartido nuevo (p. ej. energía) y qué hace `RepairStation`.

### Niveles (Backrooms)
* Cada nivel es un escenario independiente con una temática liminal distinta. Secuencia de prueba: `Level_1 → Parada → Level_2 → Parada → Level_3`.
* **[POR DEFINIR]** número final de niveles y su temática (listado en `creation_models.md` como propuesta).
* Cada nivel contiene: `ElevatorDock`, `TreasureSpawn`, `MachineSpawn` (máquinas), `PuzzleDoor`/`PuzzleChest`, `CreatureSpawn` y `Patrol`.

### Elementos interactivos (nuevo)
* **Máquinas de comunicación:** el jugador las repara interactuando (mantener `E` / minijuego). **[POR DEFINIR]** pasos de reparación, piezas necesarias y si requieren cooperación.
* **Puzzles:** desbloquean puertas y tesoros. **[POR DEFINIR]** tipos (códigos, palancas, interruptores, secuencias).
* **Tesoros:** objetos con valor y peso, capacidad de carga limitada. Se mantiene.

### Criaturas (nuevo, sin combate)
* Criaturas **mezcladas estilo nextbot** (híbridos de objetos, personas y formas distorsionadas) que persiguen a los jugadores. **[POR DEFINIR]** tipos, velocidades, detección y cómo se evaden.
* No hay armas. Se sobrevive huyendo, escondiéndose y evitando hacer ruido/luz (a confirmar).
* Muerto → **espectador**.

### Economía (solo dentro de la partida)
* Fondo común: se venden tesoros en el Ascensor y se compra equipo (p. ej. mejor linterna, velocidad de carrera). Sin persistencia entre partidas ni DataStore.

## 4. Arquitectura de Datos & Eventos (Roblox Spec)

### Estado de sala/partida (en memoria)
| Variable | Tipo | Descripción |
| :-- | :-- | :-- |
| `RoomCode` | string | Código de la sala |
| `Players` | list | 2–4 jugadores |
| `LevelIndex` | number | Nivel actual |
| `TeamMoney` | number | Dinero común |
| `MachinesRepaired` | number | Máquinas reparadas en el nivel/partida |
| `State` | enum | Lobby / Traveling / Exploring / Stopover / Won / Lost |

### DataStore
* Sin guardado de economía.

### Eventos Cliente-Servidor
* `CreateRoom` / `JoinRoom` (RemoteFunction), `StartRun` (RemoteEvent).
* `RequestPurchase` (RemoteFunction) y `SellTreasure` (RemoteFunction): validados por el servidor con el fondo común.
* `RepairMachine` (RemoteEvent): progreso de reparación, validado por el servidor (distancia, estado).
* `SubmitPuzzle` (RemoteFunction): el servidor valida la solución y abre la puerta/tesoro.
* `UpdateHUD` (RemoteEvent): dinero, nivel, máquinas, estado.
* `RunEnded` (RemoteEvent): victoria/derrota.
* Máximo 20 Hz por cliente (ver `Docs/CLAUDE.md`).

## 5. Alcance (qué se elimina)
Todo lo oceánico: agua, nado, oxígeno, presión, casco, profundidad, fauna marina, naufragios, cuevas submarinas, baliza del fondo y combate con arpón. Se mantiene: lobby por códigos, tesoros, economía en memoria, linterna, cabina sellada con traslado entre niveles, espectador.
