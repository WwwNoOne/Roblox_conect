# Criaturas (enemigos y fauna)

> **2026-11-18:** el **cangrejo guardián, la mandíbula radial y el Pez Pelícano se eliminaron** (código, configuración y modelos; respaldo de los modelos en `ServerStorage.Respaldo_Criaturas_Obsoletas`). Los enemigos del laberinto son las 5 especies de `Config.Monster.Species` (anguila, rape, medusa, isópodo, tiburón duende) gestionadas por `MonsterService`:
> **patrulla** por la red de pasillos → **detecta** (vista con línea de visión, oído; más lejos si haces ruido con el dash) → **persigue** adelantándose a tu movimiento y avisando a los demás → **zarpazo en 3 fases**: *Windup* (0,25-0,5 s, se frena y te encara: tu margen para esquivar), *Lunge* (embestida a 44-56 studs/s que daña a quien toque su cuerpo) y *Recover* (queda lento ~1 s) → si te pierde, **rastrea** la zona 10 s. Colisiona con las paredes (esferas de cuerpo) y se desliza en vez de atravesarlas. Parámetros y comentarios en `Config.Monster`.

Parámetros en `src/ReplicatedStorage/Shared/Config.luau` (`Config.Monster`, `Config.Kraken`, `Config.Ambient`). Todas las plantillas están en `ServerStorage.AbismoAssets.Creatures` (peces en `ReplicatedStorage.AmbientFauna`). Todos los enemigos ignoran a los jugadores **dentro del submarino** (`InteriorZone`) y son **más lentos que el nado del jugador (20 studs/s)**, salvo el dash.

| Criatura | Servicio | Rol y comportamiento | Velocidades (studs/s) | Daño |
| :-- | :-- | :-- | :-- | :-- |
| **Kraken abisal** (jefe) | `KrakenService` + `KrakenClient` | Mide 70 de alto (`Kraken.Length`). Ronda por la sala grande; detecta a 160 (×1,3 con lámpara); **te agarra con un tentáculo y te mata a los 2,5 s**, y se aleja 5 s. Postura casi siempre erguida (tentáculos hacia abajo, nunca hacia arriba) y a veces horizontal. Esquiva paredes con 3 esferas a lo largo del cuerpo + colisión dura. Animación de huesos por código en el cliente (tentáculos, aletas, barbillas) | pasear 9 · perseguir 16 | letal (agarre) |
| Fauna ambiental | `AmbientFauna.client` (+ `AmbientRoutesService`) | Peces en cardúmenes (cliente); gigantes por rutas (en desuso tras borrar los niveles) | — | ninguno |


## Giro de diseño (2026-11-15)
El juego pasa a laberinto con un **enemigo principal agresivo**, nuevo modelo del usuario: caza de forma constante por todo el laberinto (no se queda en una sala), navega por el grafo de piezas y no ve a quien está escondido salvo muy cerca. Los parámetros del kraken (`Config.Kraken`) sirven de plantilla. Cangrejos y mandíbulas siguen desactivados y se decidirá si vuelven. Ver `Generacion_Cuevas.md` §0.

## Notas
- El kraken (44 de ancho a escala 1, ~30 a escala 0,7) **no está pensado para los pasillos**; se queda en su sala. El pasillo mide 60 × 60.
- Hoy los tres servicios se activan con las etapas de `Config.Run.Stages` y buscan el mapa en `Workspace.Maps.<Nivel>`; hay que adaptarlos a las salas del generador (ver `Generacion_Cuevas.md` §8). `Config.Run.Stages` aún pone `Crab`, `Kraken` y `Mandibula` en el antiguo `Level_2`.
- Los jefes futuros (3 más) irán cada uno con su sala grande.
- Animaciones: en Studio se registran con `KeyframeSequenceProvider`; en el juego publicado hay que publicarlas como `Animation` (no verificado).
