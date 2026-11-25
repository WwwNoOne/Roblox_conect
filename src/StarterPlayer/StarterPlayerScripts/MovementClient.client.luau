--!strict
-- Velocidad de movimiento: camina a Config.Sprint.WalkSpeed y corre a Config.Sprint.Speed mientras el servidor marca
-- el atributo Sprinting (StaminaService). Sustituye al antiguo control de natación.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local P = Config.Sprint
local player = Players.LocalPlayer

RunService.Heartbeat:Connect(function()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return
	end
	local target = if player:GetAttribute("Sprinting") == true then P.Speed else P.WalkSpeed
	if humanoid.WalkSpeed ~= target then
		humanoid.WalkSpeed = target
	end
end)
