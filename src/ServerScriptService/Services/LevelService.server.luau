--!strict
-- Prepara el mundo al arrancar el servidor. Los niveles son mapas fijos (Workspace.Maps.<Nivel>, los carga Runs): aquí solo se apartan
-- a ServerStorage.Plantillas las carpetas de pruebas y las plantillas de criaturas, y se avisa con el atributo Workspace.WorldReady
-- (la pantalla de carga espera a ese atributo). Parámetros: Config.Level.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local stash = ServerStorage:FindFirstChild("Plantillas") or Instance.new("Folder")
stash.Name = "Plantillas"
stash.Parent = ServerStorage

for _, name in Config.Level.Stash do
	local item = workspace:FindFirstChild(name)
	if item then
		item.Parent = stash
	end
end

workspace:SetAttribute("WorldReady", true)
