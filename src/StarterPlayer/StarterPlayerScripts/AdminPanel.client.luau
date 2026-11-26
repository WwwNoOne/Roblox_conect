--!strict
-- TEMPORAL, solo para pruebas en Studio: panel de admin con cámara libre (freecam) e invencibilidad (AdminService.server).
-- No hace nada fuera de Studio. Borrar este archivo y AdminService.server.luau antes de publicar.
--
-- Teclas:   F6 cámara libre · F7 invencible · F8 ocultar/mostrar el panel
-- Freecam:  WASD mover · E / Q subir / bajar · Shift rápido · Ctrl lento · rueda cambia la velocidad · T teletransporta el
--           personaje a la cámara y sale · ratón mira. Los botones del panel se pulsan con Alt izquierdo (libera el cursor).
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

if not RunService:IsStudio() then
	return
end

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local godRemote = ReplicatedStorage:WaitForChild("AdminGod", 10) :: RemoteEvent?

local freecamOn = false
local godOn = false
local speed = 60
local camCFrame = CFrame.new()
local yaw, pitch = 0, 0

-- ===== UI =====
local gui = Instance.new("ScreenGui")
gui.Name = "AdminPanel"
gui.ResetOnSpawn = false
gui.DisplayOrder = 900
gui.Parent = playerGui

local frame = Instance.new("Frame")
frame.AnchorPoint = Vector2.new(1, 0)
frame.Position = UDim2.new(1, -12, 0, 12)
frame.Size = UDim2.fromOffset(190, 118)
frame.BackgroundColor3 = Color3.fromRGB(20, 20, 24)
frame.BackgroundTransparency = 0.15
frame.BorderSizePixel = 0
frame.Parent = gui
Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 6)
local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 4)
layout.Parent = frame
local pad = Instance.new("UIPadding")
pad.PaddingTop, pad.PaddingBottom, pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 6), UDim.new(0, 6), UDim.new(0, 6), UDim.new(0, 6)
pad.Parent = frame

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 16)
title.BackgroundTransparency = 1
title.Text = "ADMIN (temporal)"
title.TextColor3 = Color3.fromRGB(255, 190, 70)
title.Font = Enum.Font.GothamBold
title.TextSize = 13
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = frame

local function makeButton(): TextButton
	local b = Instance.new("TextButton")
	b.Size = UDim2.new(1, 0, 0, 28)
	b.BorderSizePixel = 0
	b.Font = Enum.Font.Gotham
	b.TextSize = 14
	b.TextColor3 = Color3.new(1, 1, 1)
	b.AutoButtonColor = true
	b.Parent = frame
	Instance.new("UICorner", b).CornerRadius = UDim.new(0, 4)
	return b
end
local freecamButton = makeButton()
local godButton = makeButton()

local hint = Instance.new("TextLabel")
hint.Size = UDim2.new(1, 0, 0, 30)
hint.BackgroundTransparency = 1
hint.Text = "F8 oculta · botones con Alt\nFreecam: WASD E/Q Shift Ctrl T"
hint.TextColor3 = Color3.fromRGB(150, 150, 160)
hint.Font = Enum.Font.Gotham
hint.TextSize = 11
hint.TextXAlignment = Enum.TextXAlignment.Left
hint.TextWrapped = true
hint.Parent = frame

local function refreshUi()
	freecamButton.Text = (if freecamOn then "Cámara libre: SÍ" else "Cámara libre: no") .. "  [F6]"
	freecamButton.BackgroundColor3 = if freecamOn then Color3.fromRGB(40, 120, 200) else Color3.fromRGB(55, 55, 62)
	godButton.Text = (if godOn then "Invencible: SÍ" else "Invencible: no") .. "  [F7]"
	godButton.BackgroundColor3 = if godOn then Color3.fromRGB(40, 150, 80) else Color3.fromRGB(55, 55, 62)
end
refreshUi()

-- ===== Invencibilidad =====
local function setGod(on: boolean)
	godOn = on
	if godRemote then
		godRemote:FireServer(on)
	end
	refreshUi()
end

-- ===== Cámara libre =====
local camera = workspace.CurrentCamera
local held: { [Enum.KeyCode]: boolean } = {}

local function sinkInput(_: string, state: Enum.UserInputState, input: InputObject): Enum.ContextActionResult
	if input.UserInputType == Enum.UserInputType.Keyboard then
		held[input.KeyCode] = state == Enum.UserInputState.Begin or state == Enum.UserInputState.Change
	end
	return Enum.ContextActionResult.Sink
