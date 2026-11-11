--!strict
-- Flotabilidad neutra: al nadar sin dar órdenes el jugador se queda quieto (no sube a la superficie).
-- Mover (WASD/joystick) nada hacia donde mira la cámara; Espacio sube y Ctrl/C baja.
-- Se desactiva con player:SetAttribute("NeutralBuoyancy", false).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local DESCEND_SPEED = 16 -- studs/s al bajar con Ctrl/C
local DRAG = 0.85 -- frena la inercia al soltar los controles

RunService.Heartbeat:Connect(function()
	if player:GetAttribute("NeutralBuoyancy") == false then
		return
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not humanoid or not root or humanoid.Health <= 0 or humanoid:GetState() ~= Enum.HumanoidStateType.Swimming then
		return
	end
	local velocity = root.AssemblyLinearVelocity
	local descending = UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.C)
	local ascending = UserInputService:IsKeyDown(Enum.KeyCode.Space) or humanoid.Jump
	if descending then
		root.AssemblyLinearVelocity = Vector3.new(velocity.X, -DESCEND_SPEED, velocity.Z)
	elseif humanoid.MoveDirection.Magnitude < 0.05 and not ascending then
		-- Sin órdenes: anula la flotabilidad y frena suavemente.
		root.AssemblyLinearVelocity = Vector3.new(velocity.X * DRAG, 0, velocity.Z * DRAG)
	end
end)
