--!strict
-- Escala única del avatar (Config.Avatar). Al cargar la apariencia de cada personaje R15 se le aplican las mismas escalas de altura,
-- anchura, profundidad, cabeza, tipo de cuerpo y proporción: así la cámara en primera persona queda a la misma altura para todos
-- (CameraMotion) y ningún avatar alto o delgado se mete el cuello en la vista. Se conservan ropa, colores y accesorios.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local A = Config.Avatar

local FIELDS = { "HeightScale", "WidthScale", "DepthScale", "HeadScale", "BodyTypeScale", "ProportionScale" }

local function normalize(character: Model)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.RigType ~= Enum.HumanoidRigType.R15 then
		return
	end
	local ok, description = pcall(function()
		return humanoid:GetAppliedDescription()
	end)
	if not ok or not description then
		return
	end
	local changed = false
	for _, field in FIELDS do
		local target = (A :: any)[field]
		if math.abs((description :: any)[field] - target) > 1e-3 then
			(description :: any)[field] = target
			changed = true
		end
	end
	if changed then
		local applied, err = pcall(function()
			humanoid:ApplyDescription(description)
		end)
		if not applied then
			warn("[AvatarService] no se pudo normalizar la escala de", character.Name, err)
		end
	end
end

local function watch(player: Player)
	player.CharacterAppearanceLoaded:Connect(normalize)
	if player.Character and player:HasAppearanceLoaded() then
		task.spawn(normalize, player.Character)
	end
end

Players.PlayerAdded:Connect(watch)
for _, p in Players:GetPlayers() do
	watch(p)
end
