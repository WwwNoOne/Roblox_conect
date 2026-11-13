# Estado de Abismo

Actualizado el 11 de noviembre de 2026. El [GDD vigente](game_designs/GDD.md) y el [manifiesto de Claude](creation_models.md) recogen las decisiones del commit `165c798`. El [plan de desarrollo](docs/superpowers/plans/2026-11-11-abismo.md) es la lista ordenada de tareas. Al cerrar una tarea, actualizar su casilla y registrar la prueba en esta página.

| Estado | Entrega | Responsable |
| --- | --- | --- |
| Disponible para pruebas | Puerto, agua, 11 marcadores y estaciones de luz a 8, 28 y 62 m en Studio | Codex |
| Probado en Studio | Niebla por profundidad, ciclo día/noche y reducción de densidad con la lámpara | Claude y Codex |
| Probado en Studio | Hoja Coral importado con textura y rig. Clip de 1,67 s reproducido con ID temporal. Publicación e integración como fauna ambiental pendientes | Codex y Claude |
| Referencia | FBX provisionales de submarino exterior, leviatán, lámpara y naufragio. El arpón se conserva como referencia histórica | Codex |
| Implementado en el worktree de Claude | T01–T04. Arranque, salas, casco, compuerta, oxígeno y transición sellada. Queda conectar la secuencia de mapas nueva | Claude |
| A01 · Bloque entregado, prueba de cuatro clientes pendiente | Submarino transitable con compuerta, indicador de casco y estaciones de venta, tienda y reparación | Codex |

El código base de Rojo y el prototipo anterior están en el worktree de Claude. Claude mantiene la programación en su worktree. Su versión actual busca los acoples en `Workspace.Zones.Zone_N` y usa `Stopover` para abrir la compuerta. Debe adaptar esa lógica a los acoples de `Workspace.Maps`, al estado de exploración y a la compuerta cerrada en `Parada`.

El [mapa de prueba anterior](game_designs/assets/test_map_spec.md) y el [plan histórico](docs/superpowers/plans/2026-11-10-ocean-depth-explorer.md) sirven como referencia del prototipo.

## A01 · Submarino transitable

- Primera versión archivada. [Modelo de Studio](assets_build/exports/submarine_A01.rbxmx), [fuente editable](assets_build/exports/submarine_A01.blend) y [FBX](assets_build/exports/submarine_A01.fbx).
- La cubierta mide 16 × 20,5 studs. La abertura de popa mide 6 × 6,4 studs. La proa apunta a `+Y` en Blender y a `−Z` en Studio. `HullPivot` conserva el origen `(0, 0, 0)` del casco provisional y es el `PrimaryPart` del modelo `submarine`.
- `HullGauge`, `SellStation`, `ShopStation`, `RepairStation` y `Hatch` son hijos directos de `submarine`. La compuerta parte abierta. `HullPivot` contiene los Attachments `HatchOpen`, `HatchClosed`, `HatchInside`, `HatchOutside` y `CrewSpawn1` a `CrewSpawn4`. `HatchOpen` y `HatchClosed` indican la posición del panel. Los demás indican posiciones para avatares.
- Prueba del 11 de noviembre de 2026. Blender reimportó 95 piezas con 3252 triángulos. Studio deserializó el modelo en memoria y se verificaron el pivote, los nombres, las dimensiones de los 14 volúmenes de colisión, cuatro posiciones de aparición, el acceso a las estaciones y dos trayectorias paralelas por la compuerta abierta. La posición cerrada bloqueó la abertura en la comprobación geométrica. Queda pendiente la prueba física con cuatro clientes en la copia de integración.

### Versión de integración vigente

