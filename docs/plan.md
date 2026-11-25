# Plan de desarrollo (Backrooms Coop)

> Plan inicial tras el cambio de temática. Las tareas dependen de definiciones pendientes del GDD. Marcar casillas y anotar pruebas en [arranque.md](../arranque.md).

| Estado | ID | Depende de | Entrega | Prueba de aceptación |
| --- | --- | --- | --- | --- |
| [x] | T01 | — | **Claude.** Limpiar código: retirar agua, oxígeno, presión, casco, profundidad y fauna marina. Cambiar nadar rápido por correr (`Shift`). | `rojo build` pasa; no quedan referencias oceánicas (`grep`). |
| [ ] | A01 | — | **Codex.** Re-exportar el Ascensor con los nombres del manifiesto. | Nombres, escala y colisiones verificados en Studio. |
| [ ] | A02 | — | **Codex.** `Level_1` y `Parada` con los puntos del manifiesto. | Recorrido desde `Gate.ExitPoint` a tesoros y máquinas. |
| [ ] | A03 | — | **Codex.** `machine_comm`, `puzzle_door`, `puzzle_chest`. | Nombres y Attachments verificados. |
| [ ] | T02 | T01 | **Claude.** Salas, estado de partida y traslado entre niveles con `ElevatorDock`. | Dos clientes llegan al mismo nivel. |
| [ ] | T03 | T02, A03 | **Claude.** Reparación de máquinas y puzzles (servidor autoritativo). **[POR DEFINIR]** mecánicas. | Estado consistente con 2 y 4 clientes. |
| [ ] | T04 | T02 | **Claude.** Tesoros, venta y tienda con fondo común. | Un tesoro paga una sola vez. |
| [ ] | T05 | definición | **Claude + Codex.** Criaturas nextbot. **[POR DEFINIR]** | — |
