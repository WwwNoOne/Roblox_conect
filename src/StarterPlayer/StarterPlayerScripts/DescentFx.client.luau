--!strict
-- Efecto de descenso en cabina sellada: vibración y fundido a negro con engranaje girando y texto (Config.Loading.TravelText),
-- para que el viaje (inicio, Parada, siguiente nivel) no sea una pantalla negra vacía.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local descentFx = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("DescentFx") :: RemoteEvent
local player = Players.LocalPlayer

local gui = Instance.new("ScreenGui")
gui.Name = "DescentFx"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 100
gui.Parent = player:WaitForChild("PlayerGui")

local blackout = Instance.new("Frame")
blackout.Size = UDim2.fromScale(1, 1)
blackout.BackgroundColor3 = Color3.new(0, 0, 0)
blackout.BackgroundTransparency = 1
blackout.BorderSizePixel = 0
blackout.Parent = gui

local gear = Instance.new("TextLabel")
gear.AnchorPoint = Vector2.new(0.5, 0.5)
gear.Position = UDim2.fromScale(0.5, 0.47)
gear.Size = UDim2.fromOffset(96, 96)
gear.BackgroundTransparency = 1
gear.Text = "⚙"
gear.TextScaled = true
gear.TextColor3 = Color3.fromRGB(120, 180, 230)
gear.TextTransparency = 1
gear.Font = Enum.Font.GothamBold
gear.Parent = blackout

local label = Instance.new("TextLabel")
label.AnchorPoint = Vector2.new(0.5, 0)
label.Position = UDim2.new(0.5, 0, 0.47, 64)
label.Size = UDim2.fromOffset(320, 30)
label.BackgroundTransparency = 1
label.Text = Config.Loading.TravelText
label.TextSize = 20
label.TextColor3 = Color3.fromRGB(150, 175, 200)
label.TextTransparency = 1
label.Font = Enum.Font.Gotham
label.Parent = blackout

local function fadeSpinner(target: number, seconds: number)
	local info = TweenInfo.new(seconds)
	TweenService:Create(gear, info, { TextTransparency = target }):Play()
	TweenService:Create(label, info, { TextTransparency = target }):Play()
end

RunService.RenderStepped:Connect(function(dt: number)
	if gear.TextTransparency < 1 then
		gear.Rotation = (gear.Rotation + dt * 140) % 360
	end
end)

local shake = 0 -- 0..1
local shakeTarget = 0

RunService:BindToRenderStep("DescentShake", Enum.RenderPriority.Camera.Value + 1, function(dt: number)
	shake += (shakeTarget - shake) * math.min(1, dt * 3)
	if shake > 0.01 then
		local t = os.clock() * 25
		local camera = workspace.CurrentCamera
		if camera then
			camera.CFrame *= CFrame.new(math.noise(t, 0) * shake * 0.4, math.noise(0, t) * shake * 0.4, 0)
				* CFrame.Angles(0, 0, math.noise(t, t) * shake * 0.03)
		end
	end
end)

descentFx.OnClientEvent:Connect(function(phase: string)
	if phase == "Start" then
		shakeTarget = 1
		TweenService:Create(blackout, TweenInfo.new(1.2), { BackgroundTransparency = 0 }):Play()
		fadeSpinner(0, 1.2)
	elseif phase == "End" then
		shakeTarget = 0
		TweenService:Create(blackout, TweenInfo.new(1.5), { BackgroundTransparency = 1 }):Play()
		fadeSpinner(1, 0.8)
	end
end)
