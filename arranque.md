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
- Exports de Codex pendientes de revisar contra el manifiesto: `Elevator`, `Level_1`, `Lobby`, `Kit_Gris_Modular` (medidas en [medidas_kit_modular.md](docs/medidas_kit_modular.md)).

## Entregas

| Estado | Entrega | Responsable |
| --- | --- | --- |
| Reutilizable | Submarino transitable A01 v2 → renombrar a **Ascensor** (ver tabla en el manifiesto) | Codex |
| Reutilizable | Tesoros small/medium/large (A03) | Codex |
| Por revisar | Kits de salas y pasillos industriales como base liminal | Codex |
| Pendiente | `Level_1` liminal, `Parada`, `machine_comm`, `puzzle_door`, `puzzle_chest`, `creature_nextbot_01` | Codex |
| Hecho (sin probar) | Retirar agua/oxígeno/presión/casco del código; correr | Claude |
| Pendiente | Máquinas de comunicación, puzzles y criaturas | Claude |
| Por definir | Mecánicas de criaturas, tipos de puzzle, reparación de máquinas, condición de victoria, temáticas de niveles 2+ | Usuario |
