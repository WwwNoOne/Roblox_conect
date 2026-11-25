--!strict
-- Oxígeno personal autoritativo: en partida se consume fuera del submarino y se recarga dentro (InteriorZone).
-- Fuera de una partida (lobby) siempre está lleno.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local Runs = require(script.Parent:WaitForChild("Runs"))
local SafeZone = require(script.Parent:WaitForChild("SafeZone"))

local REFILL_RATE = 30 -- segundos de oxígeno recuperados por segundo dentro del submarino (valor de prueba)

local oxygen: { [Player]: number } = {}

Players.PlayerAdded:Connect(function(player)
	oxygen[player] = Config.BaseOxygenSeconds
end)
Players.PlayerRemoving:Connect(function(player)
	oxygen[player] = nil
end)
for _, p in Players:GetPlayers() do
	oxygen[p] = Config.BaseOxygenSeconds
end

while true do
	local dt = task.wait(Config.HudUpdateInterval)
	for player, current in oxygen do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if root and humanoid and humanoid.Health > 0 then
			local max = Runs.OxygenMax(player.UserId)
			local inRun = Runs.GetByUser(player.UserId) ~= nil
			-- la sala_0 (zona segura) es seca: ahí tampoco se gasta oxígeno
			local submerged = inRun and not Runs.IsUserInside(player.UserId) and not SafeZone.IsPlayerSafe(root.Position)
			local nextValue = if submerged then current - dt else math.min(max, current + dt * REFILL_RATE)
			nextValue = math.clamp(nextValue, 0, max)
			oxygen[player] = nextValue
			if nextValue <= 0 then
				humanoid.Health = 0
				oxygen[player] = max
			end
			-- HudService lee estos atributos y envía UpdateHUD.
			player:SetAttribute("Oxygen", nextValue)
			player:SetAttribute("OxygenMax", max)
		end
	end
end
