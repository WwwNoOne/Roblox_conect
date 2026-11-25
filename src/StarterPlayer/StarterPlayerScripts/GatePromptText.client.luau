--!strict
-- La puerta del ascensor tiene un solo botón (GatePrompt, creado por ElevatorService). Aquí cada cliente ve
-- "Entrar" si está fuera del ascensor y "Salir" si está dentro (InteriorZone).
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WorldRefs = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("WorldRefs"))
local localPlayer = Players.LocalPlayer

local function isInside(): boolean
	local character = localPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local sub = WorldRefs.Elevator()
	local zone = sub and sub:FindFirstChild("InteriorZone", true)
	if not (root and root:IsA("BasePart") and zone and zone:IsA("BasePart")) then
		return false
	end
	local rel = zone.CFrame:PointToObjectSpace(root.Position)
	local half = zone.Size / 2 + Vector3.new(0.5, 1, 0.5)
	return math.abs(rel.X) <= half.X and math.abs(rel.Y) <= half.Y and math.abs(rel.Z) <= half.Z
end

local showing: { [ProximityPrompt]: boolean } = {}

ProximityPromptService.PromptShown:Connect(function(prompt: ProximityPrompt)
	if prompt.Name ~= "GatePrompt" or showing[prompt] then
		return
	end
	showing[prompt] = true
	-- Mientras se muestra, mantiene el texto al día (por si cruza la puerta con el botón aún visible).
	task.spawn(function()
		while showing[prompt] and prompt.Parent do
			local text = if isInside() then "Salir" else "Entrar"
			if prompt.ActionText ~= text then
				prompt.ActionText = text
			end
			task.wait(0.2)
		end
		showing[prompt] = nil
	end)
end)

ProximityPromptService.PromptHidden:Connect(function(prompt: ProximityPrompt)
	if showing[prompt] then
		showing[prompt] = false
	end
end)
