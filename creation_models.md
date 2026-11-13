# Modelos requeridos (hand-off Claude -> Codex)
Estilo Low-Poly / Anime Stylized. Export `.fbx` a `assets_build/exports/`.

> **Cambio de dirección (2026-11-11):** el juego ahora es terror cooperativo de submarino estilo REPO (ver `game_designs/GDD.md`). Sin combate: el arpón queda descartado. Ambiente oscuro y opresivo; las criaturas deben dar miedo y leerse bien con poca luz.

## Prioridad 1 (necesarios para el primer prototipo)
| Id | Descripción | Tris máx |
| :-- | :-- | :-- |
| `submarine` | Submarino del equipo (2–4 jugadores). Exterior + **interior transitable**: puesto de mando, estación de venta/tienda, panel de reparación, compuerta de salida (airlock). Partes nombradas: `HullGauge` (indicador de casco), `SellStation`, `ShopStation`, `RepairStation`, `Hatch` | 8000 |
| `treasure_small` | Tesoro pequeño (moneda/joya/cofre chico), recogible, ~0.5 stud | 800 |
| `treasure_medium` | Tesoro mediano (estatua/reliquia), ~1.5 studs | 1500 |
| `treasure_large` | Tesoro grande (cofre/ídolo pesado, requiere cargar), ~3 studs | 2500 |
| `beacon` | Baliza final (se coloca en el fondo). Parte `Light` (Neon) que cambia de color al activarse; Attachment `Base` | 2500 |
| `creature_hunter` | Criatura cazadora de zonas 2–3 (persigue por luz/sonido), ~3x2x8 studs, silueta clara y ojos/luz propia | 5000 |
| `leviathan` | Criatura grande del fondo (zona 4); ~8x5x20 studs, boca al frente (-Z) | 5000 |

## Prioridad 2
| Id | Descripción | Tris máx |
| :-- | :-- | :-- |
| `creature_small` | Criatura pasiva/ambiental de zona 1 (no combate), ~1.5x1x3 studs | 2500 |
| `shipwreck_01` | Naufragio zona 1 (con zonas huecas para recorrer y puntos de aparición de tesoros: Attachments `TreasureSpawn`) | 5000 |
| `shipwreck_02` | Naufragio zonas 2–3, más dañado y oscuro, con `TreasureSpawn` | 5000 |
| `cave_kit` | Kit modular de cuevas (3–4 piezas encajables: recto, curva, cámara, bifurcación) con `TreasureSpawn` | 4000 c/u |
| `lamp` | Lámpara/linterna de buceo en casco (luz Spot al frente, tecla F) | 2500 |
| `diving_suit` | Traje/casco de buceo del jugador (referencia visual) | 5000 |

## Descartado
`harpoon`, `creature_medium` (combate eliminado). Si Codex ya tiene avance, se puede reutilizar `creature_medium` como base de `creature_hunter`.

## Lobby
Escena de lobby simple (puerto/muelle o hangar) con: mesa/terminal para crear/unirse a sala (`RoomTerminal`), spawn de jugadores y vista del submarino. ~Mapa pequeño, sin mecánicas de supervivencia.

## Referencias
* Mapa anterior: [banco de pruebas de Studio](game_designs/assets/test_map_spec.md). Para la nueva partida, ver [lugares de prueba](Launch.md) y [plan de desarrollo](docs/superpowers/plans/2026-11-11-abismo.md).
* UI pendiente: HUD (casco, profundidad, oxígeno, dinero común), pantalla de tienda/reparación (datos en `Config.Upgrades`, referencia funcional `ShopClient.client.luau`) y pantalla de lobby (crear/unirse por código).

Nota de aspecto (Claude): Lighting.Fog no se aplica dentro de agua de Terrain; la densidad se hace con Atmosphere. En pruebas la bruma afecta al agua/Terrain pero no desvanece Parts lejanos. Si el fondo marino final es Terrain, probablemente se vea más denso; avisar qué se usa.

## Estado de los archivos

