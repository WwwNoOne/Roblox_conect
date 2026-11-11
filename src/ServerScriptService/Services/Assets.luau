--!strict
-- Busca modelos de Codex en ServerStorage.AbismoAssets (Treasures/, Props/, Creatures/...).
-- Ignora la carpeta _Duplicados (copias sueltas pendientes de borrar).
local ServerStorage = game:GetService("ServerStorage")

local Assets = {}

function Assets.Find(name: string): Instance?
	local root = ServerStorage:FindFirstChild("AbismoAssets")
	if not root then
		return nil
	end
	for _, d in root:GetDescendants() do
		if d.Name == name and not d:FindFirstAncestor("_Duplicados") then
			return d
		end
	end
	return nil
end

return Assets
