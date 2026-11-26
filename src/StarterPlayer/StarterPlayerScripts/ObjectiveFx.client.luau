--!strict
-- Animaciones locales de los objetivos y tesoros (solo visuales; el estado lo pone el servidor):
--   * Generadores (Workspace.RunObjectives.Generator_*): averiados chisporrotean de vez en cuando y la luz de estado parpadea; al fallar
--     una fase (atributo SparkAt) sueltan una lluvia de chispas; reparados (State = "Repaired") el ventilador arranca y gira, la palanca
--     baja y el motor vibra.
--   * Cajas fuertes: el dial gira solo mientras alguien la manipula (atributo Operator).
--   * Tesoros (Workspace.RunTreasure): la luz late suavemente y, al recogerlos (atributo CollectedBy), vuelan hacia quien los recogió
--     encogiéndose, con sonido.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local S = Config.Objectives.Sounds

local player = Players.LocalPlayer
local objectives = workspace:WaitForChild("RunObjectives", 60)
local treasure = workspace:WaitForChild("RunTreasure", 60)

local pickupSound = Instance.new("Sound")
pickupSound.Name = "PickupFx"
pickupSound.SoundId = S.Pickup.Id
pickupSound.Volume = S.Pickup.Volume
pickupSound.Parent = SoundService

-- ===== Chispas =====
local function sparkEmitter(att: Attachment): ParticleEmitter
	local e = att:FindFirstChild("FxSparks")
	if e and e:IsA("ParticleEmitter") then
		return e
	end
	local p = Instance.new("ParticleEmitter")
	p.Name = "FxSparks"
	p.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	p.Color = ColorSequence.new(Color3.fromRGB(255, 220, 140), Color3.fromRGB(255, 140, 40))
	p.LightEmission = 1
	p.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(1, 0) })
	p.Lifetime = NumberRange.new(0.25, 0.6)
	p.Speed = NumberRange.new(8, 16)
	p.SpreadAngle = Vector2.new(70, 70)
	p.Acceleration = Vector3.new(0, -40, 0)
	p.Drag = 2
	p.EmissionDirection = Enum.NormalId.Front
	p.Rate = 0
	p.Parent = att
	local flash = Instance.new("PointLight")
	flash.Name = "FxFlash"
	flash.Color = Color3.fromRGB(255, 190, 110)
	flash.Range = 12
	flash.Brightness = 0
	flash.Shadows = false
	flash.Parent = att
	return p
end

local function burst(model: Model, count: number)
	local att = model:FindFirstChild("SparkPoint", true)
	if not att or not att:IsA("Attachment") then
		return
	end
	local e = sparkEmitter(att)
	e:Emit(count)
	local flash = att:FindFirstChild("FxFlash")
	if flash and flash:IsA("PointLight") then
		flash.Brightness = 4
		task.delay(0.08, function()
			flash.Brightness = 0
		end)
	end
end

-- ===== Generadores =====
type GenFx = {
	model: Model,
	fan: Model?,
	fanBase: CFrame?,
	fanAngle: number,
	fanSpeed: number,
	lever: BasePart?,
	leverBase: CFrame?,
	nextSpark: number,
	statusLight: PointLight?,
}
local gens: { [Model]: GenFx } = {}

local function trackGenerator(model: Model)
	if gens[model] then
		return
	end
	local fan = model:FindFirstChild("Fan")
	local lever = model:FindFirstChild("Lever", true)
	local status = model:FindFirstChild("StatusLight", true)
	local fx: GenFx = {
		model = model,
		fan = if fan and fan:IsA("Model") then fan else nil,
		fanBase = if fan and fan:IsA("Model") then fan:GetPivot() else nil,
		fanAngle = 0,
		fanSpeed = 0,
		lever = if lever and lever:IsA("BasePart") then lever else nil,
		leverBase = if lever and lever:IsA("BasePart") then lever.CFrame else nil,
		nextSpark = os.clock() + math.random() * 4,
		statusLight = status and status:FindFirstChildOfClass("PointLight"),
	}
	gens[model] = fx
	model:GetAttributeChangedSignal("SparkAt"):Connect(function()
		burst(model, 40)
	end)
	model.AncestryChanged:Connect(function()
		if not model:IsDescendantOf(workspace) then
			gens[model] = nil
		end
	end)
