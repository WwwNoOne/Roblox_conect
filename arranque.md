# Estado del proyecto

Actualizado el 25 de noviembre de 2026. El proyecto cambió de temática: **de submarino/oceánico a Backrooms / espacios liminales**. Referencias vigentes: [GDD](game_designs/GDD.md), [manifiesto de modelos](creation_models.md), [plan](docs/plan.md). El material oceánico está archivado en `docs/archivo_oceano/` y `assets_build/archive_oceano/`. Al cerrar una tarea, actualizar su casilla y registrar la prueba aquí.

## Limpieza realizada (2026-11-25)

- Archivados los modelos y mapas oceánicos (fauna, kits marinos, naufragios, estaciones, niveles submarinos, HUD de buceo, cangrejo, arpón) en `assets_build/archive_oceano/`.
- Archivados los planes y GDD anteriores y el mapa de pruebas oceánico en `docs/archivo_oceano/`.
- GDD, manifiesto, README, Launch, UI y guía de modelos reescritos para la nueva temática.
- **Código (rama `backrooms-cleanup`, 2026-11-25):** retirados agua, natación, oxígeno, casco, presión, profundidad, día/noche, kraken, fauna ambiental, HUD de buceo y animación procedural de peces. Añadido `MovementClient` (caminar/correr). Submarino → Ascensor (`Elevator`): `Hatch`→`Gate`, `SubDock`→`ElevatorDock`, `HullGauge`→`StatusGauge`, `Hull`→`Body`; `ServerStorage.AbismoAssets`→`GameAssets`; plantilla `Kraken_map`→`Sala_Grande`. `rojo build` y sintaxis OK; sin probar en Studio.
- **Sin criaturas por ahora:** `Config.Monster.Species` solo espera `creature_nextbot_01` en `GameAssets.Creatures`.
- **Generación de niveles eliminada (2026-11-25):** borrados `MazeGenerator` y `RoomGenerator`; `LevelService` solo aparta carpetas de pruebas/plantillas a `ServerStorage.Plantillas` y publica `WorldReady`. Los niveles son mapas fijos de `Workspace.Maps` (los carga `Runs`). Adaptados: `SafeZone` (ahora el `InteriorZone` del Ascensor), `EconomyHandlers` (huecos = `TreasureSpawn` del mapa cargado), `HidingHandlers` (escondites `Escondite` en `Workspace.Maps`), `LoadingScreen` y `Runs` (sin respaldo `Sala_0`). `rojo build` OK; sin probar en Play. **Pendiente:** `MonsterService` depende de `LevelState.nav` (red de navegación) que ahora nadie publica: sin ella las criaturas no se mueven hasta resolver T05 (p. ej. `PathfindingService` sobre el mapa fijo).
- **Pendiente en Studio** (no automatizable desde aquí): limpiar el lugar `137133016631933` (ver [Launch.md](Launch.md)).

## Ramas y worktrees (2026-11-25)

- `main` y `backrooms-cleanup` están sincronizadas con `origin` (`ede8f00`). El código vivo se edita en el worktree `Roblox_conect-backrooms` (Rojo sirve desde ahí); luego `git merge --ff-only backrooms-cleanup` en `main` y push de ambas.
- Rama `claudette/confirm-roblox-mcp-connection` y su worktree eliminados (ya estaba fusionada en `main`).
- Sistema de movimiento/cámara/sonido/HUD: completo y presente en ambas ramas (ver [movimiento_sonido_hud.md](docs/movimiento_sonido_hud.md)).
- Añadidos: `AdminService` / `AdminPanel` (**temporales**, solo Studio; borrar antes de publicar), `LoadingScreen` ya no espera ningún nivel generado.
- Exports de Codex pendientes de revisar contra el manifiesto: `Elevator`, `Level_1`, `Level_1_Terror` (variante con vista previa `Level_1_Terror_Vista.png`), `Lobby`, `Kit_Gris_Modular` (medidas en [medidas_kit_modular.md](docs/medidas_kit_modular.md)).