end

local MOVE_KEYS = {
	Enum.KeyCode.W, Enum.KeyCode.A, Enum.KeyCode.S, Enum.KeyCode.D,
	Enum.KeyCode.E, Enum.KeyCode.Q, Enum.KeyCode.Space, Enum.KeyCode.LeftShift, Enum.KeyCode.LeftControl,
}

local function setFreecam(on: boolean)
	if on == freecamOn then
		return
	end
	freecamOn = on
	if on then
		camera = workspace.CurrentCamera
		camCFrame = camera.CFrame
		local x, y = camCFrame:ToOrientation()
		pitch, yaw = x, y
		held = {}
		camera.CameraType = Enum.CameraType.Scriptable
		ContextActionService:BindActionAtPriority("AdminFreecamSink", sinkInput, false, Enum.ContextActionPriority.High.Value + 100, table.unpack(MOVE_KEYS))
		RunService:BindToRenderStep("AdminFreecam", Enum.RenderPriority.Camera.Value + 10, function(dt)
			UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
			UserInputService.MouseIconEnabled = false
			local delta = UserInputService:GetMouseDelta()
			yaw -= math.rad(delta.X * 0.25)
			pitch = math.clamp(pitch - math.rad(delta.Y * 0.25), math.rad(-89), math.rad(89))
			local rot = CFrame.fromOrientation(pitch, yaw, 0)
			local move = Vector3.zero
			if held[Enum.KeyCode.W] then move += Vector3.new(0, 0, -1) end
			if held[Enum.KeyCode.S] then move += Vector3.new(0, 0, 1) end
			if held[Enum.KeyCode.A] then move += Vector3.new(-1, 0, 0) end
			if held[Enum.KeyCode.D] then move += Vector3.new(1, 0, 0) end
			if held[Enum.KeyCode.E] or held[Enum.KeyCode.Space] then move += Vector3.new(0, 1, 0) end
			if held[Enum.KeyCode.Q] then move += Vector3.new(0, -1, 0) end
			local mult = 1
			if held[Enum.KeyCode.LeftShift] then mult = 3 end
			if held[Enum.KeyCode.LeftControl] then mult = 0.25 end
			camCFrame = CFrame.new(camCFrame.Position + rot:VectorToWorldSpace(move) * speed * mult * dt) * rot
			camera.CameraType = Enum.CameraType.Scriptable
			camera.CFrame = camCFrame
		end)
	else
		RunService:UnbindFromRenderStep("AdminFreecam")
		ContextActionService:UnbindAction("AdminFreecamSink")
		held = {}
		camera.CameraType = Enum.CameraType.Custom
		UserInputService.MouseIconEnabled = true
	end
	refreshUi()
end

local function teleportToCamera()
	local character = player.Character
	if freecamOn and character then
		character:PivotTo(CFrame.new(camCFrame.Position))
		setFreecam(false)
	end
end

-- ===== Entradas =====
UserInputService.InputBegan:Connect(function(input, processed)
	if input.UserInputType == Enum.UserInputType.MouseWheel then
		return
	end
	if processed and input.KeyCode ~= Enum.KeyCode.F6 and input.KeyCode ~= Enum.KeyCode.F7 and input.KeyCode ~= Enum.KeyCode.F8 then
		return
	end
	if input.KeyCode == Enum.KeyCode.F6 then
		setFreecam(not freecamOn)
	elseif input.KeyCode == Enum.KeyCode.F7 then
		setGod(not godOn)
	elseif input.KeyCode == Enum.KeyCode.F8 then
		frame.Visible = not frame.Visible
	elseif input.KeyCode == Enum.KeyCode.T then
		teleportToCamera()
	end
end)

UserInputService.InputChanged:Connect(function(input)
	if freecamOn and input.UserInputType == Enum.UserInputType.MouseWheel then
		speed = math.clamp(speed * (if input.Position.Z > 0 then 1.25 else 0.8), 5, 600)
	end
end)

freecamButton.Activated:Connect(function()
	setFreecam(not freecamOn)
end)
godButton.Activated:Connect(function()
	setGod(not godOn)
end)

-- Si el personaje reaparece con la invencibilidad activa, el servidor la reaplica; al morir con la cámara libre no se pierde.
player.CharacterAdded:Connect(function()
	refreshUi()
end)
