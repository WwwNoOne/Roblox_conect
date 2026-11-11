# GDD — Abismo (Terror cooperativo de submarino, estilo REPO)

> **Cambio de dirección (2026-11-11):** el juego pasa de supervivencia + historia a un **juego de terror cooperativo por partidas**, con lobby y salas. Se eliminan la historia larga, la economía persistente y el diseño de niveles extenso.

## 1. Concepto
De 2 a 4 jugadores descienden en un submarino lo más profundo posible, exploran naufragios y cuevas y recolectan tesoros. La presión daña el casco cuanto más profundo se va, y criaturas cazan a los jugadores. Si el casco llega a 0, el submarino implosiona y pierden. Si llegan al fondo y colocan la baliza, ganan y termina la partida.

## 2. Game Loop

1. **Lobby:** un jugador (host) crea una sala; los demás entran por código o invitación de amigos (2–4). El host inicia la partida.
2. **Descenso:** los jugadores aparecen dentro del submarino, que desciende por zonas.
3. **Exploración:** en cada zona, los jugadores salen en traje (oxígeno limitado) a naufragios y cuevas cercanos, recolectan tesoros (objetos) y regresan al submarino.
4. **Venta y mejora (parada entre zonas):** los tesoros se venden en el submarino; el dinero común paga reparaciones del casco y equipo.
5. **Presión:** a mayor profundidad, mayor daño por segundo al casco. Sin dinero/reparaciones suficientes, el casco cae a 0 → **implosión → derrota de todos**.
6. **Final:** en la zona más profunda se coloca la **baliza** (mantener `E` varios segundos, con criaturas acechando). Al activarla → **victoria** y fin de la partida.

## 3. Mecánicas

### Submarino (casco compartido)
* Un solo valor de **Casco (HP)** para todo el equipo.
* Daño por presión por segundo = función de la profundidad (curva por zona; ver tabla de zonas). Puede mitigarse con mejoras de blindaje.
* Se repara con dinero común (y, opcional, con kit de reparación manual dentro del sub).
* Casco = 0 → implosión, fin de la partida (derrota).

### Zonas (3–4, con parada entre ellas)
| Zona | Profundidad | Presión (daño/s al casco) | Contenido |
| :-- | :-- | :-- | :-- |
| 1 | 0–50 m | Muy baja | Naufragio inicial, criaturas pasivas/lentas |
| 2 | 50–150 m | Baja-media | Naufragios y cuevas, primera criatura cazadora |
| 3 | 150–300 m | Alta | Cuevas, oscuridad total, cazadores más agresivos |
| 4 (fondo) | 300 m+ | Muy alta | Sitio de la baliza, criatura grande |
*(Valores numéricos a calibrar en playtest.)*

### Exploración fuera del submarino
* Los jugadores salen con traje: **oxígeno limitado** (regresa al sub para recargar).
* Linterna/lámpara de buceo (`F`); la oscuridad aumenta con la profundidad.
* Recolectan **tesoros** (objetos con valor y peso); capacidad limitada de carga.

### Terror y criaturas (sin combate)
* **No hay arma de combate.** Se sobrevive huyendo, escondiéndose, apagando luz y evitando hacer ruido.
* Las criaturas **cazan** por vista/sonido/luz; si atrapan a un jugador lo matan (o lo arrastran).
* Criatura grande en el fondo como amenaza final.

### Economía (solo dentro de la partida)
* **Fondo común** del equipo: vender tesoros en el submarino.
* Gasto: reparar casco, comprar equipo (más oxígeno, mejor luz, blindaje, etc.).
* El dinero **no se guarda** entre partidas.

### Muerte y derrota
* Jugador muerto → **espectador** (observa a los vivos). Revivir con ítem: opcional/futuro.
* **Fin de partida:** derrota si el casco implosiona (o todos mueren); victoria si se activa la baliza.

### Controles
* **Cámara:** primera y tercera persona.
* **PC:** `WASD` mover, `Espacio` nadar arriba, `E` interactuar, `F` linterna.
* **Mobile:** joystick táctil + botones en pantalla.

## 4. Arquitectura de Datos & Eventos (Roblox Spec)

### Estado de sala/partida (en memoria, por servidor/sala)
| Variable | Tipo | Descripción |
| :-- | :-- | :-- |
| `RoomCode` | string | Código de la sala |
| `Players` | list | 2–4 jugadores |
| `HullHP` | number | Vida del casco |
| `Depth` | number | Profundidad actual del submarino |
| `TeamMoney` | number | Dinero común |
| `State` | enum | Lobby / Descending / Stopover / Won / Lost |

### Leaderstats (opcional)
* Ninguno obligatorio; el HUD muestra profundidad, casco, oxígeno y dinero común.

### DataStore
* **Sin guardado de economía.** (Opcional futuro: cosméticos/estadísticas mínimas, p. ej. partidas ganadas.)

### Eventos Cliente-Servidor
* `CreateRoom` / `JoinRoom` (RemoteFunction): lobby y unión por código.
* `StartRun` (RemoteEvent): el host inicia la partida.
* `RequestPurchase` (RemoteFunction): cliente solicita compra/reparación → el servidor valida con el fondo común.
* `SellTreasure` (RemoteFunction): vender tesoros en el submarino.
* `UpdateHUD` (RemoteEvent): casco, profundidad, oxígeno, dinero.
* `PlaceBeacon` (RemoteEvent): activar baliza en el fondo.
* `RunEnded` (RemoteEvent): victoria/derrota.

## 5. Alcance (qué se elimina)
Historia larga, economía persistente, progresión por niveles, combate con arpón, mapa grande de supervivencia. Se mantiene: oxígeno, lámpara, día/noche (opcional), densidad del agua por profundidad, tienda de mejoras (adaptada a fondo común).
