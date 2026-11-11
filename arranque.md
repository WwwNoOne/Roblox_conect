# Estado de Abismo

Actualizado el 11 de noviembre de 2026. El [GDD vigente](game_designs/GDD.md) y el [manifiesto de Claude](creation_models.md) vienen del commit `7f93bf9`. El [plan de desarrollo](docs/superpowers/plans/2026-11-11-abismo.md) es la lista ordenada de tareas. Al cerrar una tarea, actualizar su casilla y registrar la prueba en esta página.

| Estado | Entrega | Responsable |
| --- | --- | --- |
| Disponible para pruebas | Puerto, agua, 11 marcadores y estaciones de luz a 8, 28 y 62 m en Studio | Codex |
| Probado en Studio | Niebla por profundidad, ciclo día/noche y reducción de densidad con la lámpara | Claude y Codex |
| Probado en Studio | Hoja Coral importado con textura y rig. Clip de 1,67 s reproducido con ID temporal. Publicación e integración como fauna ambiental pendientes | Codex y Claude |
| Referencia | FBX provisionales de submarino exterior, leviatán, lámpara y naufragio. El arpón se conserva como referencia histórica | Codex |
| Hecho (T01) | Arranque de Abismo en Rojo: `Shared/Remotes` + `Shared/Types` (forma de `UpdateHUD`), Bootstrap crea los remotos, prototipo (pesca, arpón, criaturas, DataStore, tienda) movido a `legacy/prototype` fuera de Rojo. `rojo build` pasa. Probado en Studio "The_FireBit" (137133016631933) con 1 cliente en Play: los 11 remotos existen y el HUD muestra `Casco: --`; la prueba con 2 clientes (Server & Clients) sigue pendiente | Claude |
| Hecho salvo terminal (T02) | `Rooms.luau` + `RoomHandlers.server.luau`: código de 4 caracteres, cupo 4, anfitrión, traspaso al desconectarse, `RoomUpdate`. Probado en Studio (lógica con IDs simulados: código inválido, sala inexistente, 5.º jugador, inicio por no anfitrión, traspaso de anfitrión, unirse tras iniciar). Falta conectar `RoomTerminal` (A02) y probar con 2 clientes reales | Claude |
| Hecho salvo prueba con modelo (T03) | `Runs.luau` + `RunHandlers.server.luau`: estado de partida (casco, profundidad, dinero común, parada), descenso entre paradas (`RequestDescend`, solo anfitrión, exige tripulación dentro de `InteriorZone`), presión interpolada por profundidad, implosión una sola vez, `UpdateHUD` unificado (oxígeno personal + datos de partida). Probado en Studio con 1 cliente: descenso 0→40→120 m, casco baja, errores `NO_RUN`/`NOT_AT_STOPOVER`, implosión emite `RunEnded` una vez. Falta: insertar `submarine_A01_v2.rbxmx`, crear `Workspace.Zones.Zone_N.SubDock` (A04) y probar con 2 clientes. Valores de `Config.Run` son de prueba | Claude |

Nota de Studio: este lugar ya tiene los scripts de Abismo copiados a mano (sin Rojo); se eliminaron los scripts del prototipo viejo del lugar.
| Siguiente entrega artística | Submarino cúbico transitable con compuerta, indicador de casco y estaciones de venta, tienda y reparación | Codex |

El código base de Rojo y el prototipo anterior están en el worktree de Claude. Studio todavía ejecuta sus sistemas de pesca y guardado individual. La transición a la partida de Abismo comienza en las tareas T01–T03 del plan.

El [mapa de prueba anterior](game_designs/assets/test_map_spec.md) y el [plan histórico](docs/superpowers/plans/2026-11-10-ocean-depth-explorer.md) sirven como referencia del prototipo.

## T04 · Compuerta, oxígeno y descenso sellado (Claude)