end

-- ===== Cajas fuertes =====
type SafeFx = { model: Model, dial: { BasePart }, base: { CFrame }, angle: number, center: CFrame? }
local safes: { [Model]: SafeFx } = {}

local function trackSafe(model: Model)
	if safes[model] then
		return
	end
	local door = model:FindFirstChild("Door")
	local parts: { BasePart } = {}
	local base: { CFrame } = {}
	local center: CFrame? = nil
	if door then
		for _, name in { "Dial", "DialFace", "DialKnob" } do
			local p = door:FindFirstChild(name)
			if p and p:IsA("BasePart") then
				table.insert(parts, p)
				table.insert(base, p.CFrame)
				if name == "Dial" then
					center = p.CFrame
				end
			end
		end
	end
	safes[model] = { model = model, dial = parts, base = base, angle = 0, center = center }
	model.AncestryChanged:Connect(function()
		if not model:IsDescendantOf(workspace) then
			safes[model] = nil
		end
	end)
end

local function onObjective(child: Instance)
	if not child:IsA("Model") then
		return
	end
	if string.sub(child.Name, 1, 10) == "Generator_" then
		trackGenerator(child)
	elseif string.sub(child.Name, 1, 5) == "Safe_" then
		trackSafe(child)
	end
end

if objectives then
	objectives.ChildAdded:Connect(function(c)
		task.defer(onObjective, c) -- deja que lleguen los descendientes
	end)
	for _, c in objectives:GetChildren() do
		onObjective(c)
	end
end

-- ===== Tesoros =====
type TreasureFx = { object: Instance, glow: PointLight?, phase: number, flying: boolean }
local treasures: { [Instance]: TreasureFx } = {}

local function parts(object: Instance): { BasePart }
	local list: { BasePart } = {}
	if object:IsA("BasePart") then
		table.insert(list, object)
	end
	for _, d in object:GetDescendants() do
		if d:IsA("BasePart") then
			table.insert(list, d)
		end
	end
	return list
end

local function pivotOf(object: Instance): CFrame?
	if object:IsA("Model") then
		return object:GetPivot()
	elseif object:IsA("BasePart") then
		return object.CFrame
	end
	return nil
end

local function fly(fx: TreasureFx, userId: number)
	if fx.flying then
		return
	end
	fx.flying = true
	local object = fx.object
	local start = pivotOf(object)
	if not start then
		return
	end
	local list = parts(object)
	local rel: { CFrame } = {}
	for i, p in list do
		rel[i] = start:Inverse() * p.CFrame
	end
	local collector = Players:GetPlayerByUserId(userId)
	local mine = collector == player
	if mine then
		SoundService:PlayLocalSound(pickupSound)
	else
		local s = pickupSound:Clone()
		s.RollOffMaxDistance = 40
		s.Parent = list[1]
		s:Play()
	end
	local t0 = os.clock()
	local DURATION = 0.4
	local conn: RBXScriptConnection
	conn = RunService.RenderStepped:Connect(function()
		if not object.Parent then
			conn:Disconnect()
			return
		end
		local a = math.clamp((os.clock() - t0) / DURATION, 0, 1)
		local e = a * a * (3 - 2 * a)
		local target: Vector3
		local cam = workspace.CurrentCamera
		local head = collector and collector.Character and collector.Character:FindFirstChild("Head")
		if mine and cam then
			target = (cam.CFrame * CFrame.new(0, -1.2, -1.5)).Position
		elseif head and head:IsA("BasePart") then
			target = head.Position
		else
			target = start.Position + Vector3.new(0, 3, 0)
		end
		-- Arco: sube un poco antes de ir hacia la mano.
		local pos = start.Position:Lerp(target, e) + Vector3.new(0, math.sin(e * math.pi) * 1.2, 0)
		local k = 1 - 0.85 * e
		local cf = CFrame.new(pos) * start.Rotation * CFrame.Angles(0, e * math.pi, 0)
		for i, p in list do
			local r = rel[i]
			p.CFrame = cf * (r - r.Position + r.Position * k)
			p.LocalTransparencyModifier = e * 0.9
		end
		if a >= 1 then
			conn:Disconnect()
		end
	end)
