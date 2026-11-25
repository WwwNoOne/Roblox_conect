--!strict
-- Indicador del ascensor (donde se depositan los tesoros): durante un nivel, un rombo con la distancia sobre el ascensor si está a
-- la vista, o pegado al borde de la pantalla apuntando hacia él si no. Se oculta al estar cerca (Config.ElevatorMarker.HideWithin) o
-- dentro. Se calcula en el cliente a partir de la posición del modelo "Elevator".
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Types = require(Shared:WaitForChild("Types"))
local WorldRefs = require(Shared:WaitForChild("WorldRefs"))
local updateHud = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("UpdateHUD") :: RemoteEvent
local M = Config.ElevatorMarker

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera :: Camera

local gui = Instance.new("ScreenGui")
gui.Name = "ElevatorMarker"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Parent = player:WaitForChild("PlayerGui")

local marker = Instance.new("Frame")
marker.AnchorPoint = Vector2.new(0.5, 0.5)
marker.Size = UDim2.fromOffset(150, 44)
marker.BackgroundTransparency = 1
marker.Visible = false
marker.Parent = gui

local diamond = Instance.new("Frame")
diamond.AnchorPoint = Vector2.new(0.5, 0)
diamond.Position = UDim2.new(0.5, 0, 0, 2)
diamond.Size = UDim2.fromOffset(16, 16)
diamond.Rotation = 45
diamond.BackgroundColor3 = M.Color
diamond.BorderSizePixel = 0
diamond.Parent = marker
local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(10, 30, 50)
stroke.Thickness = 2
stroke.Parent = diamond

local text = Instance.new("TextLabel")
text.AnchorPoint = Vector2.new(0.5, 0)
text.Position = UDim2.new(0.5, 0, 0, 22)
text.Size = UDim2.fromOffset(150, 20)
text.BackgroundTransparency = 1
text.Font = Enum.Font.GothamBold
text.TextSize = 14
text.TextColor3 = M.Color
text.TextStrokeColor3 = Color3.fromRGB(10, 30, 50)
text.TextStrokeTransparency = 0.2
text.Parent = marker

local inLevel = false
updateHud.OnClientEvent:Connect(function(payload: Types.HudPayload)
	inLevel = payload.runState == "Level"
end)

local function elevatorPosition(): Vector3?
	local sub = WorldRefs.Elevator()
	if sub then
		return sub:GetPivot().Position
	end
	local dock = workspace:FindFirstChild("ElevatorDock", true)
	return if dock and dock:IsA("BasePart") then dock.Position else nil
end

RunService.RenderStepped:Connect(function()
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local target = elevatorPosition()
	if not (inLevel and player:GetAttribute("InRun") == true and root and target) then
		marker.Visible = false
		return
	end
	local distance = (target - root.Position).Magnitude
	if distance <= M.HideWithin then
		marker.Visible = false
		return
	end
	local view = camera.ViewportSize
	local screen, onScreen = camera:WorldToViewportPoint(target + Vector3.new(0, M.HeightOffset, 0))
	local pos = Vector2.new(screen.X, screen.Y)
	local label = string.format("ASCENSOR  %d m", distance)
	if screen.Z < 0 then
		-- detrás de la cámara: las coordenadas vienen invertidas
		pos = Vector2.new(view.X - pos.X, view.Y - pos.Y)
		onScreen = false
	end
	if onScreen and pos.X > M.Margin and pos.X < view.X - M.Margin and pos.Y > M.Margin and pos.Y < view.Y - M.Margin then
		diamond.Visible = true
	else
		-- fuera de pantalla: lo pega al borde en la dirección del ascensor, con una flecha de texto
		local center = view / 2
		local dir = pos - center
		if dir.Magnitude < 1 then
			dir = Vector2.new(0, 1)
		end
		local scale = math.min(
			(center.X - M.Margin) / math.max(math.abs(dir.X), 1e-3),
			(center.Y - M.Margin) / math.max(math.abs(dir.Y), 1e-3)
		)
		pos = center + dir * scale
		local arrow = if math.abs(dir.X) > math.abs(dir.Y) then (if dir.X < 0 then "< " else " >") elseif dir.Y < 0 then "^ " else "v "
		label = if arrow == " >" then label .. arrow else arrow .. label
	end
	marker.Position = UDim2.fromOffset(pos.X, pos.Y)
	text.Text = label
	marker.Visible = true
end)
