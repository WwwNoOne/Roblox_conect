--!strict
-- Ambiente de la instalación abandonada (salas decoradas con el kit de ForgeGUI):
--  * lámparas de jaula (etiqueta "LamparaInstalacion", atributo Parpadeo) que parpadean de vez en cuando;
--  * bucle de ambiente (Config.Sfx.FacilityAmbience) mientras el jugador está en una partida;
--  * gemidos de tubería (Config.Sfx.PipeGroan) cada cierto tiempo, en un punto cercano al jugador (sonido 3D).
-- Los sonidos se buscan por prefijo en Workspace.sonidos (Shared/Sfx); si no existen, no suena nada.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Sfx = require(Shared:WaitForChild("Sfx"))

local player = Players.LocalPlayer
local AMBIENCE_VOLUME = 0.45
local GROAN_MIN, GROAN_MAX = 18, 45 -- segundos entre gemidos de tubería

-- ===== Lámparas que parpadean =====
type Lamp = { light: PointLight, base: number, nextAt: number, offUntil: number }
local lamps: { [Instance]: Lamp } = {}

local function addLamp(inst: Instance)
	if inst:GetAttribute("Parpadeo") ~= true then
		return
	end
	local light = inst:FindFirstChildWhichIsA("PointLight", true)
	if light then
		lamps[inst] = { light = light, base = light.Brightness, nextAt = os.clock() + math.random() * 6, offUntil = 0 }
	end
end
for _, inst in CollectionService:GetTagged("LamparaInstalacion") do
	addLamp(inst)
end
CollectionService:GetInstanceAddedSignal("LamparaInstalacion"):Connect(addLamp)
CollectionService:GetInstanceRemovedSignal("LamparaInstalacion"):Connect(function(inst)
	lamps[inst] = nil
end)

RunService.Heartbeat:Connect(function()
	local now = os.clock()
	for inst, l in lamps do
		if not inst.Parent then
			lamps[inst] = nil
		elseif now < l.offUntil then
			l.light.Brightness = l.base * (if math.random() < 0.5 then 0.05 else 0.6)
		elseif now >= l.nextAt then
			-- ráfaga corta de parpadeo y luego varios segundos estable
			l.offUntil = now + 0.15 + math.random() * 0.5
			l.nextAt = l.offUntil + 2 + math.random() * 7
		else
			l.light.Brightness = l.base
		end
	end
end)

-- ===== Bucle de ambiente =====
local ambience: Sound? = nil
local function ensureAmbience(): Sound?
	if ambience and ambience.Parent then
		return ambience
	end
	local template = Sfx.Find(Config.Sfx.FacilityAmbience)
	if not template then
		return nil
	end
	local s = template:Clone()
	s.Looped = true
	s.Volume = 0
	s.Parent = SoundService
	s:Play()
	ambience = s
	return s
end

local function inRun(): boolean
	return player:GetAttribute("InRun") == true
end

task.spawn(function()
	while true do
		local want = if inRun() then AMBIENCE_VOLUME else 0
		local s = if want > 0 then ensureAmbience() else ambience
		if s then
			TweenService:Create(s, TweenInfo.new(2), { Volume = want }):Play()
		end
		task.wait(1)
	end
end)

-- ===== Gemidos de tubería =====
task.spawn(function()
	while true do
		task.wait(GROAN_MIN + math.random() * (GROAN_MAX - GROAN_MIN))
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if inRun() and root and root:IsA("BasePart") then
			local angle = math.random() * math.pi * 2
			local offset = Vector3.new(math.cos(angle), (math.random() - 0.5) * 0.6, math.sin(angle)) * (20 + math.random() * 25)
			local spot = Instance.new("Part")
			spot.Anchored = true
			spot.CanCollide = false
			spot.CanQuery = false
			spot.CanTouch = false
			spot.Transparency = 1
			spot.Size = Vector3.one
			spot.Position = root.Position + offset
			spot.Parent = workspace
			Sfx.Play(Config.Sfx.PipeGroan, spot, 0.8, 120)
			task.delay(10, function()
				spot:Destroy()
			end)
		end
	end
end)