- `SubmarineService.server.luau`: `ProximityPrompt` "Salir"/"Entrar" en los Attachments `InsidePrompt`/`OutsidePrompt`; teletransporte a `ExitPoint`/`EntryPoint`; la puerta se abre solo en parada y se cierra al descender (tween entre `DoorClosed` y `DoorOpen`). `DescentFx.client.luau`: vibración y fundido a negro. Remoto nuevo `DescentFx`.
- Oxígeno: en partida se consume fuera de `InteriorZone` y se recarga dentro (30 s/s, valor de prueba); fuera de partida siempre está lleno.
- Probado en Studio (lugar 137133016631933, 1 cliente, submarino v2 escalado 1,5): salir y entrar por la compuerta, oxígeno 358,4 → 354,2 en 4 s fuera y 354,2 → 360 en 3 s dentro, prompts desactivados durante el viaje, efectos `Start`/`End`. Pendiente: cuatro clientes, pruebas táctiles, respawn/espectador (T06) y sonidos del efecto.
- Los `ExitPoint`/`EntryPoint` quedan 1,5 studs más altos tras el escalado; el jugador cae sin daño. Codex puede bajarlos en la próxima versión.

## Niveles y Parada en el código (Claude, T03/T04 adaptados)

- `Config.Run.Stages`: Nivel 1 (40 m) → Parada (80) → Nivel 2 (120) → Parada (170) → Nivel 3 (220). Presión 0,1 / 0 / 0,5 / 0 / 1,2 daño/s (valores de prueba). La Parada no daña el casco.
- Estados de partida: `Descending` (viaje sellado), `Level` (compuerta abierta, se explora), `Stopover` (Parada: compuerta cerrada, nadie sale). El submarino se acopla en `Workspace.Maps.<Map>.SubDock`.
- Probado en Studio (1 cliente): recorrido completo L1 → Parada → L2 → Parada → L3; acople correcto en cada `SubDock`; compuerta y prompt abiertos solo en niveles; casco sin cambio durante la Parada (99 → 99); `RequestDescend` desde Parada funciona y en el Nivel 3 devuelve `ALREADY_AT_BOTTOM`; al salir en el Nivel 3 el jugador queda dentro de `Bounds` sobre una superficie estable.
- Pendiente: T05 (paneles interiores de venta/reparación/tienda en la Parada), T06 (baliza en `Level_3.BeaconSite`, espectador, derrota), pruebas con 2 y 4 clientes.

## T05 · Tesoros, venta, reparación y tienda (Claude)

- `Economy.luau` (lógica) + `EconomyHandlers.server.luau` (mundo y remotos) + `ShopClient.client.luau` (panel provisional). Valores en `Config.Economy` (de prueba).
- Tesoros: aparecen en los `TreasureSpawn` (atributo `Size`) del nivel al entrar en estado `Level`; se recogen con `E` (peso máx. 6: Small 1, Medium 2, Large 4; valores 25/75/200). Se usan piezas Neon provisionales; si existe `ServerStorage.Models.Treasure_<Size>` (Model con `PrimaryPart`) se usa en su lugar. Los tesoros no recogidos se limpian al partir.
- Paneles (solo activos en la Parada y con el jugador dentro): `SellStation` vende todo lo cargado, `RepairStation` repara +10 HP por uso (2 $/HP), `ShopStation` abre el panel (Blindaje del casco: −20 % presión por nivel, 3 niveles; Tanque de oxígeno: +60 s por nivel, 3 niveles). Remotos `SellTreasure` y `RequestPurchase` (`"Repair"` o id de mejora) usan el mismo camino validado en servidor.
- Probado en Studio (1 cliente, submarino en los 3 mapas de Codex): vender en nivel → `NOT_AT_PARADA`; recoger 3 tesoros (carga 4/6); venta única (+125, segunda venta `NOTHING_TO_SELL`); reparación (cobra al 2 $/HP; segunda `HULL_FULL`); compra de oxígeno (máx. 360 → 420); `NOT_ENOUGH_MONEY`; `UNKNOWN_ITEM`; sobrepeso rechazado con aviso; el dinero vuelve a 0 al empezar otra partida (estado nuevo por `Runs.Start`).
- Pendiente: dos reparaciones simultáneas con dos clientes reales, soltar la carga al morir (T06), modelos `Treasure_*` de A03 y UI final de la tienda (Codex).

