--!strict
-- Sonido de movimiento realista (parámetros: Config.Footsteps). Sustituye a los sonidos de Roblox (RbxCharacterSounds está vacío).
--   * Pasos por zancada real (distancia recorrida / zancada de la forma de moverse), no por temporizador: van al ritmo de la
--     velocidad y marcan el balanceo de la cámara (MotionState.stepCycle).
--   * Superficie por rayo bajo los pies: material del Terrain o de la pieza, o el atributo "Superficie" de la pieza o su modelo.
--   * Cada pisada elige una variante distinta de la anterior y varía tono y volumen. Agachado suena flojo y se oye cerca; corriendo,
--     fuerte y lejos. Paso de asiento al pararse, impulso al saltar, doble pisada al aterrizar y golpe del cuerpo si la caída es dura.
--   * Se oyen los pasos de los demás jugadores en 3D; si hay una pared entre la cámara y ellos, suenan apagados (oclusión).
--   * Reverberación según el espacio (rayos alrededor de la cámara): sala pequeña seca, pasillo largo con eco, la moqueta absorbe.
--     Solo afecta al grupo de sonidos de movimiento, no a la música.
--   * Respiración que crece con el esfuerzo (estamina) y latido con poca vida (solo para ti).
local ContentProvider = game:GetService("ContentProvider")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local MotionState = require(script.Parent:WaitForChild("MotionState"))
local F = Config.Footsteps
local M = Config.Movement

local player = Players.LocalPlayer

-- ===== Grupos y precarga =====
local foley = Instance.new("SoundGroup")
foley.Name = "Movimiento"
foley.Volume = 1
foley.Parent = SoundService
local reverb = Instance.new("ReverbSoundEffect")
reverb.DecayTime = 0.8
reverb.Density = 1
reverb.Diffusion = 1
reverb.DryLevel = 0
reverb.WetLevel = -30
reverb.Parent = foley

local body = Instance.new("SoundGroup")
body.Name = "Cuerpo" -- respiración y latido: dentro de tu cabeza, sin reverberación
body.Parent = SoundService

do
	local preload: { Instance } = {}
	local function add(id: string)
		local s = Instance.new("Sound")
		s.SoundId = id
		table.insert(preload, s)
	end
	for _, surface in F.Surfaces do
		for _, id in surface.Sounds do
			add(id)
		end
	end
	for _, id in F.Cloth do
		add(id)
	end
	for _, id in F.BodyFall do
		add(id)
	end
	add(F.Breathing)
	add(F.Heartbeat)
	task.spawn(function()
		pcall(function()
			ContentProvider:PreloadAsync(preload)
		end)
	end)
end

-- ===== Reproducción =====
local lastPick: { [any]: number } = {}

local function pick(list: { string }): string?
	local n = #list
	if n == 0 then
		return nil
	end
	local i = math.random(n)
	if n > 1 and lastPick[list] == i then
		i = i % n + 1 -- nunca la misma variante dos veces seguidas
	end
	lastPick[list] = i
	return list[i]
end

local function playAt(parent: Instance, id: string, volume: number, pitch: number, range: number, occluded: boolean)
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = volume * (if occluded then F.OccludedVolume else 1)
	s.PlaybackSpeed = pitch
	s.RollOffMode = Enum.RollOffMode.InverseTapered
	s.RollOffMinDistance = 6
	s.RollOffMaxDistance = range
	s.SoundGroup = foley
	if occluded then
		local eq = Instance.new("EqualizerSoundEffect")
		eq.LowGain = 0
		eq.MidGain = F.OccludedMidGain
		eq.HighGain = F.OccludedHighGain
		eq.Parent = s
	end
	s.Parent = parent
	s.Ended:Once(function()
		s:Destroy()
	end)
	Debris:AddItem(s, 5)
	s:Play()
end

local function jitter(amount: number): number
	return 1 + (math.random() * 2 - 1) * amount
end

-- ===== Superficie =====
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.IgnoreWater = false

local function surfaceOf(result: RaycastResult): string
	local inst = result.Instance
	local tagged = inst:GetAttribute("Superficie")
	if type(tagged) ~= "string" and inst.Parent then
		tagged = inst.Parent:GetAttribute("Superficie")
	end
	if type(tagged) == "string" and (F.Surfaces :: any)[tagged] then
		return tagged
	end
	return F.Materials[result.Material] or F.Default
end

-- ===== Seguimiento por personaje =====
type Tracker = {
	player: Player,
	character: Model,
	humanoid: Humanoid,
	root: BasePart,
	feet: Attachment,
	isLocal: boolean,
	cycle: number,
	sinceStep: number, -- fracción de medio ciclo recorrida desde la última pisada
	moving: boolean,
	grounded: boolean,
	airMinVy: number,
	surface: string,
	lastLand: number,
	lastJump: number,
	lastStance: number,
}

local trackers: { [Model]: Tracker } = {}

