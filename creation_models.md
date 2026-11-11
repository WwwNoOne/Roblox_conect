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
