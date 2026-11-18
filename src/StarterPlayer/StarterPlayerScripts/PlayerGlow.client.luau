--!strict
-- Aura tenue alrededor del jugador local: una PointLight fría y corta en el torso, solo en su cliente.
-- Parámetros: Config.PlayerGlow*. Se recrea al reaparecer el personaje.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local QualityTier = require(script.Parent:WaitForChild("QualityTier"))
local player = Players.LocalPlayer

local function attach(character: Model)
	local root = character:WaitForChild("HumanoidRootPart", 10)
	if not root or not root:IsA("BasePart") then
		return
	end
	local old = root:FindFirstChild("PlayerGlow")
	if old then
		old:Destroy()
	end
	local light = Instance.new("PointLight")
	light.Name = "PlayerGlow"
	light.Range = Config.PlayerGlowRange
	light.Brightness = Config.PlayerGlowBrightness
	light.Color = Config.PlayerGlowColor
	light.Shadows = false
	light.Enabled = not QualityTier.IsLow -- en calidad baja el aura se apaga (luz dinámica extra)
	light.Parent = root
end

player.CharacterAdded:Connect(attach)
if player.Character then
	task.spawn(attach, player.Character)
end

QualityTier.Changed:Connect(function()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local light = root and root:FindFirstChild("PlayerGlow")
	if light and light:IsA("PointLight") then
		light.Enabled = not QualityTier.IsLow
	end
end)