Los FBX provisionales están en `assets_build/exports`. El casco exterior de `submarine` es referencia para A01. El `leviathan` necesita verificación de tamaño y orientación para A05. `lamp` y `shipwreck_01` son referencias para sus versiones nuevas. Hoja Coral tiene un FBX con rig y textura, y el clip fue probado en Studio. Su asignación a `creature_small` sigue pendiente.

## Contrato de nombres (Claude -> Codex)
Los scripts buscan por **nombre exacto** (sensible a mayúsculas) con `FindFirstChild(..., true)`. No renombrar. Los `ProximityPrompt`, `SurfaceGui` y sonidos los añade el script: el modelo solo aporta la parte o el Attachment donde van. Partes decorativas: `CanCollide = false`. Partes de control (zonas, puntos): transparentes, `CanCollide = false`, `Anchored = true`.

### Submarino (`Submarine`, Model)
| Nombre | Tipo | Uso |
| :-- | :-- | :-- |
| `Hull` | Part (PrimaryPart) | Pivote del submarino; el servidor lo mueve entre paradas. Origen en el centro del interior |
| `SpawnPoint1`…`SpawnPoint4` | Part | Dónde aparecen los 4 jugadores dentro |
| `InteriorZone` | Part (volumen) | Cubre todo el interior; dentro de él se recarga oxígeno y se considera "dentro del sub" |
| `Hatch` | Model | Compuerta |
| `Hatch.Door` | Part | Se abre/cierra por script (Tween) |
| `Hatch.InsidePrompt` | Attachment | "Salir" (lado interior) |
| `Hatch.OutsidePrompt` | Attachment | "Entrar" (lado exterior) |
| `Hatch.ExitPoint` | Attachment | Donde aparece el jugador al salir (fuera, frente a la puerta) |
| `Hatch.EntryPoint` | Attachment | Donde aparece al entrar (dentro) |
| `SellStation` | Model | Venta de tesoros |
| `ShopStation` | Model | Tienda |
| `RepairStation` | Model | Reparación del casco |
| `<Estación>.PromptAttachment` | Attachment | Para el ProximityPrompt (dentro de cada estación) |
| `HullGauge` | Model | Indicador de casco |
| `HullGauge.Screen` | Part (plana) | Superficie del SurfaceGui con casco/profundidad |
| `HullGauge.Fill` | Part | Barra que escala según el HP (opcional) |
| `Lights` | Folder | Luces interiores `InteriorLight1…N` (PointLight o parte Neon) y `AlarmLight` (parpadea al peligro) |

Medidas: interior para 4 avatares sin estorbar (≥ 14×8×10 studs). Colisión simple en suelo y paredes. Puerta ≥ 5 studs de ancho.

### Tesoros (`Treasure_Small`, `Treasure_Medium`, `Treasure_Large`, Model)
| Nombre | Tipo | Uso |
| :-- | :-- | :-- |
| `Handle` | Part/MeshPart (PrimaryPart) | Pieza que se sujeta y transporta; pivote en el centro |
| `GripPoint` | Attachment (en `Handle`) | Punto de agarre para la mano |
| `Glow` | Part Neon o PointLight (opcional) | Resalta el tesoro en la oscuridad |

El valor y el peso los asigna el script (no van en el modelo).

### Puntos de aparición (en naufragios y cuevas)
| Nombre | Tipo | Uso |
| :-- | :-- | :-- |
| `TreasureSpawn` | Attachment | Aquí aparece un tesoro. Atributo `Size` = `Small` / `Medium` / `Large` (poner en Studio) |
| `CreatureSpawn` | Attachment | Origen de una criatura |
| `Patrol1`…`PatrolN` | Attachment | Ruta de patrulla de criaturas, orden numérico |

### Mapas (`Workspace.Maps`, Folder) — propuesta 2026-11-11
Tres niveles de prueba y un mapa de parada. Cada uno es una carpeta/Model con al menos estos dos objetos:

| Mapa | Hijos mínimos |
| :-- | :-- |
| `Maps.Level_1`, `Maps.Level_2`, `Maps.Level_3` | `Platform` (Part base del nivel) y `SubDock` (Part donde el submarino se acopla; eje Z = frente) |
| `Maps.Parada` | `Platform` (base) y `SubDock` (donde se acopla el submarino; aquí nadie sale) |

