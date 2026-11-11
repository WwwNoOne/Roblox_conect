# Estado de Abismo

Actualizado el 11 de noviembre de 2026. El [GDD vigente](game_designs/GDD.md) y el [manifiesto de Claude](creation_models.md) vienen del commit `7f93bf9`. El [plan de desarrollo](docs/superpowers/plans/2026-11-11-abismo.md) es la lista ordenada de tareas. Al cerrar una tarea, actualizar su casilla y registrar la prueba en esta página.

| Estado | Entrega | Responsable |
| --- | --- | --- |
| Disponible para pruebas | Puerto, agua, 11 marcadores y estaciones de luz a 8, 28 y 62 m en Studio | Codex |
| Probado en Studio | Niebla por profundidad, ciclo día/noche y reducción de densidad con la lámpara | Claude y Codex |
| Probado en Studio | Hoja Coral importado con textura y rig. Clip de 1,67 s reproducido con ID temporal. Publicación e integración como fauna ambiental pendientes | Codex y Claude |
| Referencia | FBX provisionales de submarino exterior, leviatán, lámpara y naufragio. El arpón se conserva como referencia histórica | Codex |
| Hecho (T01) | Arranque de Abismo en Rojo: `Shared/Remotes` + `Shared/Types` (forma de `UpdateHUD`), Bootstrap crea los remotos, prototipo (pesca, arpón, criaturas, DataStore, tienda) movido a `legacy/prototype` fuera de Rojo. `rojo build` pasa. Prueba con 2 clientes en Studio pendiente | Claude |
| Pendiente | T02 salas (`CreateRoom`/`JoinRoom`/`StartRun`), luego T03 partida (requiere A01) | Claude |
| Siguiente entrega artística | Submarino cúbico transitable con compuerta, indicador de casco y estaciones de venta, tienda y reparación | Codex |

El código base de Rojo y el prototipo anterior están en el worktree de Claude. Studio todavía ejecuta sus sistemas de pesca y guardado individual. La transición a la partida de Abismo comienza en las tareas T01–T03 del plan.

El [mapa de prueba anterior](game_designs/assets/test_map_spec.md) y el [plan histórico](docs/superpowers/plans/2026-11-10-ocean-depth-explorer.md) sirven como referencia del prototipo.
