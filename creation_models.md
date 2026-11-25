# Modelos requeridos (hand-off Claude -> Codex)

> **Cambio de dirección (2026-11-25):** temática Backrooms / espacios liminales. Todo el contenido oceánico anterior está en `assets_build/archive_oceano/` y su manifiesto en `docs/archivo_oceano/`. **No usar nombres ni modelos del archivo.** Ver [GDD](game_designs/GDD.md). Los ítems **[POR DEFINIR]** esperan especificación.

## Estándar de entrega

- Entrega los modelos y mapas en formato Roblox `.rbxmx` dentro de `assets_build/exports/`.
- Usa geometría **low poly estilizada**, con siluetas claras, caras amplias y texturas o materiales de color plano.
- Ambiente liminal: espacios vacíos, iluminación artificial, repetición, sensación de "lugar equivocado". Cada nivel tiene su paleta y temática; usa luz para guiar o destacar.
- Incluye el rig y los clips editables en el `.rbxmx` para criaturas y otros modelos que deban animarse.
- Evita caras visibles coplanares superpuestas. Comprueba en Studio acabado, colisiones, recorridos transitables y animaciones.

## Estado de los archivos existentes

| Archivo | Estado |
| :-- | :-- |
| `submarine_A01_v2.*` (y `submarine_A01.*`, `submarine.fbx`) | **Se conserva como Ascensor.** Codex debe re-exportarlo con los nombres nuevos (tabla de abajo). Hasta entonces los archivos conservan el nombre antiguo. |
| `treasure_small/medium/large.*`, `abismo_A03.blend` | Se conservan (tesoros genéricos). Revisar que no tengan motivos marinos. `abismo_A03.blend` se renombrará al re-exportar. |
| `beacon.*` | Se conserva como candidato a salida/objetivo final **[POR DEFINIR]**. |
| `lamp.fbx` | Se conserva (linterna). |
| `Kit_10_Salas_Vacias_16`, `Kit_Pasillos_Industriales_16`, `Kit_Pasillos_Verticales_16`, `Salas_02_10_Industriales`, `Sala_01_Planta_De_Filtrado`, `Sala_De_Bombeo_160`, `Caja_Industrial_Rectangular`, `Kit_Decoracion_Salas_Ligero`, `Kit_Objetos_De_Recoleccion`, `Kit_Tesoros_Minerales` | **Por revisar.** Posible reciclaje como kit modular liminal. Quitar o reemplazar todo detalle marino (algas, musgo, tuberías de agua, etc.). |
| Todo lo demás (`archive_oceano/`) | Archivado. No usar. |

## Renombrados del Ascensor (antes submarino)

| Antiguo | Nuevo | Nota |
| :-- | :-- | :-- |
| `Submarine` | `Elevator` | Model raíz |
| `Submarine.Hull` | `Elevator.Body` | PrimaryPart, centrado en el interior |
| `Hatch` / `Hatch.Door` / `Hatch.Frame` | `Gate` / `Gate.Door` / `Gate.Frame` | Puerta de salida |
| `HullGauge` | `StatusGauge` | **[POR DEFINIR]** qué muestra; mientras tanto, dinero común/nivel |
| `RepairStation` | **Retirar** | El casco ya no existe. **[POR DEFINIR]** si se reutiliza |
| `SellStation`, `ShopStation` | Sin cambios | |
| `SpawnPoint1…4`, `InteriorZone`, `Lights`, `AlarmLight` | Sin cambios | `AlarmLight` se usa para avisos de criaturas |
| `SubDock` (en mapas) | `ElevatorDock` | Donde se acopla el Ascensor |

El resto de atributos (puntos de entrada/salida, `PromptAttachment`, escala 1.5 sobre la v2: interior 22,3 × 12 × 29,1 studs, puerta 9,3 × 9,6) se mantiene. Quitar toda estética de submarino (casco redondo, ojos de buey, remaches marinos): debe leerse como cabina/ascensor industrial.

## Nombres que el código ya espera (2026-11-25)
`Workspace.Elevator` (con `Body`, `Gate.Door/Frame`, `InteriorZone`, `SpawnPoint1…4`, `SellStation`, `ShopStation`, `StatusGauge.Screen`), `ElevatorDock` en cada mapa y en `Workspace.Sala_0`, plantilla de sala grande `Sala_Grande`, y plantillas de criaturas/objetos en `ServerStorage.GameAssets` (`Creatures/creature_nextbot_01`, `Kit_Objetos_De_Recoleccion`, `Beacon`).

