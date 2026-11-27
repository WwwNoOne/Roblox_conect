# Estado del proyecto

> **Rama de trabajo: `backrooms-cleanup`**, en el worktree `../Roblox_conect-backrooms`. Rojo sirve desde ahí, así que todo cambio de código, documentos o assets se hace en esa carpeta. Este worktree (`Roblox_conect`, rama `main`) es solo un espejo: no editar aquí. Al terminar, commit en `backrooms-cleanup`, `git merge --ff-only backrooms-cleanup` en `main` y push de las dos.

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

- `main` y `backrooms-cleanup` se mantienen iguales en `origin`. El código vivo se edita en el worktree `Roblox_conect-backrooms` (Rojo sirve desde ahí); luego `git merge --ff-only backrooms-cleanup` en `main` y push de ambas. **El 26/11 se trabajó por error en el worktree de `main` (criaturas): Studio no lo veía hasta copiarlo a `backrooms-cleanup`.**
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

## Criaturas (26/11/2026, T05)

Implementadas las 3 categorías 2.5D (ver [criaturas.md](docs/criaturas.md) e [integracion_criaturas.md](docs/integracion_criaturas.md)). Revisión y pruebas en Play (1 cliente):
- [x] Aparecen las 3 en `Level_1` (8/16/24 s), sin errores.
- [x] Agresivo: detecta en 0,2 s, persigue, `Windup` → `Lunge` y mata (98 → 0).
- [x] Acechador: emboscada a 8 studs, `AmbushStrike`, −30 de vida y screamer 2D (la `ScreenGui` se activa).
- [x] Acosador: ignorado 5,4 s delata («Algo te está observando...») y huye; mirado de frente huye en ~1,5 s.
- [x] Los 6 `HideSpot` tienen prompt para esconderse.
- Corregido en la revisión: carrera de caminos (un camino vacío del grafo se daba por «llegado» y el Acechador se quedaba en su spawn); red de navegación fragmentada (14 islas → malla `NavGridSpacing` de 10 studs, 181 de 199 nodos conectados); nodos de escondites dentro de las taquillas; detección de «mirar» con la cabeza (la tuerce `Turning`; ahora con el cuerpo).

## Lobby: entrar al ascensor andando (26/11/2026)

- El ascensor estaba fuera del lobby, detrás de `Lateral_1` y con la puerta hacia fuera: no había forma de llegar. Se movió (−32, 0, −34) para encajar su puerta en la pared norte, donde estaba la persiana decorativa `ElevatorPreview` (retirada, igual que `Pilaster_25`). `NorthWall` se partió en `NorthWall_West` + `NorthWall_Lintel`. Es un cambio del place: **guardar en Studio**.
- `BoardingService` reescrito (ya no hay `BoardPrompt`): en el lobby la puerta está abierta; quien entra en `InteriorZone` queda apuntado (`Boarded`) y ve «Esperando jugadores (n/total)» (`BoardingHud.client`). Con todos dentro, la puerta se cierra (`Config.Boarding.DoorSeconds`), pausa `StartDelay` y empieza la partida. Si alguien sale o entra alguien nuevo durante el cierre, se reabre. Quien vuelve de una partida dentro del ascensor debe salir y volver a entrar.
- [x] Probado con 1 jugador: entra andando desde el spawn, cierre, partida; derrota → vuelta al lobby con la puerta abierta; segunda partida.
- [ ] Probar con 2+ clientes (mensaje «Esperando jugadores (1/2)», reapertura si alguien sale) y la vuelta tras ganar (aviso «Sal del ascensor...»).

## Resumen del 26/11/2026 (tarde)

- **Lobby y ascensor:** se entra andando y aparece «Esperando jugadores (n/total)». Con todos dentro, la puerta se cierra y arranca la partida. Probado con 1 y 2 clientes, también la vuelta al lobby («Sal del ascensor y vuelve a entrar»).
- **Turning:** compatible con `AnimationConstraint`; 0 errores. `Movement System.rbxm` y `legacy/` en `.gitignore`.
- **Criaturas nuevas:** SujetoFeliz (mirada sostenida) y Acosador del tramo final, integradas en `MonsterService`. Probadas con 1 y 2 clientes: solo cuenta la mirada del objetivo, y el Acosador final cambia de objetivo cuando el suyo entra al ascensor.
- **Teletransportes repartidos:** al salir, entrar, volver al lobby o subir rezagados, cada jugador va a un hueco distinto (antes uno caía al vacío). Probado con 2 clientes saliendo en el mismo segundo.
- **Codex:** `Level_1` y `Level_2` rehechos con generador, y 4 biomas nuevos (Hospital, Escuela, Mansión y Centro comercial, el final con baliza). Escondites con vista desde dentro (`HidingView`), ambiente por nivel (`LevelAtmosphere`) y `MapNav` con varias plantas. Revisado en Play: cargan bien, la red se construye en 0,2–2,4 s sin congelar y no hay errores.
- **Correcciones:** las criaturas no se crean si el nivel acaba mientras se construye la red.
- **Docs:** reglas para Codex en [docs/reglas_codex.md](docs/reglas_codex.md) (enlazado desde `AGENTS.md`). Pendientes de mapas en [docs/niveles_generados.md](docs/niveles_generados.md).
- **Mañana:** Codex sigue con piezas, ambientación y sonido de los mapas siguiendo `reglas_codex.md`. Después, Claude revisa los mapas (red y duplicados), decide con el usuario qué hacer con `Workspace.zona` y sigue con la lista de abajo.

