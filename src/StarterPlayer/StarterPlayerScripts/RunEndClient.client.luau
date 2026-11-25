--!strict
-- Pantalla de fin de partida (T06). El regreso al lobby real llega con L01.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local runEnded = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("RunEnded") :: RemoteEvent
local player = Players.LocalPlayer

local gui = Instance.new("ScreenGui")
gui.Name = "RunEnd"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 200
gui.Enabled = false
gui.Parent = player:WaitForChild("PlayerGui")

local bg = Instance.new("Frame")
bg.Size = UDim2.fromScale(1, 1)
bg.BackgroundColor3 = Color3.new(0, 0, 0)
bg.BackgroundTransparency = 0.35
bg.BorderSizePixel = 0
bg.Parent = gui

local title = Instance.new("TextLabel")
title.AnchorPoint = Vector2.new(0.5, 0.5)
title.Position = UDim2.fromScale(0.5, 0.45)
title.Size = UDim2.fromOffset(600, 80)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBold
title.TextSize = 48
title.TextColor3 = Color3.new(1, 1, 1)
title.Parent = bg

local sub = Instance.new("TextLabel")
sub.AnchorPoint = Vector2.new(0.5, 0.5)
sub.Position = UDim2.fromScale(0.5, 0.55)
sub.Size = UDim2.fromOffset(600, 40)
sub.BackgroundTransparency = 1
sub.Font = Enum.Font.GothamMedium
sub.TextSize = 22
sub.TextColor3 = Color3.fromRGB(220, 220, 220)
sub.Parent = bg

local REASONS: { [string]: string } = {
	Beacon = "Objetivo final activado. ¡Misión cumplida!",
	QuotaFailed = "Fallaron demasiadas cuotas.",
	AllDead = "Toda la tripulación murió.",
	TimeUp = "Se acabó el tiempo: no se alcanzó el objetivo final.",
}

runEnded.OnClientEvent:Connect(function(result: string, reason: string)
	title.Text = if result == "Won" then "VICTORIA" else "DERROTA"
	title.TextColor3 = if result == "Won" then Color3.fromRGB(90, 255, 140) else Color3.fromRGB(255, 80, 80)
	sub.Text = REASONS[reason] or reason
	gui.Enabled = true
	task.delay(7.5, function()
		gui.Enabled = false
	end)
end)