- Insertar [`submarine_A01_v2.rbxmx`](assets_build/exports/submarine_A01_v2.rbxmx) en la copia de integración. La [fuente Blender](assets_build/exports/submarine_A01_v2.blend) y el [FBX](assets_build/exports/submarine_A01_v2.fbx) incluyen la geometría revisada.
- `Submarine.Hull` es el `PrimaryPart`, centrado en el interior. Mover el conjunto con `Submarine:PivotTo(...)`. `SpawnPoint1` a `SpawnPoint4` son partes invisibles. `InteriorZone` mide 14,9 × 8 × 19,4 studs en ejes de Studio y admite consultas y eventos de contacto.
- `Hatch.Door` parte cerrada. Los Attachments `InsidePrompt`, `OutsidePrompt`, `EntryPoint`, `ExitPoint`, `DoorOpen` y `DoorClosed` están en `Hatch.Frame` y quedan fijos cuando se mueve `Door`. Los puntos de entrada y salida miran en la dirección de paso correspondiente.
- Cada estación tiene un `PromptAttachment` en `Body`. `HullGauge.Screen` mira al interior por la cara `Front` y `HullGauge.Fill` es una pieza separada. `Lights` contiene seis piezas Neon numeradas y `AlarmLight`, con su `Emitter` inicialmente apagado.
- Studio deserializó la versión en memoria y verificó la jerarquía, las medidas, el giro y desplazamiento del modelo, y el espacio libre en los puntos de aparición y al abrir la puerta. Blender reabrió el archivo editable y reimportó el FBX con 91 mallas y 3012 triángulos. La prueba de juego con cuatro clientes y la conexión de la lógica de Claude quedan pendientes en la copia de integración.

## A03 · Tesoros y baliza

- Plantillas en `ServerStorage.AbismoAssets`. Cada tesoro tiene un `Handle` primario, un `GripPoint` y piezas decorativas soldadas al `Handle`. El punto primario está anclado en la plantilla para que Claude decida cuándo liberarlo al transportar.
- Exportaciones de Studio. [Tesoro pequeño](assets_build/exports/treasure_small.rbxmx), [mediano](assets_build/exports/treasure_medium.rbxmx), [grande](assets_build/exports/treasure_large.rbxmx) y [baliza](assets_build/exports/beacon.rbxmx). La baliza trae `Base` como pieza primaria, un Attachment `Base`, `Light` de neón y `PromptAttachment`.
- [Fuente editable](assets_build/exports/abismo_A03.blend). Los cuatro FBX del mismo directorio reimportaron en Blender con 24, 48, 60 y 48 triángulos, respectivamente. Usar los RBXMX para mantener soldaduras y Attachments. Valor, peso y acciones quedan a cargo de Claude.

## A04 · Mapas de prueba en Studio

| Carpeta | Posición de SubDock (X, Y, Z) | Contenido |
| --- | --- | --- |
| `Workspace.Maps.Level_1` | (312, −40, 0) | Bahía, naufragio abierto, tres tesoros y marcadores de fauna |
| `Workspace.Maps.Level_2` | (472, −120, 0) | Bahía, segundo naufragio abierto, tres tesoros y marcadores de fauna |
| `Workspace.Maps.Level_3` | (632, −220, 0) | Bahía, cueva, tres tesoros y `BeaconSite.Base` en (632, −227, 82) |
| `Workspace.Maps.Parada` | (792, −40, 0) | Base y acople. Se reutiliza entre niveles. |

Se reutilizaron las carpetas y bases que ya estaban en Studio. Las tres zonas de exploración tienen agua de Terrain independiente, proa del submarino hacia −Z y salida hacia +Z. La ruta a la baliza rodea la cueva por el este. La separación lateral de 160 studs y la geometría cúbica son decisiones del prototipo.

La prueba geométrica en Studio confirmó agua en los recorridos, tres Attachments `TreasureSpawn` por nivel con atributo `Size`, paso despejado desde `Hatch.ExitPoint` a las zonas explorables y acceso al sitio de la baliza. Queda pendiente ejecutar en Play la secuencia con la lógica de Claude y dos clientes.

## Cangrejo guardián

- El 13 de noviembre de 2026 se comprobó en Studio, sobre un clon sin insertar en el lugar, que el giro de `Cangrejo` y su `GrabPoint` siguen el frente `-Z` al mover y rotar el pivote. La altura y el avance del Attachment se midieron en Blender a partir del cierre de las pinzas en `Atrapar`.
- En el archivo de mapas final, ambos puntos de liberación de cada nivel están en `DeepZone`, las guaridas y patrullas están en `GuardZone` y los acoples quedan fuera. Cada zona profunda contiene un tesoro `Large`. Queda pendiente comprobar el agarre y la liberación en partida después de instalar el [modelo corregido](assets_build/exports/Cangrejo_v1_01.rbxmx) y los [mapas finales](assets_build/exports/Abismo_Niveles_1-3_Studio.md) en la copia de integración. Los clips se conservan como `KeyframeSequence`. La publicación de sus IDs sigue pendiente.
