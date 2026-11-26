--!strict
-- Modelos de objetivos construidos con piezas (low poly, colores planos, como el mapa). Si GameAssets tiene una plantilla con el mismo
-- contrato de nombres (Config.Objectives.*.Template), se usa esa. Todo se construye con el pivote en el centro del suelo y el frente
-- hacia -Z; Props.Place lo apoya en el suelo y le da la espalda a la pared más cercana.
--
-- Contrato (lo usan ObjectiveService y ObjectiveFx):
--   Generator: Body (PrimaryPart), Panel.PromptAttachment, Panel.SparkPoint, Screen (SurfaceGui Display.Label), StatusLight (+PointLight),
--              Fan (Model, gira al repararse), Radiator, Pipe.ExhaustPoint (humo), Hum (Sound en Body), PowerGlow (PointLight en Body).
--   Safe:      Body (PrimaryPart), Door (Model: Plate con Attachment Hinge, Dial, StatusLight), Top.PromptAttachment, Top.InteriorLight,
--              Bottom.LootPoint / Shelf.LootPoint2 (dónde aparece el botín).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Assets = require(script.Parent:WaitForChild("Assets"))

local Props = {}

local AXIS_Z = CFrame.Angles(0, math.rad(90), 0) -- el eje de los cilindros (X) pasa a apuntar a Z
local AXIS_Y = CFrame.Angles(0, 0, math.rad(90)) -- el eje de los cilindros pasa a apuntar a Y

