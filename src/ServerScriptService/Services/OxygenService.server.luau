--!strict
-- Oxígeno autoritativo en servidor: se consume bajo el agua, se recupera en superficie.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local updateHud = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("UpdateHUD") :: RemoteEvent

local REFILL_RATE = 4 -- segundos de oxígeno recuperados por segundo en superficie

local oxygen: { [Player]: number } = {}
local maxOxygen: { [Player]: number } = {}

Players.PlayerAdded:Connect(function(player)
	oxygen[player] = Config.BaseOxygenSeconds
	maxOxygen[player] = Config.BaseOxygenSeconds
end)
Players.PlayerRemoving:Connect(function(player)
	oxygen[player] = nil
	maxOxygen[player] = nil
end)
for _, p in Players:GetPlayers() do
	oxygen[p] = Config.BaseOxygenSeconds
	maxOxygen[p] = Config.BaseOxygenSeconds
end

local function setMax(player: Player, value: number) -- para mejoras de tanque
	maxOxygen[player] = value
end
_G.SetMaxOxygen = setMax

while true do
	local dt = task.wait(Config.HudUpdateInterval)
	for player, current in oxygen do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if root and humanoid and humanoid.Health > 0 then
			local max = maxOxygen[player]
			local submerged = root.Position.Y < Config.SeaLevelY
			local nextValue = if submerged then current - dt else math.min(max, current + dt * REFILL_RATE)
			nextValue = math.clamp(nextValue, 0, max)
			oxygen[player] = nextValue
			if nextValue <= 0 then
				humanoid.Health = 0
				oxygen[player] = max
			end
			updateHud:FireClient(player, nextValue, max)
		end
	end
end
