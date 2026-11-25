--!strict
-- Zona profunda: sin traje de presión, por debajo de Config.DeepZoneDepth se recibe daño continuo.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Upgrades = require(script.Parent:WaitForChild("Upgrades"))

local TICK = 1
local WARN_EVERY = 4
local lastWarn: { [Player]: number } = {}

while true do
	task.wait(TICK)
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if root and humanoid and humanoid.Health > 0 and not Upgrades.HasSuit(player) then
			local depth = Config.SeaLevelY - root.Position.Y
			if depth > Config.DeepZoneDepth then
				humanoid:TakeDamage(Config.PressureDamagePerSecond * TICK)
				if os.clock() - (lastWarn[player] or 0) >= WARN_EVERY then
					lastWarn[player] = os.clock()
					player:SetAttribute("HudNotice", "¡Presión peligrosa! Necesitas el traje|" .. tostring(os.clock()))
				end
			end
		end
	end
end