local function occludedFrom(t: Tracker): boolean
	if t.isLocal then
		return false
	end
	local camera = workspace.CurrentCamera
	if not camera then
		return false
	end
	local from = camera.CFrame.Position
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local exclude: { Instance } = { t.character }
	if player.Character then
		table.insert(exclude, player.Character)
	end
	params.FilterDescendantsInstances = exclude
	return workspace:Raycast(from, t.root.Position - from, params) ~= nil
end

local function gaitOf(t: Tracker, flatSpeed: number): string
	if t.isLocal then
		local g = MotionState.gait
		return if g == "Idle" then "Walk" else g
	end
	if t.player:GetAttribute("Crouching") == true then
		return "Crouch"
	end
	if flatSpeed > M.WalkSpeed * F.OthersSprintRatio then
		return "Sprint"
	end
	return "Walk"
end

local function footstep(t: Tracker, gaitName: string, volumeScale: number)
	local surface = (F.Surfaces :: any)[t.surface] or (F.Surfaces :: any)[F.Default]
	local gait = (F.Gaits :: any)[gaitName] or F.Gaits.Walk
	local id = pick(surface.Sounds)
	if not id then
		return
	end
	local volume = surface.Volume * gait.Volume * volumeScale * jitter(F.VolumeJitter) * (if t.isLocal then 0.8 else 1)
	local pitch = gait.Pitch * jitter(F.PitchJitter)
	playAt(t.feet, id, volume, pitch, gait.Range, occludedFrom(t))
end

local function cloth(t: Tracker, volume: number)
	local id = pick(F.Cloth)
	if id then
		playAt(t.root, id, volume, jitter(0.08), 30, occludedFrom(t))
	end
end

local function onLanded(t: Tracker, impact: number)
	if impact < M.SoftLandSpeed then
		return
	end
	local strength = math.clamp(impact / M.HardLandSpeed, 0.4, 1.4)
	local gaitName = if impact >= M.HardLandSpeed then "Sprint" else "Walk"
	footstep(t, gaitName, strength)
	task.delay(0.05 + math.random() * 0.04, function()
		if t.root.Parent then
			footstep(t, gaitName, strength * 0.8)
		end
	end)
	if impact >= M.HardLandSpeed then
		local id = pick(F.BodyFall)
		if id then
			playAt(t.root, id, 0.7 * math.min(strength, 1.2), jitter(0.06), 70, occludedFrom(t))
		end
		cloth(t, 0.4)
	end
end

