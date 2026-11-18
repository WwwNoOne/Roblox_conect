# Criaturas (enemigos y fauna)

Parámetros en `src/ReplicatedStorage/Shared/Config.luau` (`Config.Crab`, `Config.Kraken`, `Config.Mandibula`, `Config.Ambient`). Todas las plantillas están en `ServerStorage.AbismoAssets.Creatures` (peces en `ReplicatedStorage.AmbientFauna`). Todos los enemigos ignoran a los jugadores **dentro del submarino** (`InteriorZone`) y son **más lentos que el nado del jugador (20 studs/s)**, salvo el dash.

| Criatura | Servicio | Rol y comportamiento | Velocidades (studs/s) | Daño |
| :-- | :-- | :-- | :-- | :-- |
| **Cangrejo guardián** | `CrabService` | Necesita suelo. Cada partida se sortean `Crab.PlatformCount` (3) plataformas (`H-<n>`; en el nuevo sistema, `CrabPlatform`) y en cada una vive un cangrejo que patrulla su plataforma. Detecta a 45 (×1,5 con lámpara), se sorprende, persigue, **agarra y arrastra** al jugador hacia un `CrabDrop` (o la esquina más lejana de `Bounds`) y lo suelta con 6 s de inmunidad | pasear 4 · perseguir 12 · llevar 14 | 20 en total durante el traslado |
| **Mandíbula radial** | `MandibulaService` | 3 a la vez (`Mandibula.Count`) rondan todo el mapa (puntos al azar dentro de `Bounds`, lejos del submarino). Detecta a 90 (×1,4 con lámpara), persigue y **muerde**; luego se aleja 2,5 s. Cabeza hacia −Z; animaciones Swim/Attack | pasear 11 · perseguir 18 | 20 por mordisco (2 s de enfriamiento) + empujón |
| **Kraken abisal** (jefe) | `KrakenService` + `KrakenClient` | Mide 70 de alto (`Kraken.Length`). Ronda por la sala grande; detecta a 160 (×1,3 con lámpara); **te agarra con un tentáculo y te mata a los 2,5 s**, y se aleja 5 s. Postura casi siempre erguida (tentáculos hacia abajo, nunca hacia arriba) y a veces horizontal. Esquiva paredes con 3 esferas a lo largo del cuerpo + colisión dura. Animación de huesos por código en el cliente (tentáculos, aletas, barbillas) | pasear 9 · perseguir 16 | letal (agarre) |
| Fauna ambiental | `AmbientFauna.client` (+ `AmbientRoutesService`) | Peces en cardúmenes (cliente); gigantes por rutas (en desuso tras borrar los niveles) | — | ninguno |

| **Pez Pelícano Abisal** (enemigo principal) | `MonsterService` | Patrulla el laberinto por la red de pasillos y, al detectarte (vista con línea de visión 80, oído 14, escondido solo a ≤ 5), **corre hacia ti**; muerde a ≤ 8. Cinemático (sin colisión) | patrullar 10 · correr **24** | 50 por mordisco (2 s de enfriamiento) |

## Giro de diseño (2026-11-15)
El juego pasa a laberinto con un **enemigo principal agresivo**, nuevo modelo del usuario: caza de forma constante por todo el laberinto (no se queda en una sala), navega por el grafo de piezas y no ve a quien está escondido salvo muy cerca. Los parámetros del kraken (`Config.Kraken`) sirven de plantilla. Cangrejos y mandíbulas siguen desactivados y se decidirá si vuelven. Ver `Generacion_Cuevas.md` §0.

## Notas
- El kraken (44 de ancho a escala 1, ~30 a escala 0,7) **no está pensado para los pasillos**; se queda en su sala. El pasillo mide 60 × 60.
- Hoy los tres servicios se activan con las etapas de `Config.Run.Stages` y buscan el mapa en `Workspace.Maps.<Nivel>`; hay que adaptarlos a las salas del generador (ver `Generacion_Cuevas.md` §8). `Config.Run.Stages` aún pone `Crab`, `Kraken` y `Mandibula` en el antiguo `Level_2`.
- Los jefes futuros (3 más) irán cada uno con su sala grande.
- Animaciones: en Studio se registran con `KeyframeSequenceProvider`; en el juego publicado hay que publicarlas como `Animation` (no verificado).