Opcionales (para cuando se llenen los niveles): `Bounds` (volumen del nivel), `Wreck` (Model), `DepthMarker` (Attachment con atributo `Depth` en metros), y en `Level_3` el `BeaconSite` (Part). La compuerta (`Hatch.ExitPoint`) debe dar al área explorable del nivel; en `Parada` basta con una base.

### Baliza (`Beacon`, Model)
| Nombre | Tipo | Uso |
| :-- | :-- | :-- |
| `Base` | Part (PrimaryPart) | Pivote; Attachment `Base` en ella |
| `Light` | Part Neon | Cambia de color al activarse |
| `PromptAttachment` | Attachment | Para mantener `E` |

### Criaturas (`Hunter`, `Leviathan`, `SmallCreature`, Model)
| Nombre | Tipo | Uso |
| :-- | :-- | :-- |
| `Root` | Part (PrimaryPart) | Cuerpo principal / pivote; frente = -Z |
| `Hitbox` | Part invisible | Tamaño de colisión/captura |
| `Mouth` | Attachment | Punto de captura (en `Root`) |
| `EyeLight` | Part Neon o PointLight | Ojos (visibles en la oscuridad) |
| `AnimationController` + `Animator` | — | Animaciones nombradas `Idle`, `Swim`, `Attack` |

### Lobby (`Workspace.Lobby`, Model)
| Nombre | Tipo | Uso |
| :-- | :-- | :-- |
| `LobbySpawn1`…`LobbySpawn4` | Part | Aparición en el lobby |
| `RoomTerminal` | Model | Terminal de sala |
| `RoomTerminal.Screen` | Part (plana) | SurfaceGui con código y jugadores |
| `RoomTerminal.PromptAttachment` | Attachment | ProximityPrompt crear/unirse |
| `SubPreview` | Model | Submarino decorativo visible |

### Equipo del jugador (Accessory)
`Handle` en cada accesorio. Lámpara: Attachment `LampOrigin` en la parte delantera del casco/lámpara (de aquí nace la luz).

### Decisión de descenso y mapas (2026-11-11)
El submarino es una cabina sellada: el descenso es cierre de compuerta + fundido + teletransporte al `SubDock` siguiente, sin animación visible de viaje. Cada zona es un escenario independiente. Para Codex: cada `Level_N` debe esconder la caja del submarino en un **nicho o bahía de acoplamiento** (roca, estructura, muelle) alrededor de `SubDock`, con la compuerta (`Hatch.ExitPoint`) dando al área explorable. No hace falta tubo ni continuidad visual entre zonas.

### Escala del submarino (2026-11-11)
En Studio se aplicó `Submarine:ScaleTo(1.5)` a `submarine_A01_v2`: interior 22,3 × 12 × 29,1 studs, compuerta 9,3 × 9,6, cubierta 24 × 30,8. Los `SpawnPoint` se colocaron a 3 studs sobre la cubierta. Codex: al actualizar el modelo, usar estas medidas como base (escala 1.5 sobre la v2) para no repetir el ajuste.

### Cangrejo guardián (`Cangrejo`, Model)

- El [modelo de Studio](assets_build/exports/Cangrejo_v1_01.rbxmx) está listo para instalar en `ServerStorage.AbismoAssets.Creatures`. Conserva el `MeshPart` primario `Cangrejo_v1_01` y los clips `Caminar`, `Sorprender` y `Atrapar`. La mandíbula y las pinzas apuntan a `-Z` respecto al pivote del modelo.
- `GrabPoint` es un Attachment del `MeshPart`, centrado delante de las pinzas a 1,15 studs de altura y 4,05 studs por delante del pivote. La [fuente Blender](assets_build/exports/Cangrejo_v1_01.blend) incluye el marcador en `+Y` frontal.
- El [paquete de mapas](assets_build/exports/Abismo_Niveles_1-3.rbxmx) incluye `CrabLair`, `GuardZone`, `DeepZone`, `CrabDrop1…2` y `CrabPatrol1…4` en `Level_2` y `Level_3`. El lugar de pruebas aún usa los mapas provisionales. Quedan pendientes la instalación del modelo revisado y la prueba de captura en partida.
