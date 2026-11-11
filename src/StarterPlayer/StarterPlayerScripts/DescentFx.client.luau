--!strict
-- Efecto de descenso en cabina sellada: vibración y fundido a negro (sonidos: pendiente de assets).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

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
	elseif phase == "End" then
		shakeTarget = 0
		TweenService:Create(blackout, TweenInfo.new(1.5), { BackgroundTransparency = 1 }):Play()
	end
end)