end

local function trackTreasure(object: Instance)
	if treasures[object] then
		return
	end
	local glow = object:FindFirstChild("TreasureGlow", true)
	local fx: TreasureFx = {
		object = object,
		glow = if glow and glow:IsA("PointLight") then glow else nil,
		phase = math.random() * math.pi * 2,
		flying = false,
	}
	treasures[object] = fx
	local function check()
		local by = object:GetAttribute("CollectedBy")
		if type(by) == "number" then
			fly(fx, by)
		end
	end
	object:GetAttributeChangedSignal("CollectedBy"):Connect(check)
	check()
	object.AncestryChanged:Connect(function()
		if not object:IsDescendantOf(workspace) then
			treasures[object] = nil
		end
	end)
end

if treasure then
	treasure.ChildAdded:Connect(function(c)
		task.defer(trackTreasure, c)
	end)
	for _, c in treasure:GetChildren() do
		trackTreasure(c)
	end
end

-- ===== Bucle =====
local baseBrightness = Config.TreasureGlowBrightness
RunService.RenderStepped:Connect(function(dt)
	local now = os.clock()
	for model, fx in gens do
		local repaired = model:GetAttribute("State") == "Repaired"
		-- Ventilador: acelera al arrancar, se para si no hay energía.
		fx.fanSpeed += ((if repaired then 18 else 0) - fx.fanSpeed) * (1 - math.exp(-1.2 * dt))
		if fx.fan and fx.fanBase and fx.fanSpeed > 0.01 then
			fx.fanAngle = (fx.fanAngle + fx.fanSpeed * dt) % (math.pi * 2)
			fx.fan:PivotTo(fx.fanBase * CFrame.Angles(fx.fanAngle, 0, 0))
		end
		if fx.lever and fx.leverBase then
			local target = if repaired then fx.leverBase * CFrame.Angles(math.rad(60), 0, 0) else fx.leverBase
			fx.lever.CFrame = fx.lever.CFrame:Lerp(target, 1 - math.exp(-8 * dt))
		end
		local light = fx.statusLight
		if not repaired then
			-- Averiado: chispazos sueltos y piloto que parpadea.
			if now >= fx.nextSpark then
				fx.nextSpark = now + 3 + math.random() * 6
				burst(model, 8 + math.random(0, 8))
			end
			if light then
				light.Enabled = math.noise(now * 6, model:GetPivot().X) > -0.25
			end
		elseif light then
			light.Enabled = true
		end
	end
	for _, fx in safes do
		if fx.center and #fx.dial > 0 and fx.model:GetAttribute("Operator") ~= nil and fx.model:GetAttribute("State") ~= "Open" then
			fx.angle += dt * 2.5 * math.sin(now * 1.3)
			local c = fx.center
			local rot = c * CFrame.Angles(fx.angle, 0, 0) * c:Inverse() -- giro sobre el eje del dial (X local del cilindro)
			for i, p in fx.dial do
				p.CFrame = rot * fx.base[i]
			end
		end
	end
	for _, fx in treasures do
		local g = fx.glow
		if g and not fx.flying then
			g.Brightness = baseBrightness * (0.75 + 0.35 * math.sin(now * 2.2 + fx.phase))
		end
	end
end)
