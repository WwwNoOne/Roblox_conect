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