local function part(model: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?, shape: Enum.PartType?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.Metal
	p.Anchored = true
	p.CanCollide = false
	p.CastShadow = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if shape then
		p.Shape = shape
	end
	p.Parent = model
	return p
end

local function attachment(parent: BasePart, name: string, worldPos: Vector3): Attachment
	local a = Instance.new("Attachment")
	a.Name = name
	a.Parent = parent
	a.WorldPosition = worldPos
	return a
end

local function sound(parent: Instance, name: string, def: { Id: string, Volume: number }, looped: boolean, range: number): Sound
	local s = Instance.new("Sound")
	s.Name = name
	s.SoundId = def.Id
	s.Volume = def.Volume
	s.Looped = looped
	s.RollOffMode = Enum.RollOffMode.InverseTapered
	s.RollOffMinDistance = 6
	s.RollOffMaxDistance = range
	s.Parent = parent
	return s
end

-- Fija el pivote del modelo en el origen de construcción (centro del suelo) aunque tenga PrimaryPart.
local function setPivot(model: Model, primary: BasePart)
	model.PrimaryPart = primary
	primary.PivotOffset = primary.CFrame:Inverse() * CFrame.new()
end

-- ===== Generador =====
local MUSTARD = Color3.fromRGB(168, 140, 64)
local STEEL = Color3.fromRGB(70, 76, 72)
local DARK = Color3.fromRGB(32, 34, 33)
local BLADE = Color3.fromRGB(138, 138, 126)
local HAZARD = Color3.fromRGB(214, 172, 52)

local function buildGenerator(): Model
	local m = Instance.new("Model")
	m.Name = "Generator"

	-- Bancada con franjas de peligro en el frente
	local skid = part(m, "Skid", Vector3.new(7.6, 0.5, 4.4), CFrame.new(0, 0.25, 0), DARK, Enum.Material.DiamondPlate)
	for i = 0, 11 do
		local x = -3.5 + i * 0.6 + 0.3
		part(m, "Hazard", Vector3.new(0.6, 0.3, 0.05), CFrame.new(x, 0.28, -2.22) * CFrame.Angles(0, 0, math.rad(0)), if i % 2 == 0 then HAZARD else DARK, Enum.Material.SmoothPlastic)
	end

	-- Bloque motor
	local body = part(m, "Body", Vector3.new(4.4, 3.0, 3.4), CFrame.new(-1.1, 2.0, 0.1), MUSTARD)
	part(m, "BodyTop", Vector3.new(4.0, 0.3, 3.0), CFrame.new(-1.1, 3.65, 0.1), Color3.fromRGB(140, 116, 52))
	for i = 0, 3 do
		part(m, "Rib", Vector3.new(0.12, 2.4, 0.08), CFrame.new(-2.9 + i * 0.25, 2.0, -1.66), Color3.fromRGB(140, 116, 52))
	end

	-- Depósito de combustible encima, con abrazaderas
	part(m, "Tank", Vector3.new(3.2, 1.3, 1.3), CFrame.new(-1.1, 4.45, 0.55), Color3.fromRGB(120, 44, 36), Enum.Material.Metal, Enum.PartType.Cylinder)
	for _, x in { -2.2, 0.0 } do
		part(m, "Strap", Vector3.new(0.18, 1.42, 1.42), CFrame.new(x, 4.45, 0.55), DARK, Enum.Material.Metal, Enum.PartType.Cylinder)
	end
	part(m, "TankCap", Vector3.new(0.25, 0.45, 0.45), CFrame.new(-0.4, 5.15, 0.55) * AXIS_Y, DARK, Enum.Material.Metal, Enum.PartType.Cylinder)

	-- Radiador con ventilador visible al frente
	local radiator = part(m, "Radiator", Vector3.new(2.6, 3.6, 3.8), CFrame.new(2.35, 2.3, 0), STEEL)
	part(m, "FanRing", Vector3.new(0.2, 2.7, 2.7), CFrame.new(2.35, 2.35, -1.95) * AXIS_Z, DARK, Enum.Material.Metal, Enum.PartType.Cylinder)
	local fan = Instance.new("Model")
	fan.Name = "Fan"
	fan.Parent = m
	local hubCf = CFrame.new(2.35, 2.35, -2.08)
	local hub = part(fan, "FanHub", Vector3.new(0.25, 0.55, 0.55), hubCf * AXIS_Z, Color3.fromRGB(90, 90, 84), Enum.Material.Metal, Enum.PartType.Cylinder)
	for k = 0, 3 do
		part(fan, "Blade", Vector3.new(0.4, 1.0, 0.06), hubCf * CFrame.Angles(0, 0, k * math.pi / 2) * CFrame.new(0, 0.62, 0) * CFrame.Angles(0, math.rad(28), 0), BLADE)
	end
	fan.PrimaryPart = hub
	for i = 0, 4 do
		part(m, "Grille", Vector3.new(2.4, 0.08, 0.08), CFrame.new(2.35, 1.35 + i * 0.5, -2.2), DARK)
	end

	-- Escape
	local pipe = part(m, "Pipe", Vector3.new(1.8, 0.45, 0.45), CFrame.new(3.0, 5.0, 1.0) * AXIS_Y, DARK, Enum.Material.Metal, Enum.PartType.Cylinder)
	part(m, "PipeCap", Vector3.new(0.15, 0.62, 0.62), CFrame.new(3.0, 5.92, 1.0) * AXIS_Y, Color3.fromRGB(50, 50, 48), Enum.Material.Metal, Enum.PartType.Cylinder)
	local exhaust = attachment(pipe, "ExhaustPoint", Vector3.new(3.0, 6.05, 1.0))

	-- Panel de control: pantalla, luz de estado, palanca y cable
	local panel = part(m, "Panel", Vector3.new(2.0, 1.7, 0.15), CFrame.new(-1.4, 2.3, -1.68), DARK)
	local screen = part(m, "Screen", Vector3.new(1.4, 0.7, 0.06), CFrame.new(-1.4, 2.6, -1.78), Color3.fromRGB(18, 28, 22), Enum.Material.SmoothPlastic)
	local status = part(m, "StatusLight", Vector3.new(0.32, 0.32, 0.1), CFrame.new(-0.75, 1.82, -1.78), Color3.fromRGB(220, 50, 40), Enum.Material.Neon)
	part(m, "LeverBase", Vector3.new(0.4, 0.2, 0.1), CFrame.new(-1.9, 1.82, -1.78), Color3.fromRGB(60, 60, 58))
	part(m, "Lever", Vector3.new(0.1, 0.5, 0.1), CFrame.new(-1.9, 1.98, -1.86) * CFrame.Angles(math.rad(-30), 0, 0), Color3.fromRGB(180, 40, 30), Enum.Material.SmoothPlastic)
	part(m, "Cable", Vector3.new(0.14, 1.3, 0.14), CFrame.new(-0.4, 1.15, -1.72), DARK, Enum.Material.Plastic)
	attachment(panel, "PromptAttachment", Vector3.new(-1.4, 2.6, -2.3))
	attachment(panel, "SparkPoint", Vector3.new(-1.4, 2.6, -1.9))

	local gui = Instance.new("SurfaceGui")
	gui.Name = "Display"
	gui.Face = Enum.NormalId.Front
	gui.CanvasSize = Vector2.new(280, 140)
	gui.LightInfluence = 0
	gui.Brightness = 1.4
	gui.Parent = screen
	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.FontFace = Font.new("rbxasset://fonts/families/RobotoMono.json", Enum.FontWeight.Bold)
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(220, 70, 50)
	label.Text = "SIN ENERGÍA"
	label.Parent = gui

	local light = Instance.new("PointLight")
	light.Color = status.Color
	light.Range = 7
	light.Brightness = 1.5
	light.Shadows = false
	light.Parent = status

	local glow = Instance.new("PointLight")
	glow.Name = "PowerGlow"
	glow.Color = Color3.fromRGB(255, 214, 150)
	glow.Range = 16
	glow.Brightness = 1.2
	glow.Enabled = false
	glow.Parent = body

	-- Humo: fino desde el panel mientras está averiado; del escape cuando funciona.
	local function smoke(parent: Attachment, name: string, rate: number, color: Color3): ParticleEmitter
		local e = Instance.new("ParticleEmitter")
		e.Name = name
		e.Texture = "rbxasset://textures/particles/smoke_main.dds"
		e.Color = ColorSequence.new(color)
		e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(1, 2.2) })
		e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(1, 1) })
		e.Lifetime = NumberRange.new(1.6, 2.6)
		e.Speed = NumberRange.new(1.2, 2.2)
		e.SpreadAngle = Vector2.new(12, 12)
		e.EmissionDirection = Enum.NormalId.Top
		e.Rate = rate
		e.LightInfluence = 0.6
		e.Parent = parent
		return e
	end
	local brokenSmoke = smoke(attachment(radiator, "SmokePoint", Vector3.new(1.6, 4.15, -0.6)), "BrokenSmoke", 3, Color3.fromRGB(60, 60, 60))
	brokenSmoke.Enabled = true
	local runSmoke = smoke(exhaust, "ExhaustSmoke", 6, Color3.fromRGB(90, 90, 88))
	runSmoke.Enabled = false

	sound(body, "Hum", Config.Objectives.Sounds.GeneratorHum, true, 70)
	sound(panel, "Spark", Config.Objectives.Sounds.Spark, false, 60)

	-- Colisión sólida solo en los volúmenes grandes
	for _, p in { skid, body, radiator } do
		p.CanCollide = true
	end
	setPivot(m, body)
	return m