## Siguiente sesión

1. Probar con 4 clientes (y una caja fuerte con 2); criaturas con 2+ clientes.
2. Criaturas sin probar: `Noise.Emitted` → `Investigate` del Agresivo, olfateo de escondites, Acechador vigilando una taquilla ocupada.
3. Sonidos `Criatura_*` en `Workspace.sonidos` (hoy suenan sustitutos); quitar `Config.Monster.Debug` antes de publicar; borrar las 7 criaturas oceánicas de `ServerStorage.GameAssets.Creatures`.
4. ~~Ruido de `Turning`~~ (hecho 26/11): el rig usa `AnimationConstraint`, con `C0` de solo lectura; `Turning` escribía `C0` cada frame, fallaba y nunca giraba el cuerpo. Ahora escribe `Attachment0.CFrame` (o `C0` si es `Motor6D`): 0 errores, giro de cadera de 21° al moverse de lado.
5. `assets_build/*Movement System.rbxm` y `legacy/` quedan en `.gitignore` (decisión del 26/11).
6. ~~Integrar las variantes de Codex~~ (hecho 26/11): SujetoFeliz y Acosador del Tramo Final en `MonsterService` (campo `Behavior`), probados con 1 cliente; ver `docs/integracion_criaturas.md` §5. Probados también con 2 clientes (26/11). `Config.Monster.PerLevel = 5` para pruebas: bajarlo antes de publicar.
7. **Guardar el place en Studio**: ascensor del lobby movido y plantillas nuevas en `GameAssets.Creatures`.
8. **Salidas y entradas simultáneas** (hecho 26/11): dos personajes teletransportados al mismo punto se solapaban y uno caía al vacío. `ElevatorService` (`freeSpot`), `Runs` (`spreadCFrame` en la vuelta al lobby y al subir rezagados) y `BoardingService` (`clearDoorway`) reparten ahora a cada jugador en un hueco distinto. Probado con 2 clientes saliendo en el mismo segundo (6 ms de diferencia).
9. **`Workspace.zona`**: pieza suelta de 700×1×700, visible y con colisión, a altura 49,5. Atraviesa el Nivel 1 a la altura de la cabeza y bloquea a los jugadores. Ningún script la usa. Borrarla o moverla (decisión del usuario).
10. Retocar los mapas generados: zonas sueltas en la red de criaturas (Pantano: 340 de 2150 puntos) y piezas duplicadas (Pantano 764, Mansión 430, Escuela 151, Centro comercial 14). Ver `docs/niveles_generados.md`, «Pendiente de retocar».

## Entregas

| Estado | Entrega | Responsable |
| --- | --- | --- |
| Reutilizable | Submarino transitable A01 v2 → renombrar a **Ascensor** (ver tabla en el manifiesto) | Codex |
| Reutilizable | Tesoros small/medium/large (A03) | Codex |
| Por revisar | Kits de salas y pasillos industriales como base liminal | Codex |
| Pendiente | `Level_1` liminal, `Parada`, `machine_comm`, `puzzle_door`, `puzzle_chest`, `creature_agresivo_01`, `creature_acosador_01`, `creature_acechador_01` (2.5D + sprites, ver `docs/criaturas.md`) | Codex |
| Hecho (sin probar) | Retirar agua/oxígeno/presión/casco del código; correr | Claude |
| Hecho | Puertas con panel de interruptores (`Puerta*`) | Claude |
| Pendiente | Máquinas de comunicación y criaturas (T05: 3 categorías 2.5D + screamer 2D) | Claude |
| Por definir | Tipos de puzzle extra, reparación de máquinas, condición de victoria, temáticas de niveles 2+ | Usuario |

## Pulido de mapas (Codex, 26/11/2026)

- [x] Regenerados los seis exports con separación de caras coplanares y `ContencionExterior`. Distribución, marcadores y `src/` conservados.
- [x] Seis pruebas de regresión y auditoría de los seis XML: cero caras coincidentes en bloques alineados. Informe en `assets_build/reports/map_polish.json`.
- [x] Aplicados los parches en Studio con respaldo de los seis mapas; guardado en Roblox, versión 481. 43.590 barridos de colisión sin fugas, un intento de escape saltando por mapa en Play sin cruzar y red de criaturas sin pérdida de conectividad. Cero caras coplanares residuales en los bloques alineados del place.
- Detalles y comandos para continuar: [docs/pulido_mapas.md](docs/pulido_mapas.md). La conectividad de criaturas del Pantano sigue pendiente. `Workspace.zona` ya no existe en el lugar revisado.
