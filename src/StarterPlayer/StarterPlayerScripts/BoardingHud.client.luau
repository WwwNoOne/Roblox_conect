--!strict
-- Aviso del abordaje en el lobby: dentro del ascensor muestra "Esperando jugadores (n/total)" y, al cerrarse la puerta,
-- "Cerrando puerta..." / "Iniciando partida...". Lee los atributos que publica BoardingService en el Model del ascensor.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WorldRefs = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("WorldRefs"))
local player = Players.LocalPlayer

local gui = Instance.new("ScreenGui")
gui.Name = "BoardingHud"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 50
gui.Parent = player:WaitForChild("PlayerGui")

local label = Instance.new("TextLabel")
label.AnchorPoint = Vector2.new(0.5, 0)
label.Position = UDim2.fromScale(0.5, 0.12)
label.Size = UDim2.fromOffset(520, 44)
label.BackgroundColor3 = Color3.new(0, 0, 0)
label.BackgroundTransparency = 0.45
label.BorderSizePixel = 0
label.Font = Enum.Font.GothamMedium
label.TextSize = 22
label.TextColor3 = Color3.fromRGB(235, 228, 200)
label.Visible = false
label.Parent = gui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 8)
corner.Parent = label

local function textFor(sub: Model): string?
	if player:GetAttribute("InRun") == true then
		return nil
	end
	if player:GetAttribute("BoardMustExit") == true then
		return "Sal del ascensor y vuelve a entrar para jugar otra vez"
	end
	if player:GetAttribute("Boarded") ~= true then
		return nil
	end
	local phase = sub:GetAttribute("BoardPhase")
	if phase == "Closing" then
		return "Cerrando puerta..."
	elseif phase == "Starting" then
		return "Iniciando partida..."
	elseif phase == "Waiting" then
		local count = sub:GetAttribute("BoardCount") or 0
		local total = sub:GetAttribute("BoardTotal") or 0
		return string.format("Esperando jugadores (%d/%d)", count, total)
	end
	return nil
end

while true do
	local sub = WorldRefs.Elevator()
	local text = if sub then textFor(sub) else nil
	label.Visible = text ~= nil
	if text and label.Text ~= text then
		label.Text = text
	end
	task.wait(0.2)
end