end

-- ===== Caja fuerte =====
local SAFE = Color3.fromRGB(64, 74, 68)
local SAFE_IN = Color3.fromRGB(38, 42, 40)
local BRASS = Color3.fromRGB(156, 132, 74)
local PAPER = Color3.fromRGB(225, 218, 196)

local function buildSafe(): Model
	local m = Instance.new("Model")
	m.Name = "Safe"
	local t = 0.35
	local W, H, D, base = 3.6, 4.4, 3.2, 0.3
	local cy = base + H / 2

	local back = part(m, "Body", Vector3.new(W, H, t), CFrame.new(0, cy, D / 2 - t / 2), SAFE)
	part(m, "SideL", Vector3.new(t, H, D), CFrame.new(-W / 2 + t / 2, cy, 0), SAFE)
	part(m, "SideR", Vector3.new(t, H, D), CFrame.new(W / 2 - t / 2, cy, 0), SAFE)
	local top = part(m, "Top", Vector3.new(W - 2 * t, t, D), CFrame.new(0, base + H - t / 2, 0), SAFE)
	local bottom = part(m, "Bottom", Vector3.new(W - 2 * t, t, D), CFrame.new(0, base + t / 2, 0), SAFE)
	part(m, "Lining", Vector3.new(W - 2 * t - 0.02, H - 2 * t - 0.02, 0.05), CFrame.new(0, cy, D / 2 - t - 0.03), SAFE_IN, Enum.Material.Fabric)
	local shelf = part(m, "Shelf", Vector3.new(W - 2 * t, 0.12, D - t - 0.1), CFrame.new(0, cy + 0.1, -0.05), SAFE_IN)
	for _, x in { -1.45, 1.45 } do
		for _, z in { -1.2, 1.2 } do
			part(m, "Foot", Vector3.new(0.45, base, 0.45), CFrame.new(x, base / 2, z), Color3.fromRGB(28, 30, 29))
		end
	end
	for _, y in { base + 1.0, base + H - 1.0 } do
		part(m, "HingePin", Vector3.new(0.8, 0.26, 0.26), CFrame.new(-W / 2 - 0.05, y, -D / 2 - 0.2) * AXIS_Y, Color3.fromRGB(40, 42, 41), Enum.Material.Metal, Enum.PartType.Cylinder)
	end
	attachment(bottom, "LootPoint", Vector3.new(0, base + t, 0.05))
	attachment(shelf, "LootPoint2", Vector3.new(0, cy + 0.16, 0.05))
	attachment(top, "PromptAttachment", Vector3.new(0, 2.6, -D / 2 - 1.2))

	local inner = Instance.new("PointLight")
	inner.Name = "InteriorLight"
	inner.Color = Color3.fromRGB(255, 220, 160)
	inner.Range = 7
	inner.Brightness = 1.2
	inner.Enabled = false
	inner.Parent = top

	-- Puerta (Model aparte que gira sobre la bisagra izquierda)
	local door = Instance.new("Model")
	door.Name = "Door"
	door.Parent = m
	local dz = -D / 2 - 0.2
	local plate = part(door, "Plate", Vector3.new(W, H, 0.4), CFrame.new(0, cy, dz), SAFE)
	part(door, "Inset", Vector3.new(W - 0.6, H - 0.6, 0.05), CFrame.new(0, cy, dz - 0.22), Color3.fromRGB(72, 83, 76))
	part(door, "Dial", Vector3.new(0.18, 1.3, 1.3), CFrame.new(0.35, cy + 0.6, dz - 0.3) * AXIS_Z, Color3.fromRGB(46, 48, 47), Enum.Material.Metal, Enum.PartType.Cylinder)
	part(door, "DialFace", Vector3.new(0.05, 1.05, 1.05), CFrame.new(0.35, cy + 0.6, dz - 0.4) * AXIS_Z, Color3.fromRGB(190, 184, 166), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
	part(door, "DialKnob", Vector3.new(0.3, 0.45, 0.45), CFrame.new(0.35, cy + 0.6, dz - 0.5) * AXIS_Z, Color3.fromRGB(40, 40, 40), Enum.Material.Metal, Enum.PartType.Cylinder)
	part(door, "DialMark", Vector3.new(0.08, 0.22, 0.03), CFrame.new(0.35, cy + 1.36, dz - 0.22), PAPER, Enum.Material.Neon)
	local hcf = CFrame.new(0.35, cy - 0.8, dz - 0.3)
	part(door, "HandleHub", Vector3.new(0.3, 0.45, 0.45), hcf * AXIS_Z, BRASS, Enum.Material.Metal, Enum.PartType.Cylinder)
	for k = 0, 2 do
		local spoke = hcf * CFrame.Angles(0, 0, k * math.pi * 2 / 3) * CFrame.new(0, 0.45, -0.05)
		part(door, "Spoke", Vector3.new(0.12, 0.9, 0.12), spoke, BRASS)
		part(door, "SpokeEnd", Vector3.new(0.24, 0.24, 0.24), spoke * CFrame.new(0, 0.45, 0), BRASS, Enum.Material.Metal, Enum.PartType.Ball)
	end
	part(door, "Badge", Vector3.new(1.0, 0.28, 0.03), CFrame.new(-0.75, cy + 1.6, dz - 0.22), BRASS, Enum.Material.Metal)
	local status = part(door, "StatusLight", Vector3.new(0.5, 0.14, 0.05), CFrame.new(0.35, cy + 1.6, dz - 0.22), Color3.fromRGB(220, 50, 40), Enum.Material.Neon)
	local light = Instance.new("PointLight")
	light.Color = status.Color
	light.Range = 5
	light.Brightness = 1
	light.Shadows = false
	light.Parent = status
	attachment(plate, "Hinge", Vector3.new(-W / 2, cy, dz))
	door.PrimaryPart = plate

	sound(plate, "Click", Config.Objectives.Sounds.DialClick, false, 30)
	sound(plate, "Open", Config.Objectives.Sounds.SafeOpen, false, 50)
	sound(plate, "Wrong", Config.Objectives.Sounds.Wrong, false, 40)

	for _, name in { "Body", "SideL", "SideR", "Top", "Bottom" } do
		(m:FindFirstChild(name) :: BasePart).CanCollide = true
	end
	plate.CanCollide = true
	setPivot(m, back)
	return m
end

-- Plantilla de GameAssets si existe; si no, el modelo de piezas.
function Props.Make(kind: "Generator" | "Safe"): Model
	local def = (Config.Objectives :: any)[kind]
	local template = def and def.Template and Assets.Find(def.Template)
	if template and template:IsA("Model") then
		return template:Clone()
	end
	return if kind == "Generator" then buildGenerator() else buildSafe()
end

-- Apoya el modelo en el suelo bajo `point` y le da la espalda a la pared más cercana (si hay una a menos de `reach` studs), pegándolo
-- a ella. `ignore`: instancias que los rayos atraviesan (marcadores, decoración sin colisión, jugadores...). `solids`: piezas visibles
-- del mapa (muebles incluidos, aunque tengan CanQuery = false) con las que no debe solaparse; si choca, se desliza junto a la pared.
function Props.Place(model: Model, point: Vector3, ignore: { Instance }, solids: { BasePart }?, reach: number?)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	params.IgnoreWater = true
	local _, size = model:GetBoundingBox()
	local depth = size.Z
	local origin = point + Vector3.new(0, 3, 0)
	local best: RaycastResult? = nil
	local bestDir = Vector3.zAxis
	for _, dir in { Vector3.xAxis, -Vector3.xAxis, Vector3.zAxis, -Vector3.zAxis } do
		local hit = workspace:Raycast(origin, dir * (reach or 12), params)
		if hit and (not best or hit.Distance < (best :: RaycastResult).Distance) then
			best = hit
			bestDir = dir
		end
	end
	local center = point
	if best then
		-- Espalda contra la pared: el centro queda a medio fondo (+holgura) de ella.
		local wallPoint = best.Position
		center = Vector3.new(wallPoint.X, point.Y, wallPoint.Z) - bestDir * (depth / 2 + 0.25)
	end
	-- El frente del modelo es -Z: mirar en sentido contrario a la pared.
	local look = -bestDir
	local side = Vector3.new(-look.Z, 0, look.X) -- a lo largo de la pared
	-- Piezas cercanas (caja alineada a los ejes de cada una) para comprobar solapes sin depender de CanQuery.
	type Box = { min: Vector3, max: Vector3 }
	local near: { Box } = {}
	for _, p in solids or {} do
		if (p.Position - point).Magnitude < 20 + p.Size.Magnitude / 2 then
			local cf = p.CFrame
			local h = p.Size / 2
			local e = Vector3.new(
				math.abs(cf.RightVector.X) * h.X + math.abs(cf.UpVector.X) * h.Y + math.abs(cf.LookVector.X) * h.Z,
				math.abs(cf.RightVector.Y) * h.X + math.abs(cf.UpVector.Y) * h.Y + math.abs(cf.LookVector.Y) * h.Z,
				math.abs(cf.RightVector.Z) * h.X + math.abs(cf.UpVector.Z) * h.Y + math.abs(cf.LookVector.Z) * h.Z
			)
			table.insert(near, { min = cf.Position - e, max = cf.Position + e })
		end
	end
	local function frameAt(c: Vector3): CFrame
		local down = workspace:Raycast(c + Vector3.new(0, 4, 0), Vector3.new(0, -12, 0), params)
		local floorY = if down then down.Position.Y else point.Y
		local base = Vector3.new(c.X, floorY, c.Z)
		return CFrame.lookAt(base, base + look)
	end
	local function blocked(cf: CFrame): boolean
		-- El modelo mira a lo largo de X o Z: su caja en mundo se obtiene girando el tamaño.
		local half = Vector3.new(size.X / 2 + 0.3, size.Y / 2 - 0.35, size.Z / 2 - 0.35) -- holgura a los lados, tolerancia contra pared y suelo
		local sx = math.abs(cf.LookVector.X) > 0.5
		local hx, hz = if sx then half.Z else half.X, if sx then half.X else half.Z
		local c = cf.Position + Vector3.new(0, size.Y / 2 + 0.35, 0)
		local mn, mx = c - Vector3.new(hx, half.Y, hz), c + Vector3.new(hx, half.Y, hz)
		for _, b in near do
			if mn.X < b.max.X and mx.X > b.min.X and mn.Y < b.max.Y and mx.Y > b.min.Y and mn.Z < b.max.Z and mx.Z > b.min.Z then
				return true
			end
		end
		return false
	end
	-- Si choca con muebles del mapa, se desliza a lo largo de la pared hasta encontrar hueco (máx. 8 studs).
	local chosen = frameAt(center)
	for _, offset in { 0, 1.5, -1.5, 3, -3, 4.5, -4.5, 6, -6, 8, -8 } do
		local cf = frameAt(center + side * offset)
		if not blocked(cf) then
			chosen = cf
			break
		end
	end
	model:PivotTo(chosen)
end

return Props
