--!strict
-- Publica los puntos de ruta de los gigantes (Workspace.Maps.<Nivel>.AmbientRoutes.<Ruta>.<Punto>) en
-- ReplicatedStorage.AmbientRoutes.<Nivel>.<Ruta> como Vector3Value. Con StreamingEnabled el cliente no ve esas partes
-- (están muy lejos), así que AmbientFauna lee de aquí. Mueve los puntos en Studio y se aplican al siguiente Play.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local root = Instance.new("Folder")
root.Name = "AmbientRoutes"

-- Los mapas pueden estar en Workspace.Maps o descargados en ServerStorage.MapStorage (ver Runs): se leen de ambos.
local sources: { Instance } = {}
local live = workspace:FindFirstChild("Maps")
local stored = game:GetService("ServerStorage"):FindFirstChild("MapStorage")
if live then
	table.insert(sources, live)
end
if stored then
	table.insert(sources, stored)
end
for _, source in sources do
	for _, level in source:GetChildren() do
		local routes = level:FindFirstChild("AmbientRoutes")
		if routes then
			local levelFolder = Instance.new("Folder")
			levelFolder.Name = level.Name
			for _, route in routes:GetChildren() do
				local routeFolder = Instance.new("Folder")
				routeFolder.Name = route.Name
				for _, p in route:GetChildren() do
					if p:IsA("BasePart") then
						local v = Instance.new("Vector3Value")
						v.Name = p.Name
						v.Value = p.Position
						v.Parent = routeFolder
					end
				end
				routeFolder.Parent = levelFolder
			end
			levelFolder.Parent = root
		end
	end
end

root.Parent = ReplicatedStorage
