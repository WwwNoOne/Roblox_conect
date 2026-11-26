# Integración de criaturas 2.5D y Screamer 2D (T05)

> **Fecha:** 2026-11-26 · **Estado:** Implementado, revisado y probado en Play con 1 cliente (ver §4). Los `.rbxmx` ya están en `ServerStorage.GameAssets.Creatures`. Pendiente: pruebas con 2+ clientes.
>
> **Rama de trabajo:** `backrooms-cleanup` (worktree `Roblox_conect-backrooms`, desde donde sirve Rojo). No editar en el worktree de `main`.
> **Documentos relacionados:** [docs/criaturas.md](criaturas.md) · [creation_models.md](../creation_models.md) · [game_designs/GDD.md](../game_designs/GDD.md) · [docs/plan.md](plan.md)

Este documento resume todo lo agregado y modificado para que otros agentes (Claude / Codex / revisores) puedan auditar la integración sin recorrer todo el historial.

---

## 1. Assets de Codex verificados

En `assets_build/exports/creatures/` se revisaron los 3 modelos entregados por Codex y sus `rbxassetid://` subidos como `Image`:

| Modelo | Archivo | Categoría (`Category`) | Grilla | IDs en uso |
| :--- | :--- | :--- | :--- | :--- |
| `creature_agresivo_01` | [creature_agresivo_01.rbxmx](../assets_build/exports/creatures/creature_agresivo_01.rbxmx) | `Aggressive` | `4×4`, `12` FPS | Cuerpo `125416395009712`, Ojos `92079012147493` (`LightInfluence=0`), Billboard `9.5×9.5`, `StudsOffset.Y=0.2` |
| `creature_acosador_01` | [creature_acosador_01.rbxmx](../assets_build/exports/creatures/creature_acosador_01.rbxmx) | `Stalker` | `4×4`, `12` FPS | Cuerpo `72237757733107`, Ojos `85458595523316` (`LightInfluence=0`), Billboard `8.5×8.5`, `StudsOffset.Y=-0.42` |
| `creature_acechador_01` | [creature_acechador_01.rbxmx](../assets_build/exports/creatures/creature_acechador_01.rbxmx) | `Ambusher` | `4×4`, `12` FPS | Cuerpo `117589415294503`, Screamer `85806574415851` (`4×4`, `12` frames), Billboard `7.5×7.5`, `StudsOffset.Y=-1.05` |

Todos cumplen el contrato de [docs/criaturas.md](criaturas.md) (`Root` `2×8×2`, `AlwaysOnTop = false`, `LightInfluence = 1` en cuerpo y `0` en ojos, `ScaleType = Fit`).

---

## 2. Cambios realizados en el código (`src/`)

### 2.1 Configuración y remotos (`ReplicatedStorage/Shared`)
* **[Remotes.luau](../src/ReplicatedStorage/Shared/Remotes.luau):**
  * Añadido el `RemoteEvent` `CreatureScreamer` (`servidor -> cliente`) para disparar el screamer 2D del Acechador.
* **[Config.luau](../src/ReplicatedStorage/Shared/Config.luau):**
  * Actualizada `Config.Monster`:
    * `KeepModelScale = true`, `CenterHeight = 4`, `BodyRadius = 2.0`, `AttackDamage = 100` (el Agresivo mata si alcanza al jugador).
    * `PerLevel = 3`, `FirstDelay = 8`, `SpawnStagger = 8` para probar las 3 categorías juntas en `Level_1`.
    * Parámetros nuevos de `Stalker` (`StalkMinDist`, `StalkMaxDist`, `StalkLookDot`, `StalkBanishSeconds`, `StalkAlertSeconds`, `StalkTooClose`, `StalkCooldown`) y `Ambusher` (`AmbushMoveSpeed`, `AmbushFleeSpeed`, `AmbushRange`, `AmbushHideSpotRange`, `AmbushDamage = 30`, `AmbushScreamerSeconds`, `AmbushCooldown`, `AmbushRelocateSeconds`).
    * `Config.Monster.Species` reemplazado por `Agresivo`, `Acosador` y `Acechador` con sus `TemplateName` e IDs de sprites de Codex.
  * Añadidos prefijos opcionales en `Config.Sfx`: `CreatureRoar`, `CreatureAlert`, `CreatureWhisper`, `CreatureScreamer`.

