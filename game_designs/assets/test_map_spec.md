# Mapa de prueba del prototipo original

> Referencia del lugar de pruebas de Studio. La integración de Abismo sigue [Launch.md](../../Launch.md).

Unidades: studs (1 stud = 1 m en el HUD). Ejes Roblox: +Y arriba. Origen (0,0,0) = nivel del mar.
`Config.SeaLevelY = 0`: el servidor consume oxígeno cuando `HumanoidRootPart.Position.Y < 0`.

## Reglas previas
- Eliminar o hundir el `Baseplate` de la plantilla (su cara superior está en Y=0 y taparía el agua).
- El agua debe ser **Terrain Water** (para que el personaje nade), no un Part. Superficie exacta en Y=0.
- Marcadores: Parts `Anchored=true`, `CanCollide=false`, `CanQuery=false`, `Transparency=1`, tamaño 2x2x2,
  dentro de `Workspace.Markers` (Folder). El nombre es el ID; además `SetAttribute("MarkerId", <nombre>)`.

## Medidas
| Elemento | Tamaño (X,Y,Z) | Centro | Notas |
| :-- | :-- | :-- | :-- |
| Puerto cúbico (`Port`) | 40 x 12 x 40 | (-80, -2, 0) | Cara superior (cubierta) en Y=+4; sólido, CanCollide |
| Zona de agua (`WaterZone`) | 200 x 60 x 200 | (40, -30, 0) | X de -60 a 140, Z de -100 a 100, Y de 0 a -60 |
| Fondo marino (`SeaFloor`) | 200 x 4 x 200 | (40, -62, 0) | Cara superior en Y=-60 |

El borde este del puerto (X=-60) toca el borde oeste del agua: el jugador salta de la cubierta al agua.

## Marcadores (posición en studs)
| MarkerId | Posición | Uso |
| :-- | :-- | :-- |
| `Marker_PortSpawn` | (-80, 5, 0) | Spawn del jugador en el puerto |
| `Marker_PortDock` | (-62, 5, 0) | Punto de salto al agua |
| `Marker_SeaLevel` | (0, 0, 0) | Referencia de superficie |
| `Marker_Depth_10` | (40, -10, 0) | Prueba HUD 10 m |
| `Marker_Depth_25` | (80, -25, 0) | Prueba HUD 25 m |
| `Marker_Depth_50` | (120, -50, 0) | Prueba HUD 50 m |
| `Marker_Wreck_01` | (100, -58, 40) | Naufragio zona 1 (sobre el fondo) |
| `Marker_Treasure_01` | (100, -58, 46) | Tesoro junto al naufragio |
| `Marker_Fish_01` | (60, -20, -40) | Spawn de peces |
| `Marker_Leviathan_Patrol_01` | (20, -35, 60) | Punto de patrulla 1 |
| `Marker_Leviathan_Patrol_02` | (120, -35, -60) | Punto de patrulla 2 |

## Prueba de recorrido
Spawn -> saltar al agua -> bajar a 50 m (Depth_50) -> naufragio -> volver a Y>0.
Duración esperada con oxígeno de 360 s: sobra margen; el HUD debe mostrar 0..~58 m.
