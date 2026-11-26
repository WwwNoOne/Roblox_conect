# Plan de desarrollo (Backrooms Coop)

> Plan inicial tras el cambio de temática. Las tareas dependen de definiciones pendientes del GDD. Marcar casillas y anotar pruebas en [arranque.md](../arranque.md).

| Estado | ID | Depende de | Entrega | Prueba de aceptación |
| --- | --- | --- | --- | --- |
| [x] | T01 | — | **Claude.** Limpiar código: retirar agua, oxígeno, presión, casco, profundidad y fauna marina. Cambiar nadar rápido por correr (`Shift`). | `rojo build` pasa; no quedan referencias oceánicas (`grep`). |
| [x] | T01b | T01 | **Claude.** Movimiento realista en primera persona, sonido de movimiento, HUD de supervivencia y escala única de avatar. Detalle: [movimiento_sonido_hud.md](movimiento_sonido_hud.md). | Verificado en Play (2026-11-25): sprint a 34 con estamina, cámara estable, pasos por superficie, HUD. |
| [ ] | A01 | — | **Codex.** Re-exportar el Ascensor con los nombres del manifiesto. | Nombres, escala y colisiones verificados en Studio. |
| [ ] | A02 | — | **Codex.** `Level_1` y `Parada` con los puntos del manifiesto. | Recorrido desde `Gate.ExitPoint` a tesoros y máquinas. |
| [ ] | A03 | — | **Codex.** `machine_comm`, `puzzle_door`, `puzzle_chest`. | Nombres y Attachments verificados. |
| [ ] | T02 | T01 | **Claude.** Salas, estado de partida y traslado entre niveles con `ElevatorDock`. | Dos clientes llegan al mismo nivel. |
| [x] | T03 | T02, A03 | **Claude.** Generadores (calibración), cajas fuertes (dial) y puertas con panel de interruptores, servidor autoritativo; bajar exige energía. Detalle: [objetivos_nivel.md](objetivos_nivel.md). | Verificado en Play con 1 cliente (2026-11-25) y con 2 clientes (2026-11-26). Falta repetir con 4. |
| [ ] | T04 | T02 | **Claude.** Tesoros, venta y tienda con fondo común. | Un tesoro paga una sola vez. |
| [~] | T05 | T03 | **Claude + Codex.** Criaturas 2.5D (Agresivo, Acosador, Acechador con screamer 2D), navegación sobre mapas fijos (`LevelState.nav`), puertas cerradas como obstáculo y `Noise.Emitted`. Detalle: [criaturas.md](criaturas.md). | Verificado en Play con 1 cliente (2026-11-26): aparición, persecución letal, emboscada + screamer, Acosador (delata/huye). Falta ruido, escondites y 2+ clientes. |
| [x] | A02b | T05 | **Claude.** Level_1 y Level_2 rehechos con generador (`tools/levelgen`): 840-864 studs, pasillos en raíz/grafo, segundo piso, naves con pasarela, colinas, casas del árbol, escondites (taquilla/arbusto/armario) con vista desde dentro, noche y niebla por nivel, límites 2.5D. Detalle: [niveles_generados.md](niveles_generados.md). | Verificado en Play (2026-11-26): partida en Level_1, escalera al 2.º piso, taquilla, criaturas moviéndose; navegación 95-100 % conectada en ambos mapas. Falta recorrer Level_2 en una partida completa. |
| [x] | A02c | A02b | **Claude.** Cuatro biomas más con marco de arquitectura (`tools/levelgen/arch.py`): Level_3 Hospital, Level_4 Escuela, Level_5 Mansión, Level_6 Centro comercial (final con baliza). Etapas, música y perfiles de noche y niebla en Config. Detalle: [niveles_generados.md](niveles_generados.md). | Verificado (2026-11-26): los cuatro generan y validan alcanzabilidad; navegación 97-99,7 % conectada; partida de prueba en Level_3 con criaturas moviéndose por varias plantas. Falta recorrer L4-L6 en partida completa. |
