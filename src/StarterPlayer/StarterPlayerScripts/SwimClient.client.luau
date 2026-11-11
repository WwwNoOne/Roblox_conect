--!strict
-- Natación fluida con flotabilidad neutra: aceleración/frenado suaves, un poco más rápida que caminar.
-- Mover (WASD/joystick) nada hacia donde mira la cámara; Espacio sube y Ctrl/C baja.
-- Se desactiva con player:SetAttribute("NeutralBuoyancy", false).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local S = Config.Swim

local player = Players.LocalPlayer

local function approach(current: number, target: number, rate: number, dt: number): number
	return current + (target - current) * (1 - math.exp(-rate * dt))
end

RunService.Heartbeat:Connect(function(dt)
	if player:GetAttribute("NeutralBuoyancy") == false then
		return
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not humanoid or not root or humanoid.Health <= 0 then
		return
	end
	if humanoid:GetState() ~= Enum.HumanoidStateType.Swimming then
		if humanoid.WalkSpeed == S.Speed then
			humanoid.WalkSpeed = S.WalkSpeed
		end
		return
	end
	humanoid.WalkSpeed = S.Speed

	local v = root.AssemblyLinearVelocity
	local descending = UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.C)
	local ascending = UserInputService:IsKeyDown(Enum.KeyCode.Space) or humanoid.Jump
	local moving = humanoid.MoveDirection.Magnitude >= 0.05

	if descending then
		v = Vector3.new(v.X, approach(v.Y, -S.VerticalSpeed, S.VerticalAccel, dt), v.Z)
	elseif ascending then
		v = Vector3.new(v.X, approach(v.Y, S.VerticalSpeed, S.VerticalAccel, dt), v.Z)
	elseif not moving then
		-- Sin órdenes: planea y se detiene sin subir (anula la flotabilidad).
		local vy = approach(v.Y, 0, S.VerticalDamping, dt)
		if math.abs(vy) < 2.5 then
			vy = 0 -- anula la flotabilidad residual (si no, deriva hacia arriba)
		end
		v = Vector3.new(approach(v.X, 0, S.Damping, dt), vy, approach(v.Z, 0, S.Damping, dt))
	end
	root.AssemblyLinearVelocity = v
end)
