# Modelos requeridos (hand-off Claude -> Codex)
Estilo Low-Poly / Anime Stylized. Export `.fbx` a `assets_build/exports/`.
| Id | Descripción | Tris máx |
| :-- | :-- | :-- |
| `submarine` | Submarino del jugador (puerto/entrada a inmersión) | 5000 |
| `leviathan` | Criatura grande (agarra y mata); ~8x5x20 studs, boca en el frente (-Z) | 5000 |
| `harpoon` | Arpón (Tool). Debe incluir: punta (parte "Tip", Neon; el servidor la pone verde=listo / roja=recarga) y un Attachment "RopeStart" en la punta para el cable | 2500 |
| `lamp` | Lámpara de buceo montada en la cabeza/casco (luz Spot al frente, tecla F) | 2500 |
| `creature_small` | Criatura pequeña (muerde); ~1.5x1x3 studs | 2500 |
| `creature_medium` | Criatura mediana (agarra); ~3x2.5x8 studs | 5000 |
| `shipwreck_01` | Naufragio de la zona 1 | 5000 |

Mapa de prueba: ver `game_designs/assets/test_map_spec.md` (medidas e IDs de marcadores).

UI pendiente para Codex: pantalla de tienda final (ver `src/StarterPlayer/StarterPlayerScripts/ShopClient.client.luau` como referencia funcional; datos en `Config.Upgrades`), y modelos `shop_station` / `sell_station` para el puerto.

Nota de aspecto (Claude): Lighting.Fog no se aplica dentro de agua de Terrain; la densidad se hace con Atmosphere. En pruebas la bruma afecta al agua/Terrain pero no desvanece Parts lejanos (el fondo de prueba es un Part). Si el fondo marino final es Terrain, probablemente se vea más denso; por favor avisar qué se usa.