-- Los sonidos de personaje de Roblox (Running, Jumping, Landing...: rbxasset://sounds/...) a veces llegan aunque RbxCharacterSounds
-- esté anulado; se silencian para que solo suenen los nuestros.
local function muteDefault(inst: Instance)
	if inst:IsA("Sound") and string.sub(inst.SoundId, 1, 18) == "rbxasset://sounds/" then
		inst.Volume = 0
		inst:GetPropertyChangedSignal("Volume"):Connect(function()
			if inst.Volume ~= 0 then
				inst.Volume = 0
			end
		end)
	end
end

local function track(p: Player, character: Model)
	if trackers[character] then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not humanoid or not root then
		return
	end
	for _, d in root:GetChildren() do
		muteDefault(d)
	end
	root.ChildAdded:Connect(function(d)
		task.defer(muteDefault, d) -- el SoundId puede asignarse justo después de crearse
	end)
	local feet = Instance.new("Attachment")
	feet.Name = "Pies"
	feet.Position = Vector3.new(0, -(root.Size.Y / 2 + humanoid.HipHeight), 0)
	feet.Parent = root
	trackers[character] = {
		player = p,
		character = character,
		humanoid = humanoid,
		root = root,
		feet = feet,
		isLocal = p == player,
		cycle = 0,
		sinceStep = 0,
		moving = false,
		grounded = true,
		airMinVy = 0,
		surface = F.Default,
		lastLand = MotionState.landCount,
		lastJump = MotionState.jumpCount,
		lastStance = MotionState.stanceCount,
	}
end

local function updateTracker(t: Tracker, dt: number)
	local h, r = t.humanoid, t.root
	if h.Health <= 0 then
		return
	end
	local vel = r.AssemblyLinearVelocity
	local flatSpeed = Vector3.new(vel.X, 0, vel.Z).Magnitude

	-- Suelo
	rayParams.FilterDescendantsInstances = { t.character }
	local reach = r.Size.Y / 2 + h.HipHeight + 0.8
	local hit = workspace:Raycast(r.Position, Vector3.new(0, -reach, 0), rayParams)
	local grounded = hit ~= nil and h:GetState() ~= Enum.HumanoidStateType.Freefall
	if hit then
		t.surface = surfaceOf(hit)
	end

	-- Aire: salto y aterrizaje
	if t.isLocal then
		if MotionState.jumpCount ~= t.lastJump then
			t.lastJump = MotionState.jumpCount
			footstep(t, "Walk", 0.9)
			cloth(t, 0.25)
		end
		if MotionState.landCount ~= t.lastLand then
			t.lastLand = MotionState.landCount
			onLanded(t, MotionState.landImpact)
		end
		if MotionState.stanceCount ~= t.lastStance then
			t.lastStance = MotionState.stanceCount
			cloth(t, 0.35)
		end
	else
		if not grounded then
			t.airMinVy = math.min(t.airMinVy, vel.Y)
			if t.grounded and vel.Y > 12 then
				footstep(t, "Walk", 0.9) -- impulso del salto
			end
		elseif not t.grounded then
			onLanded(t, -t.airMinVy)
			t.airMinVy = 0
		end
	end
	t.grounded = grounded

	-- Pisadas
	local moving = grounded and flatSpeed >= F.MinSpeed
	local gaitName = gaitOf(t, flatSpeed)
	if moving then
		if not t.moving then
			t.cycle = 0.4 -- el primer paso llega enseguida
			t.sinceStep = 0.8
		end
		local stride = ((F.Gaits :: any)[gaitName] or F.Gaits.Walk).Stride
		local advance = flatSpeed * dt / (stride * 2)
		local before = t.cycle
		t.cycle = (t.cycle + advance) % 1
		t.sinceStep += advance * 2
		if (before < 0.5 and t.cycle >= 0.5) or t.cycle < before then
			t.sinceStep = 0
			footstep(t, gaitName, 1)
		end
	elseif t.moving and grounded then
		-- al pararse, el pie que estaba en el aire se apoya
		if t.sinceStep > 0.35 then
			footstep(t, gaitName, 0.55)
		end
		t.sinceStep = 0
	end
	t.moving = moving
	if t.isLocal then
		MotionState.stepCycle = t.cycle
	end
end

-- ===== Reverberación del espacio =====
local DIRS: { Vector3 } = {}
for i = 0, 7 do
	local a = i / 8 * math.pi * 2
	table.insert(DIRS, Vector3.new(math.cos(a), 0, math.sin(a)))
end
local reverbTarget = { decay = 0.6, wet = -30 }
local nextProbe = 0

local function probeSpace()
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = if player.Character then { player.Character } else {}
	local origin = camera.CFrame.Position
	local range = F.ReverbProbeRange
	local ceiling = workspace:Raycast(origin, Vector3.new(0, range, 0), params)
	local total = 0
	for _, d in DIRS do
		local hit = workspace:Raycast(origin, d * range, params)
		total += if hit then hit.Distance else range
	end
	local avg = total / #DIRS
	if not ceiling then
		reverbTarget.decay, reverbTarget.wet = 0.5, -30 -- exterior: casi sin eco
		return
	end
	local decay = math.clamp(0.35 + avg * 0.045, 0.4, 3.2)
	local wet = math.clamp(-17 + avg * 0.16, -17, -6)
	local local_ = trackers[player.Character :: any]
	if local_ and local_.surface == "Carpet" then
		decay *= 0.6 -- la moqueta y el techo bajo absorben
		wet -= 3
	end
	reverbTarget.decay, reverbTarget.wet = decay, wet
end

-- ===== Respiración y latido =====
local function loop(id: string): Sound
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Looped = true
	s.Volume = 0
	s.SoundGroup = body
	s.Parent = SoundService
	return s
end
local breathing = loop(F.Breathing)
local heartbeat = loop(F.Heartbeat)

local function drive(s: Sound, target: number, speed: number, dt: number)
	s.Volume += (target - s.Volume) * (1 - math.exp(-2.5 * dt))
	s.PlaybackSpeed = speed
	if s.Volume > 0.01 then
		if not s.IsPlaying then
			s:Play()
		end
	elseif s.IsPlaying then
		s:Stop()
	end
end

-- ===== Bucle =====
RunService.Heartbeat:Connect(function(dt)
	for _, p in Players:GetPlayers() do
		local c = p.Character
		if c and not trackers[c] then
			track(p, c)
		end
	end
	for character, t in trackers do
		if not character.Parent or t.player.Character ~= character or not t.root.Parent then
			t.feet:Destroy()
			trackers[character] = nil
		else
			updateTracker(t, dt)
		end
	end

	local now = os.clock()
	if now >= nextProbe then
		nextProbe = now + F.ReverbProbeSeconds
		probeSpace()
	end
	local k = 1 - math.exp(-3 * dt)
	reverb.DecayTime += (reverbTarget.decay - reverb.DecayTime) * k
	reverb.WetLevel += (reverbTarget.wet - reverb.WetLevel) * k

	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	local alive = humanoid ~= nil and humanoid.Health > 0
	local exertion = MotionState.exertion
	local breathTarget = if alive then F.BreathingMaxVolume * math.clamp((exertion - 0.15) / 0.85, 0, 1) ^ 1.3 else 0
	drive(breathing, breathTarget, 0.92 + 0.16 * exertion, dt)
	local health = if humanoid and humanoid.MaxHealth > 0 then humanoid.Health / humanoid.MaxHealth else 1
	local danger = if alive then math.clamp(1 - health / F.HeartbeatBelow, 0, 1) else 0
	drive(heartbeat, F.HeartbeatMaxVolume * danger, 0.9 + 0.4 * danger, dt)
end)
