--!strict
-- Círculo de luz proyectado donde la linterna toca una superficie. Solo local.
-- Parte fina orientada a la normal con SurfaceGui + ImageLabel (gradiente radial, LightInfluence = 0).
-- Respaldo si no hay imagen (Config.LampHotspotImage == ""): 3 discos Cylinder Neon concéntricos.
-- Reutilizable: no depende de ningún nivel; solo necesita Workspace.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local QualityTier = require(script.Parent:WaitForChild("QualityTier"))

local MAX_RETRIES = 4

local LampHotspot = {}
LampHotspot.__index = LampHotspot

export type Hotspot = typeof(setmetatable(
	{} :: {
		part: Part,
		gui: SurfaceGui?,
		discs: { Part },
		pos: Vector3?,
		normal: Vector3,
		radius: number,
		shown: boolean,
		level: number,
		bounce: PointLight,
		target: Attachment,
		shaft: Beam,
		motes: ParticleEmitter,
		params: RaycastParams,
	},
	LampHotspot
))

local function newPart(name: string): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Transparency = 1
	part.Size = Vector3.new(1, 1, Config.LampHotspotOffset)
	return part
end

function LampHotspot.new(parent: Instance): Hotspot
	local part = newPart("LampHotspot")
	local gui: SurfaceGui? = nil
	local discs: { Part } = {}
	if Config.LampHotspotImage ~= "" then
		local g = Instance.new("SurfaceGui")
		g.Face = Enum.NormalId.Front
		g.LightInfluence = 0
		g.Brightness = Config.LampHotspotBrightness
		g.AlwaysOnTop = false
		g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		g.PixelsPerStud = 25
		local img = Instance.new("ImageLabel")
		img.BackgroundTransparency = 1
		img.Size = UDim2.fromScale(1, 1)
		img.Image = Config.LampHotspotImage
		img.ImageColor3 = Config.LampHotspotColor
		img.Parent = g
		g.Parent = part
		gui = g
	else
		for i = 1, 3 do
			local d = newPart("Disc" .. i)
			d.Shape = Enum.PartType.Cylinder
			d.Material = Enum.Material.Neon
			d.Color = Config.LampHotspotColor
			d.Transparency = 0.9 - 0.1 * (i - 1) -- los discos pequeños se suman: centro más brillante
			d.Parent = part
			table.insert(discs, d)
		end
	end
	-- Rebote, haz y motas (solo se activan en calidad media/alta; ver applyQuality).
	local bounce = Instance.new("PointLight")
	bounce.Name = "Bounce"
	bounce.Color = Config.LampHotspotColor
	bounce.Brightness = Config.LampBounceBrightness
	bounce.Shadows = false
	bounce.Enabled = false
	bounce.Parent = part
	local target = Instance.new("Attachment")
	target.Name = "Target"
	target.Parent = part
	local shaft = Instance.new("Beam")
	shaft.Name = "Shaft"
	shaft.Attachment1 = target
	shaft.Color = ColorSequence.new(Config.LampHotspotColor)
	shaft.Transparency = NumberSequence.new(Config.LampShaftTransparency)
	shaft.LightEmission = 1
	shaft.LightInfluence = 0
	shaft.FaceCamera = true
	shaft.Segments = 1
	shaft.Width0 = Config.LampShaftStartWidth
	shaft.Enabled = false
	shaft.Parent = part
	local motes = Instance.new("ParticleEmitter")
	motes.Name = "Motes"
	motes.Enabled = false
	motes.EmissionDirection = Enum.NormalId.Front -- hacia donde apunta la linterna (se mueve al rig en applyQuality)
	motes.Rate = Config.LampMoteRate
	motes.Lifetime = NumberRange.new(1.5, 2.5)
	motes.Speed = NumberRange.new(10, 24)
	motes.SpreadAngle = Vector2.new(Config.LampAngle * 0.5, Config.LampAngle * 0.5)
	motes.Size = NumberSequence.new(0.12)
	motes.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.2, 0.5), NumberSequenceKeypoint.new(1, 1) })
	motes.LightEmission = 1
	motes.LightInfluence = 0
	motes.Color = ColorSequence.new(Config.LampHotspotColor)
	motes.Parent = part
	part.Parent = parent
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.IgnoreWater = true
	params.RespectCanCollide = false
	return setmetatable({
		part = part,
		gui = gui,
		discs = discs,
		pos = nil,
		normal = Vector3.yAxis,
		radius = Config.LampHotspotMinRadius,
		shown = false,
		level = 0,
		bounce = bounce,
		target = target,
		shaft = shaft,
		motes = motes,
		params = params,
	}, LampHotspot)
end

local function setShown(self: Hotspot, on: boolean)
	if self.shown == on then
		return
	end
	self.shown = on
	if self.gui then
		self.gui.Enabled = on
	end
	for _, d in self.discs do
		d.Parent = if on then self.part else nil
	end
end

-- Rebote, haz y motas solo en calidad media/alta y mientras el círculo está visible.
local function applyQuality(self: Hotspot, originAtt: Attachment?)
	local on = self.shown and not QualityTier.IsLow and originAtt ~= nil
	self.bounce.Enabled = on
	self.shaft.Enabled = on and Config.LampShaftEnabled
	self.motes.Enabled = on and Config.LampMoteRate > 0
	if on and originAtt then
		self.shaft.Attachment0 = originAtt
		if self.motes.Parent ~= originAtt.Parent then
			self.motes.Parent = originAtt.Parent
		end
	end
end