## T05b · Slots, depósito y cuota (Claude)

- Slots: 4 por jugador (`CarryCount`/`CarryCapacity`); sustituye al límite por peso. Remoto `SellTreasure` renombrado a `DepositTreasure`.
- `SellStation` ahora **deposita** durante un nivel (`Level`); `RepairStation` y `ShopStation` solo en la Parada. Al partir se paga: cuota cumplida = depositado + 50 % de la cuota; fallida = 75 % de lo depositado y +1 fallo; lo no depositado se pierde; 2 fallos = `Lost / QuotaFailed`. Cuotas de prueba: Nivel 1 = 100, Nivel 2 = 200 (`Config.Run.Stages`, `Config.Economy.Quota`). El HUD muestra `Cuota depositado/cuota` y `Fallos`.
- Probado en Studio (1 cliente): depósito, pago 125 → +$175 con extra $50, `NOT_AT_PARADA` al reparar en nivel, fallo 1/2 con $0 y 2 objetos perdidos, y derrota al 2.º fallo (`RunEnded Lost/QuotaFailed` una vez; luego `NO_RUN`).
- Pendiente: curas y daño de criaturas (T07), soltar objetos al morir (T06), calibrar cuotas con partidas reales (T08).

## T06 · Baliza, espectador y final de partida (Claude)

- `BeaconService.server.luau`: en el Nivel 3 (`Beacon = true` en `Config.Run.Stages`) aparece la baliza en `Level_3.BeaconSite`. Si existe `Maps.Level_3.Beacon` (Model con `Light` y `PromptAttachment`) se usa; si no, una baliza provisional. Se activa manteniendo `E` (`Config.Run.BeaconHoldSeconds`, 5 s en el repo): soltar o alejarse la interrumpe (lo hace el `ProximityPrompt`). Al activarla: `Won / Beacon`, la luz pasa a verde. Se eliminó el remoto `PlaceBeacon` (innecesario).
- Muerte: el jugador muerto no reaparece durante la partida (`Players.RespawnTime` bloqueado), pierde lo que cargaba y pasa a espectador (`SpectatorClient`: Q/E o botones `<` `>` para cambiar de compañero vivo). Todos muertos = `Lost / AllDead`. Atributos de jugador `InRun` y `RunAlive`.
- Fin: `RunEndClient` muestra VICTORIA/DERROTA y el motivo; tras `EndScreenSeconds` (8 s) la partida se cierra, los muertos reaparecen, la sala vuelve a `Lobby` y el host puede iniciar otra (el submarino vuelve a su posición inicial).
- Arreglo: `StartRun` ya no se descarta tras `CreateRoom`/`JoinRoom` (enfriamiento por acción).
- Probado en Studio (1 cliente): partida completa L1→L3 con cuotas cumplidas (dinero 575); soltar la baliza antes de tiempo no gana; una pulsación completa (1 s) gana una sola vez y la luz pasa a verde; muerte → `RunAlive=false`, pantalla DERROTA / AllDead, tras el cierre reaparece, la sala vuelve a Lobby y la nueva partida empieza con dinero 0 y casco 100.
- **No verificado:** pulsación completa de 3 s con `InputHoldBegin` (el simulador de Studio no completó ninguna espera ≥ 3 s, ni siquiera en prompts de tesoros). Verificar a mano en Studio con teclado real. Tampoco se probó el espectador con compañeros vivos (requiere 2 clientes).
- Pendiente: la prueba con 2 y 4 clientes (V01), modelo `Beacon` de Codex.

## Flotabilidad neutra (Claude)

- `SwimClient.client.luau`: al nadar sin dar órdenes el jugador se queda quieto en vez de subir. Moverse nada hacia donde mira la cámara, `Espacio`/saltar sube y `Ctrl` o `C` baja (16 studs/s). Se desactiva con el atributo de jugador `NeutralBuoyancy = false`.
- Probado en Studio (Nivel 1, agua de Terrain): sin el script el jugador sube 8 studs en 3 s; con él, 0,4. El movimiento y el salto siguen funcionando.
- No cambia el comportamiento dentro del submarino fuera del agua (Parada, interior seco).
