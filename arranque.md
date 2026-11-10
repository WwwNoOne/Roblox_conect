# Estado de Arranque y Sincronización de Agentes

## Contexto de la Sesión Actual
- **Proyecto:** Roblox Ocean Exploration / Submarine Game
- **Fase actual:** Configuración inicial de UI y mallas 3D
- **Objetivo de hoy:** Implementar HUD de buceo (Claude) y modelar submarino/leviatán (Codex).

## Archivos de Lectura Obligatoria para Agentes
1. `.agents/AGENTS.md` (Reglas de coordinación)
2. `game_designs/GDD.md` (Mecánicas core)
3. `game_designs/assets/ui_design.md` (Para trabajo de UI)
4. `game_designs/assets/model_design.md` (Para trabajo en Blender)

## Bitácora de Avances
- [x] Estructura del repositorio creada.
- [x] UI de profundidad y oxígeno creada en Luau (`src/StarterPlayer/StarterPlayerScripts/DiveHud.client.luau`, pendiente de probar en Studio).
- [x] Mapa de prueba (puerto, agua, marcadores) por Codex; recorrido, oxígeno y DataStore verificados en Studio "The_FireBit".
- [x] Bucle de pesca (arpón, peces, tesoro, venta en puerto) con modelos provisionales; valores de prueba: pez 10, tesoro 50, inventario 10.
- [x] Criaturas hostiles (pequeña: mordisco 25%; mediana: agarra y deja al 50%; grande: agarra y mata), modelos provisionales.
- [ ] Modelo `.fbx` del submarino exportado desde Blender.

## Próximo Hand-off
*Claude esperará a que Codex guarde `assets_build/exports/submarine.fbx` para enlazar la MeshPart en Roblox Studio.*