### 2.2 Navegación sobre mapas fijos (`ServerScriptService/Services`)
* **[MapNav.luau](../src/ServerScriptService/Services/MapNav.luau)** *(nuevo, `--!strict`)*:
  * `MapNav.Build(map)` lee `ElevatorDock`, `Patrol1..N`, `CreatureSpawn`, `MachineSpawn`, `TreasureSpawn`, `PuzzleSpawn` y `HideSpot`/`Escondite` del mapa activo en `Workspace.Maps` y publica `LevelState.nav`, `LevelState.container` y `LevelState.entry`.
  * Proyecta los nodos al suelo real del mapa (`snapToFloor`) y construye el grafo de visibilidad (`adj`) más `ambushSpots` (esquinas y escondites).
  * Calcula `boundsCenter` / `boundsHalf` usando `Bounds` si existe o `map:GetBoundingBox()` como respaldo (en `Level_1.rbxmx` no había `Bounds`, lo que antes impedía detectar jugadores).
  * `MapNav.ComputeNavMeshPath(...)` consulta `PathfindingService` respetando paredes y puertas cerradas (`Workspace.RunObjectives`).
* **[HidingHandlers.server.luau](../src/ServerScriptService/Services/HidingHandlers.server.luau):**
  * Ampliado `isHideVolume` para aceptar tanto `Escondite` como `HideSpot` (en `Level_1.rbxmx` los volúmenes se llaman `HideSpot` dentro de carpetas `Escondite01..06`).
* **[MonsterService.server.luau](../src/ServerScriptService/Services/MonsterService.server.luau):**
  * Construye `MapNav.Build(map)` al entrar en estado `"Level"` y limpia con `MapNav.Clear()` al salir.
  * **Carga híbrida de plantillas:** busca primero en `ServerStorage.GameAssets.Creatures`, `Plantillas`, `Workspace.Creatures` o `Assets.Find`; si los `.rbxmx` aún no se importaron en Studio, `buildFallbackTemplate` genera el modelo 2.5D exacto con los IDs de `Config.Monster.Species`.
  * Etiqueta todos los monstruos con `"ProcCreature"` (para `CameraFxClient` y `CreatureFxClient`) y añade `EyeLight` (`PointLight`) y `AuraParticles` si no existen en `Root`.
  * Incluye `Workspace.RunObjectives` en `RaycastParams` para que las persianas cerradas (`Door_*`) bloqueen vista y movimiento.
  * `setPath` calcula primero el grafo Dijkstra de forma síncrona (sin bloquear `Heartbeat`) y lanza `MapNav.ComputeNavMeshPath` asíncrono con `task.spawn` para refinar alrededor de muros y puertas.
  * Conecta `Noise.Emitted` para atraer a criaturas `Aggressive` hacia fallos/reparaciones de generadores, cajas y puertas.
  * Implementa las 3 IAs:
    * `stepAggressive`: patrulla, vista (amplificada con linterna), oído (`Sprint` / agachado / `Noise`), persecución con frenesí, `Windup -> Lunge` letal (`100` daño) y olfateo de escondites.
    * `stepStalker`: busca puntos de observación con línea de visión (`32..85` studs), gira hacia el jugador; huye (`Flee -> Cooldown`) si lo miran directo `1.6 s` o se acercan a `< 20` studs; si lo ignoran `5.5 s`, delata al jugador alertando a los `Aggressive`.
    * `stepAmbusher`: elige esquinas o `HideSpot` (sin repetir ni empalmarse con otro Acechador), espera inmóvil; al acercarse un jugador (o estar en el `HideSpot` vigilado), lo saca si estaba escondido, dispara `CreatureScreamer`, aplica `30` de daño (`PlayerHit`), hace `AmbushStrike` y huye (`Flee -> Cooldown`).

### 2.3 Efectos y animación en cliente (`StarterPlayer/StarterPlayerScripts`)
* **[CreatureFxClient.client.luau](../src/StarterPlayer/StarterPlayerScripts/CreatureFxClient.client.luau)** *(nuevo)*:
  * Anima `BodyBillboard.Sprite` y `EyesBillboard.Eyes` usando `SpriteCols`, `SpriteRows`, `AnimFps` y el atributo `Estado` (fila `0..3`).
  * Aplica trucos 2.5D: balanceo vertical/lateral (`StudsOffset` y `Rotation`) proporcional a la velocidad real, espasmos en `Windup`/`Lunge`/`AmbushStrike`, sombra local proyectada al suelo (`CreatureFloorShadow`) y soporte de susurro 3D (`Config.Sfx.CreatureWhisper`).
  * Escucha `CreatureScreamer` y renderiza el **screamer 2D animado**: flash inicial, sprite sheet animado (`ScreamerFrames`), escala con rebote, aberración cromática (capas rojo/cian vibrando), franjas de estática, viñeta y audio con respaldo automático si faltan sonidos propios en `Workspace.sonidos`.

