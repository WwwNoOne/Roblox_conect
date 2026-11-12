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
local Sfx = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Sfx"))
local nextStroke = 0

local player = Players.LocalPlayer
local holdY: number? = nil -- altura que se mantiene al quedarse quieto (contrarresta la flotabilidad del motor)

local function approach(current: number, target: number, rate: number, dt: number): number
	return current + (target - current) * (1 - math.exp(-rate * dt))
end

RunService.Heartbeat:Connect(function(dt)
	if player:GetAttribute("NeutralBuoyancy") == false or player:GetAttribute("Dashing") == true then
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

	-- Sonido de brazada mientras se nada de verdad (no al flotar quieto).
	if (moving or ascending or descending) and v.Magnitude > 4 and os.clock() >= nextStroke then
		nextStroke = os.clock() + S.StrokeSeconds
		Sfx.Play(Config.Sfx.Stroke, nil, S.StrokeVolume)
	end

	if descending then
		holdY = nil
		v = Vector3.new(v.X, approach(v.Y, -S.VerticalSpeed, S.VerticalAccel, dt), v.Z)
	elseif ascending then
		holdY = nil
		v = Vector3.new(v.X, approach(v.Y, S.VerticalSpeed, S.VerticalAccel, dt), v.Z)
	elseif not moving then
		-- Sin órdenes: planea en horizontal y MANTIENE la altura. El motor empuja hacia arriba en cada paso de
		-- física, así que no basta con poner la velocidad vertical a 0: se corrige la posición hacia holdY.
		if holdY == nil then
			holdY = root.Position.Y
		end
		local correction = math.clamp((holdY - root.Position.Y) * S.HoldGain, -S.HoldMaxSpeed, S.HoldMaxSpeed)
		v = Vector3.new(approach(v.X, 0, S.Damping, dt), correction, approach(v.Z, 0, S.Damping, dt))
	else
		holdY = nil
	end
	root.AssemblyLinearVelocity = v
end)
