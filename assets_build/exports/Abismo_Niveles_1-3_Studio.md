# Niveles 1–3 de Abismo

El archivo `Abismo_Niveles_1-3.rbxmx` contiene las carpetas `Level_1`, `Level_2` y `Level_3` con geometría nativa y colisiones. El archivo Blender tiene una escena editable por nivel. En Blender cada escena usa su propio acople como origen. El RBXMX ya está colocado en las coordenadas de `Workspace.LevelSizeGuides`.

| Nivel | SubDock en Studio | Tesoros | Recorrido |
|---|---|---|---|
| 1 · Bosque del pecio | (0, −40, −876.5) | 4 Small, 2 Medium | Carga de emergencia cerca del acople y naufragio transitable entre algas y arrecifes de discos |
| 2 · Estación en la grieta | (800, −120, −876.5) | 3 Small, 3 Medium, 1 Large | Dos ramas, por el laboratorio elevado o los arcos de basalto, hacia el pecio profundo |
| 3 · El relé abisal | (1600, −220, −876.5) | 2 Medium, 3 Large | Ruta central vigilada y galería oeste más larga. Las dos llegan a la cámara de la baliza |

Cada `Bounds` mide 700 × 700 × 700 studs. Las caras del precipicio continúan por debajo del límite jugable. El marcador `Integracion.WaterRegion` cubre el volumen jugable y el agua que oculta la base de la caída. `Parada` conserva su configuración actual. El mapa usa la iluminación por profundidad que gestiona el cliente de Claude.

## Colocar en la copia de integración

1. En una copia local del lugar, inserta el RBXMX en `Workspace` con **Insert from File**. Debe quedar `Workspace.Abismo_Niveles_1_3`.
2. Ejecuta el siguiente comando una sola vez en la **Command Bar** de Studio en modo edición. Rellena con agua de Terrain las zonas nuevas, conserva los mapas A04 en ServerStorage y coloca las tres carpetas en `Workspace.Maps`. Mantén las posiciones importadas.
3. Guarda la copia y comprueba el trayecto con el submarino acoplado. La baliza la coloca la lógica del proyecto en `Level_3.BeaconSite`.

```lua
local package = assert(workspace:FindFirstChild("Abismo_Niveles_1_3"))
local maps = assert(workspace:FindFirstChild("Maps"))
local terrain = workspace.Terrain
local archiveName = "MapasPrototipo_A04"
local storage = game:GetService("ServerStorage")
assert(not storage:FindFirstChild(archiveName), "Ya existe el respaldo A04")
local levels = {}
for i = 1, 3 do
    local level = assert(package:FindFirstChild("Level_" .. i))
    local marker = assert(level.Integracion:FindFirstChild("WaterRegion"))
    table.insert(levels, { level = level, marker = marker })
end

for _, entry in levels do
    local box = entry.marker
    local region = Region3.new(box.Position - box.Size / 2, box.Position + box.Size / 2):ExpandToGrid(4)
    local low = region.CFrame.Position - region.Size / 2
    local high = region.CFrame.Position + region.Size / 2
    for y = low.Y, high.Y - 4, 96 do
        local slab = Region3.new(
            Vector3.new(low.X, y, low.Z),
            Vector3.new(high.X, math.min(y + 96, high.Y), high.Z)
        )
        terrain:FillRegion(slab, 4, Enum.Material.Water)
        task.wait()
    end
end

local archive = Instance.new("Folder")
archive.Name = archiveName
archive.Parent = storage
for _, entry in levels do
    local old = maps:FindFirstChild(entry.level.Name)
    if old then old.Parent = archive end
    entry.level.Parent = maps
end
package:Destroy()
game:GetService("ChangeHistoryService"):SetWaypoint("Instalar niveles 1 a 3 de Abismo")
```