---

## 3. Puntos a revisar por otros agentes y en Studio

1. **Importación en Studio (`ServerStorage.GameAssets.Creatures`):** aunque el respaldo automático ya instancia los 3 modelos con los mismos `rbxassetid://` de Codex, conviene importar `creature_agresivo_01.rbxmx`, `creature_acosador_01.rbxmx` y `creature_acechador_01.rbxmx` dentro de `ServerStorage.GameAssets.Creatures` en el lugar de Studio para usar directamente los `.rbxmx` originales.
2. **Sonidos opcionales en `Workspace.sonidos`:** añadir clips con prefijo `Criatura_Rugido`, `Criatura_Alerta`, `Criatura_Susurro` y `Criatura_Screamer` (el screamer ya tiene respaldo sonoro si aún no existen).
3. **Pruebas pendientes en Studio (`Server & Clients`):**
   * Verificar que los 3 enemigos aparecen en `Level_1`, evitan `Elevator.InteriorZone` y respetan las persianas cerradas (`Puerta01`/`Puerta02`).
   * Validar ocultarse en `Escondite01..06` (`HideSpot`) con `E`, la huida/delación del Acosador y el screamer 2D + `30` de daño del Acechador.
   * Confirmar con `rojo build` o `rojo serve` (en el entorno donde esté instalado el CLI de Rojo; en este entorno de terminal no estaba en `PATH`) que no hay errores de tipos ni de ejecución en Roblox Studio.

---

## 4. Revisión y pruebas en Play (2026-11-26)

**Probado (1 cliente, `Level_1`):** aparición de las 3 criaturas; Agresivo detecta, persigue y mata; Acechador embosca, quita 30 y dispara el screamer; Acosador delata si lo ignoras y huye si lo miras; los 6 `HideSpot` tienen prompt.

**Corregido en la revisión:**
1. **Carrera de caminos (`MonsterService.setPath`).** Si el grafo no daba camino, `follow()` lo daba por llegado en el mismo frame y la respuesta de `PathfindingService` se descartaba al cambiar de estado: el Acechador se quedaba en su spawn. Ahora cada petición lleva un id (`pathReq`; solo vale la última) y, mientras espera sin camino (`pending`), no cuenta como llegada. `setDirect` invalida las peticiones pendientes.
2. **Red de navegación fragmentada (`MapNav`).** 32 nodos en 14 islas: los marcadores no se ven entre sí. Se añade una malla sobre el suelo de la planta baja (`Config.Monster.NavGridSpacing = 10`, solo puntos con hueco libre) con aristas cortas entre vecinos; los marcadores se proyectan desde +1,5 studs (antes caían encima de muebles) y se omiten los `PuzzleSpawn` de puertas (quedan dentro de la persiana). Resultado: 181 de 199 nodos conectados (los sueltos son tesoros en pasarelas altas, que cubre `PathfindingService`). Se construye 0,5 s después de entrar al nivel para incluir las persianas.
3. **Escondites.** El nodo del `HideSpot` caía dentro de la taquilla (inalcanzable). Ahora el punto de emboscada es el nodo libre más cercano junto al mueble, y el Acechador saca a quien esté escondido en esa taquilla.
4. **«Lo está mirando» (Acosador).** Usaba `Head.LookVector`, pero `Turning.client` tuerce la cabeza hasta 60°: nunca se cumplía. Ahora usa la orientación horizontal del `HumanoidRootPart` (en `LockFirstPerson` sigue a la cámara).

Descartado: las 372 piezas de `Level_1` con `CanQuery = false` son decoración sin colisión (los jugadores también las atraviesan); ninguna pieza sólida es invisible a los rayos.

**Sin probar:** `Noise.Emitted` → `Investigate`, olfateo de escondites, Acechador en taquilla ocupada, 2+ clientes.