## Prioridad 1 (primer prototipo)
| Id | Descripción | Tris máx |
| :-- | :-- | :-- |
| `Elevator` | Re-exportar `submarine_A01_v2` con la tabla de renombrados y estética de ascensor | 8000 |
| `Level_1` | Primer nivel liminal de prueba (propuesta: oficinas/pasillos amarillos). Con `ElevatorDock`, `TreasureSpawn`, `MachineSpawn`, `CreatureSpawn`, `Patrol1…N` | — |
| `Parada` | Mapa de parada: base y `ElevatorDock`. Nadie sale | — |
| `machine_comm` | Máquina de comunicación reparable (radio/terminal/transmisor). Partes: `Body` (PrimaryPart), `PromptAttachment`, `Screen` (SurfaceGui), `StatusLight` (Neon, rojo→verde) | 3000 |
| `puzzle_door` | Puerta bloqueada por puzzle. `Door` (Part móvil), `Frame`, `PromptAttachment`, `StatusLight` | 2500 |
| `puzzle_chest` | Cofre/tesoro bloqueado por puzzle | 1500 |
| `creature_nextbot_01` | Criatura mezclada tipo nextbot (**[POR DEFINIR]** diseño). Contrato abajo | 5000 |

## Prioridad 2 **[POR DEFINIR]**
`Level_2`, `Level_3` (propuesta de temáticas: piscina vacía / almacén / hotel / estacionamiento), más tipos de criaturas, kit modular de pasillos y salas, props de puzzle (palancas, teclados, fusibles), lobby y traje/linterna del jugador.

## Lobby
Escena simple con `LobbySpawn1…4`, `RoomTerminal` (+ `Screen`, `PromptAttachment`) y `ElevatorPreview` (Ascensor decorativo).

## Contrato de nombres (Claude -> Codex)
Los scripts buscan por **nombre exacto** (sensible a mayúsculas) con `FindFirstChild(..., true)`. No renombrar. Los `ProximityPrompt`, `SurfaceGui` y sonidos los añade el script. Partes decorativas: `CanCollide = false`. Partes de control: transparentes, `CanCollide = false`, `Anchored = true`.

### Ascensor (`Elevator`, Model)
`Body` (PrimaryPart), `SpawnPoint1…4`, `InteriorZone` (volumen), `Gate` (`Door`, `Frame`; Attachments `InsidePrompt`, `OutsidePrompt`, `EntryPoint`, `ExitPoint`, `DoorOpen`, `DoorClosed`), `SellStation`, `ShopStation` (cada una con `PromptAttachment`), `StatusGauge` (`Screen`, `Fill`), `Lights`.

### Tesoros (`Treasure_Small`, `Treasure_Medium`, `Treasure_Large`)
`Handle` (PrimaryPart), `GripPoint` (Attachment), `Glow` opcional. Valor y peso los asigna el script.

### Puntos en los niveles
| Nombre | Tipo | Uso |
| :-- | :-- | :-- |
| `TreasureSpawn` | Attachment | Atributo `Size` = `Small`/`Medium`/`Large` |
| `MachineSpawn` | Attachment | Dónde va una `machine_comm` |
| `PuzzleSpawn` | Attachment | Atributo `Kind` **[POR DEFINIR]** |
| `CreatureSpawn` | Attachment | Origen de una criatura |
| `Patrol1…N` | Attachment | Ruta de patrulla, orden numérico |
| `HideSpot` | Part (volumen) | Zona donde esconderse **[POR DEFINIR]** |

### Mapas (`Workspace.Maps`)
| Mapa | Hijos mínimos |
| :-- | :-- |
| `Maps.Level_1…N` | `Platform` (base) y `ElevatorDock` (eje Z = frente), más los puntos de arriba |
| `Maps.Parada` | `Platform` y `ElevatorDock` |

Opcional: `Bounds`. El ascensor debe quedar oculto en un nicho/cuarto de acople; `Gate.ExitPoint` da al área explorable.

### Criaturas (`Model`)
`Root` (PrimaryPart, frente = -Z), `Hitbox` (Part invisible), `Grab` (Attachment de captura en `Root`), `EyeLight` (opcional), `AnimationController` + `Animator` con clips `Idle`, `Walk`/`Run`, `Attack`.

### Máquinas y puzzles
`machine_comm`: `Body`, `PromptAttachment`, `Screen`, `StatusLight`. `puzzle_door`: `Door`, `Frame`, `PromptAttachment`, `StatusLight`. `puzzle_chest`: `Handle`/`Lid`, `PromptAttachment`.

### Lobby (`Workspace.Lobby`)
`LobbySpawn1…4`, `RoomTerminal` (`Screen`, `PromptAttachment`), `ElevatorPreview`.
