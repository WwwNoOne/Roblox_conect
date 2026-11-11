# Estado de Abismo

<<<<<<< HEAD
## Contexto de la Sesión Actual
- **Proyecto:** Abismo — terror cooperativo de submarino estilo REPO (nuevo GDD 2026-11-11)
- **Fase actual:** Configuración inicial de UI y mallas 3D
- **Objetivo de hoy:** Implementar HUD de buceo (Claude) y modelar submarino/leviatán (Codex).
=======
Actualizado el 11 de noviembre de 2026. El [GDD vigente](game_designs/GDD.md) y el [manifiesto de Claude](creation_models.md) vienen del commit `7f93bf9`. El [plan de desarrollo](docs/superpowers/plans/2026-11-11-abismo.md) es la lista ordenada de tareas. Al cerrar una tarea, actualizar su casilla y registrar la prueba en esta página.
>>>>>>> main

| Estado | Entrega | Responsable |
| --- | --- | --- |
| Disponible para pruebas | Puerto, agua, 11 marcadores y estaciones de luz a 8, 28 y 62 m en Studio | Codex |
| Probado en Studio | Niebla por profundidad, ciclo día/noche y reducción de densidad con la lámpara | Claude y Codex |
| Probado en Studio | Hoja Coral importado con textura y rig. Clip de 1,67 s reproducido con ID temporal. Publicación e integración como fauna ambiental pendientes | Codex y Claude |
| Referencia | FBX provisionales de submarino exterior, leviatán, lámpara y naufragio. El arpón se conserva como referencia histórica | Codex |
| Pendiente | Migración de scripts del prototipo a salas y partidas de Abismo | Claude |
| Siguiente entrega artística | Submarino cúbico transitable con compuerta, indicador de casco y estaciones de venta, tienda y reparación | Codex |

<<<<<<< HEAD
## Bitácora de Avances
- [x] Estructura del repositorio creada.
- [x] UI de profundidad y oxígeno creada en Luau (`src/StarterPlayer/StarterPlayerScripts/DiveHud.client.luau`, pendiente de probar en Studio).
- [x] Mapa de prueba (puerto, agua, marcadores) por Codex; recorrido, oxígeno y DataStore verificados en Studio "The_FireBit".
- [x] Bucle de pesca (arpón, peces, tesoro, venta en puerto) con modelos provisionales; valores de prueba: pez 10, tesoro 50, inventario 10.
- [x] Criaturas hostiles (pequeña: mordisco 25%; mediana: agarra y deja al 50%; grande: agarra y mata), modelos provisionales.
- [x] Lámpara de buceo (tecla F, luz en la cabeza) y ciclo día/noche (10 min por día), provisionales.
- [x] Tienda de mejoras (tanque O2 x3, luz, arpón, traje de presión) + presión en zona profunda (>35 m sin traje); UI provisional.
- [x] Ajustes tras playtest: luz sigue la cámara (1ª/3ª persona), arpón con cable + jalón + indicador de listo en la punta, pequeñas 5% de daño y mueren de 1 arponazo (reaparecen a los 20 s).
- [x] Densidad del agua por profundidad (Atmosphere + color; la lámpara y su mejora reducen la densidad). Calibración fina pendiente de playtest.
- [ ] Modelo `.fbx` del submarino exportado desde Blender.

## Cambio de dirección (2026-11-11)
El GDD fue reescrito: lobby + salas 2–4, descenso por zonas, casco compartido con daño por presión, criaturas sin combate, economía común sin guardado, baliza al fondo. El código existente (arpón, DataStore, tienda individual) aún NO está adaptado; pendiente fase de migración.

## Próximo Hand-off
*Claude esperará a que Codex guarde `assets_build/exports/submarine.fbx` para enlazar la MeshPart en Roblox Studio.*
=======
El código base de Rojo y el prototipo anterior están en el worktree de Claude. Studio todavía ejecuta sus sistemas de pesca y guardado individual. La transición a la partida de Abismo comienza en las tareas T01–T03 del plan.

El [mapa de prueba anterior](game_designs/assets/test_map_spec.md) y el [plan histórico](docs/superpowers/plans/2026-11-10-ocean-depth-explorer.md) sirven como referencia del prototipo.
>>>>>>> main
