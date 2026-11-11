# GDD — Abismo (Terror cooperativo de submarino, estilo REPO)

> **Cambio de dirección (2026-11-11):** el juego pasa de supervivencia + historia a un **juego de terror cooperativo por partidas**, con lobby y salas. Se eliminan la historia larga, la economía persistente y el diseño de niveles extenso.

## 1. Concepto
De 2 a 4 jugadores descienden en un submarino lo más profundo posible, exploran naufragios y cuevas y recolectan tesoros. La presión daña el casco cuanto más profundo se va, y criaturas cazan a los jugadores. Si el casco llega a 0, el submarino implosiona y pierden. Si llegan al fondo y colocan la baliza, ganan y termina la partida.

## 2. Game Loop

1. **Lobby:** un jugador (host) crea una sala; los demás entran por código o invitación de amigos (2–4). El host inicia la partida.
2. **Descenso:** los jugadores aparecen dentro del submarino, que desciende por zonas.
3. **Exploración:** en cada zona, los jugadores salen en traje (oxígeno limitado) a naufragios y cuevas cercanos, recolectan tesoros (objetos) y regresan al submarino.
4. **Venta y mejora (parada entre niveles):** en el mapa de parada, sin salir del submarino, se venden los tesoros y el dinero común paga reparaciones y equipo con paneles interiores.
5. **Presión:** a mayor profundidad, mayor daño por segundo al casco. Sin dinero/reparaciones suficientes, el casco cae a 0 → **implosión → derrota de todos**.
6. **Final:** en la zona más profunda se coloca la **baliza** (mantener `E` varios segundos, con criaturas acechando). Al activarla → **victoria** y fin de la partida.

## 3. Mecánicas

### Submarino (casco compartido)
* Un solo valor de **Casco (HP)** para todo el equipo.
* Daño por presión por segundo = función de la profundidad (curva por zona; ver tabla de zonas). Puede mitigarse con mejoras de blindaje.
* Se repara con dinero común (y, opcional, con kit de reparación manual dentro del sub).
* Casco = 0 → implosión, fin de la partida (derrota).

### Descenso y estructura del mapa (decisión 2026-11-11)
* **Niveles separados**: cada zona es su propio escenario, sin conexión visual entre ellas.
* **Cabina sellada**: el submarino es una cabina. Para descender se cierra la compuerta (todos dentro), hay crujidos, vibración y fundido a negro, y el servidor lleva el submarino al `SubDock` de la siguiente zona. Los jugadores no ven el exterior durante el viaje.
* En cada parada el submarino queda acoplado en un nicho/bahía de roca o estructura, para que desde fuera no se aprecie como una caja.
* Mejora opcional futura: tubo conector entre niveles (híbrido) sin cambiar la lógica, porque cada nivel ya tiene su `SubDock`.

### Niveles y paradas (decisión 2026-11-11)
Para la primera versión de prueba hay **3 niveles** y un mapa de **parada** compartido (`Parada`). Secuencia: **Nivel 1 → Parada → Nivel 2 → Parada → Nivel 3 (final, baliza)**.

* **Niveles:** el submarino se acopla en el `SubDock` del nivel; la compuerta se abre y los jugadores salen a explorar, recoger tesoros y volver. La presión daña el casco mientras el submarino está en un nivel o viaja.
* **Parada:** mapa vacío con solo una base donde se acopla el submarino. **Nadie sale**: se vende, repara y compra desde dentro con los paneles (`SellStation`, `RepairStation`, `ShopStation`). La compuerta permanece cerrada. Propuesta: el casco no recibe presión durante la parada (refugio seguro), a calibrar.
* Se baja de nivel a parada, o de parada a nivel, con el mismo descenso de cabina sellada (todos dentro, compuerta cerrada, fundido, teletransporte).
* Al terminar el Nivel 3 la partida acaba con la baliza (no hay parada final).

| Nivel | Profundidad (prueba) | Presión (daño/s al casco) | Contenido |
| :-- | :-- | :-- | :-- |
| 1 | ~40 m | Muy baja | Naufragio inicial, criaturas pasivas/lentas |
| 2 | ~120 m | Media | Naufragios y cuevas, primera criatura cazadora |
| 3 (fondo) | ~220 m | Alta | Cuevas, oscuridad, cazadores agresivos, criatura grande y sitio de la baliza |
*(Valores numéricos a calibrar en playtest. Más niveles se añaden con el mismo esquema.)*

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