## Objetivos de Level_1 (2026-11-25)

- `Level_1` integrado en `Workspace.Maps` del lugar; `ServerStorage.AbismoAssets` renombrado a `GameAssets` (el código ya lo buscaba así).
- Generadores, cajas fuertes con dial, animaciones y panel de energía: ver [objetivos_nivel.md](docs/objetivos_nivel.md). Verificado en Play (1 cliente): aparecen 3 generadores (2 necesarios) y 2 cajas; bajar da `POWER_OFF` hasta reparar 2; validación de fases y de combinación; botín dentro de la caja; recogida con vuelo; sonidos cargados.
- Corregido: `SellStation`/`ShopStation` están en `Elevator.Equipment` y no se encontraban (no se podía depositar).

## Sesión del 26/11/2026

0. [x] `rojo serve` desde `Roblox_conect-backrooms`; el plugin sincroniza (fuentes de Studio = disco). El lugar ya tenía `Workspace.Maps.Level_1` y `ServerStorage.GameAssets`; `Workspace.Sala_0` ya no existe.
1. [x] **2 clientes** (Test → Clients and Servers, 2 jugadores): sala compartida (CreateRoom/JoinRoom/StartRun), los dos llegan a `Level_1`; aparecen 3 generadores (2 necesarios), 2 cajas y 2 puertas. Un jugador repara G-02 y el otro G-03: el contador es común (1/2 → «Energía restablecida» en ambos), el HUD de los dos muestra `powerDone 2/2` y `RequestDescend` pasa a `ok`; al bajar se limpian los objetivos. Un objetivo ocupado rechaza al segundo jugador («Player1 ya está trabajando aquí»). La puerta abierta por uno se ve abierta en el otro. Sin errores en el servidor. `Config.Objectives` sin cambios (con 2 jugadores siguen siendo 2 necesarios; 3 a partir de 3 jugadores). **Pendiente:** probar con 4 y la caja fuerte con 2.
2. [x] **Puertas con puzzle** en `Puerta01` (Taller) y `Puerta02` (Energía): persiana + panel de interruptores a cada lado. Ver [objetivos_nivel.md](docs/objetivos_nivel.md). Verificado en Play: vano medido 10 × 9 (pared de 1), cerrada bloquea el paso, cortocircuito al agotar las pulsaciones (se mezcla y bloquea 3 s), luces 3D = interfaz, se abre y se cruza.

## Siguiente sesión

1. Probar con 4 clientes (y una caja fuerte con 2).
2. Ruido de `Turning` (`C0` de solo lectura con `AnimationConstraint`) inunda la salida: revisar.
3. T05: red de navegación para criaturas sobre mapas fijos (`LevelState.nav`) y conectar `Noise.Emitted`. Las persianas cerradas (`RunObjectives.Door_*`) deben contar como obstáculo.

## Entregas

| Estado | Entrega | Responsable |
| --- | --- | --- |
| Reutilizable | Submarino transitable A01 v2 → renombrar a **Ascensor** (ver tabla en el manifiesto) | Codex |
| Reutilizable | Tesoros small/medium/large (A03) | Codex |
| Por revisar | Kits de salas y pasillos industriales como base liminal | Codex |
| Pendiente | `Level_1` liminal, `Parada`, `machine_comm`, `puzzle_door`, `puzzle_chest`, `creature_nextbot_01` | Codex |
| Hecho (sin probar) | Retirar agua/oxígeno/presión/casco del código; correr | Claude |
| Hecho | Puertas con panel de interruptores (`Puerta*`) | Claude |
| Pendiente | Máquinas de comunicación y criaturas | Claude |
| Por definir | Mecánicas de criaturas, tipos de puzzle, reparación de máquinas, condición de victoria, temáticas de niveles 2+ | Usuario |