-- Raycast desde el origen: ignora partes casi invisibles (p. ej. Pared_*) y reintenta tras ellas.
local function cast(self: Hotspot, origin: Vector3, dir: Vector3, range: number): RaycastResult?
	local excluded: { Instance } = {}
	local exclude = self.params.FilterDescendantsInstances
	for _, e in exclude do
		table.insert(excluded, e)
	end
	local from = origin
	local remaining = range
	for _ = 1, MAX_RETRIES do
		self.params.FilterDescendantsInstances = excluded
		local hit = workspace:Raycast(from, dir * remaining, self.params)
		if not hit then
			self.params.FilterDescendantsInstances = exclude
			return nil
		end
		if hit.Instance.Transparency < 0.99 then
			self.params.FilterDescendantsInstances = exclude
			return hit
		end
		table.insert(excluded, hit.Instance)
		remaining = range - (hit.Position - origin).Magnitude
		if remaining <= 0 then
			break
		end
	end
	self.params.FilterDescendantsInstances = exclude
	return nil
end

-- El círculo es un disco plano: en paredes curvas o esquinas sus bordes se hunden en la geometría vecina y se ven
-- recortados como cuadros. Se sondean 4 puntos del borde y, si la superficie se aleja del plano del impacto, se reduce el radio.
local function fitRadius(self: Hotspot, hit: RaycastResult, radius: number): number
	local n = hit.Normal
	local t1 = if math.abs(n.Y) < 0.9 then n:Cross(Vector3.yAxis).Unit else n:Cross(Vector3.xAxis).Unit
	local t2 = n:Cross(t1)
	local dirs = { t1, -t1, t2, -t2 }
	-- Nunca por debajo de una fracción del radio ideal: de lejos el círculo debe seguir leyéndose como círculo.
	local floor = math.max(Config.LampHotspotMinRadius, radius * Config.LampHotspotFitMinScale)
	for _ = 1, Config.LampHotspotFitSteps do
		-- La tolerancia crece con el radio: un círculo grande admite más curvatura que uno pequeño.
		local tol = math.max(Config.LampHotspotFlatTolerance, radius * Config.LampHotspotFlatToleranceScale)
		local ok = true
		for _, d in dirs do
			local from = hit.Position + n * 2 + d * radius * 0.9
			local probe = workspace:Raycast(from, -n * (2 + tol + 2), self.params)
			if not probe or math.abs((probe.Position - hit.Position):Dot(n)) > tol or probe.Normal:Dot(n) < 0.9 then
				ok = false
				break
			end
		end
		if ok or radius <= floor then
			return math.max(radius, floor)
		end
		radius = math.max(floor, radius * 0.8)
	end
	return radius
end

-- Qué no debe recibir el círculo: personaje propio y efectos locales.
function LampHotspot.SetIgnore(self: Hotspot, list: { Instance })
	self.params.FilterDescendantsInstances = list
end

-- Nivel de "Luz potente": círculo más grande y brillante.
function LampHotspot.SetUpgrade(self: Hotspot, level: number)
	if self.level ~= level and self.gui then
		self.level = level
		self.gui.Brightness = Config.LampHotspotBrightness + level * Config.Upgrades.Lamp.HotspotBrightnessBonus
	end
	self.level = level
end

function LampHotspot.Hide(self: Hotspot)
	setShown(self, false)
	applyQuality(self, nil)
	self.pos = nil
end

function LampHotspot.Update(self: Hotspot, origin: Vector3, dir: Vector3, range: number, dt: number, originAtt: Attachment?)
	local hit = cast(self, origin, dir, range)
	if not hit then
		setShown(self, false)
		self.pos = nil
		applyQuality(self, originAtt)
		return
	end
	local dist = (hit.Position - origin).Magnitude
	local scale = 1 + self.level * Config.Upgrades.Lamp.HotspotScaleBonus
	local radius = math.clamp(dist * math.tan(math.rad(Config.LampHotspotHalfAngle)) * scale, Config.LampHotspotMinRadius, Config.LampHotspotMaxRadius)
	radius = fitRadius(self, hit, radius)
	local target = hit.Position + hit.Normal * Config.LampHotspotOffset
	local alpha = math.min(1, dt * Config.LampHotspotSmoothing)
	local prev = self.pos
	if not prev or (target - prev).Magnitude > Config.LampHotspotSnapDistance or not self.shown then
		self.pos, self.normal, self.radius = target, hit.Normal, radius -- snap (primer cuadro o teletransporte)
	else
		self.pos = prev:Lerp(target, alpha)
		self.normal = self.normal:Lerp(hit.Normal, alpha).Unit
		self.radius += (radius - self.radius) * alpha
	end
	local pos = self.pos :: Vector3
	local cf = CFrame.lookAt(pos, pos + self.normal)
	local d = self.radius * 2
	self.part.Size = Vector3.new(d, d, Config.LampHotspotOffset)
	self.part.CFrame = cf
	if #self.discs > 0 then
		-- Cylinder tiene su eje en X: se gira para que quede plano sobre la superficie.
		for i, disc in self.discs do
			local s = d * (1 - 0.3 * (i - 1))
			disc.Size = Vector3.new(0.02, s, s)
			disc.CFrame = cf * CFrame.new(0, 0, -0.01 * i) * CFrame.Angles(0, math.rad(90), 0)
		end
	end
	setShown(self, true)
	self.bounce.Range = self.radius * Config.LampBounceRangeScale
	self.shaft.Width1 = self.radius * 1.2
	applyQuality(self, originAtt)
end

function LampHotspot.Destroy(self: Hotspot)
	self.part:Destroy()
end

return LampHotspot
