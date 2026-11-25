--!strict
-- Rig de luz de linterna de un jugador, persistente y solo local (no se replica).
-- La parte vive en una carpeta propia de Workspace (no bajo Camera, que Roblox recrea) y se reutiliza:
-- encender/apagar solo cambia Enabled. Las propiedades solo se escriben cuando cambian.
-- Pensado para reutilizarse en cualquier nivel: no depende de ningún mapa.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local MAX_RANGE = 120 -- tope real de SpotLight.Range en Roblox

local LampRig = {}
LampRig.__index = LampRig

export type Rig = typeof(setmetatable(
	{} :: {
		part: Part,
		light: SpotLight,
		fill: SpotLight,
		dir: Vector3,
		on: boolean,
		range: number,
		level: number,
	},
	LampRig
))

local folder: Folder? = nil

local function getFolder(): Folder
	local f = folder
	if f and f.Parent then
		return f
	end
	local existing = workspace:FindFirstChild("LampRigs")
	if existing and existing:IsA("Folder") then
		f = existing
	else
		f = Instance.new("Folder")
		f.Name = "LampRigs"
		f.Parent = workspace
	end
	folder = f
	return f :: Folder
end

local function build(): (Part, SpotLight, SpotLight)
	local part = Instance.new("Part")
	part.Name = "LampBeam"
	part.Size = Vector3.new(0.2, 0.2, 0.2)
	part.Transparency = 1
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Parent = getFolder()
	local origin = Instance.new("Attachment")
	origin.Name = "Origin"
	origin.Parent = part
	local light = Instance.new("SpotLight")
	light.Name = "Main"
	light.Face = Enum.NormalId.Front
	light.Angle = Config.LampAngle
	light.Brightness = Config.LampBrightness
	light.Range = math.min(Config.LampRange, MAX_RANGE)
	light.Shadows = false
	light.Enabled = false
	light.Parent = part
	-- Relleno: cono ancho y corto, tenue, para que el suelo cercano no quede a oscuras.
	local fill = Instance.new("SpotLight")
	fill.Name = "Fill"
	fill.Face = Enum.NormalId.Front
	fill.Angle = Config.LampFillAngle
	fill.Range = Config.LampFillRange
	fill.Brightness = Config.LampFillBrightness
	fill.Shadows = false
	fill.Enabled = false
	fill.Parent = part
	return part, light, fill
end

function LampRig.new(initialDir: Vector3): Rig
	local part, light, fill = build()
	return setmetatable({
		part = part,
		light = light,
		fill = fill,
		dir = initialDir,
		on = false,
		range = light.Range,
		level = 0,
	}, LampRig)
end

-- Recrea la parte si algo la destruyó (limpieza de Workspace, reaparición del mapa...).
function LampRig.Validate(self: Rig)
	if not self.part.Parent or not self.light.Parent or not self.fill.Parent then
		self.part:Destroy()
		self.part, self.light, self.fill = build()
		self.range = self.light.Range
		self.level = 0
		self.on = false
	end
end

-- Nivel de la mejora "Luz potente": más brillo y más ángulo (no alcance, que está topado en 120).
function LampRig.SetUpgrade(self: Rig, level: number)
	if self.level ~= level then
		self.level = level
		local U = Config.Upgrades.Lamp
		self.light.Brightness = Config.LampBrightness + level * U.BrightnessBonus
		self.light.Angle = math.min(120, Config.LampAngle + level * U.AngleBonus)
	end
end

function LampRig.SetEnabled(self: Rig, on: boolean)
	if self.on ~= on then
		self.on = on
		self.light.Enabled = on
		self.fill.Enabled = on
	end
end

-- Coloca el rig y aplica el alcance (solo escribe si cambia).
function LampRig.Update(self: Rig, origin: Vector3, dir: Vector3, range: number)
	self.part.CFrame = CFrame.lookAt(origin, origin + dir)
	range = math.min(range, MAX_RANGE)
	if range ~= self.range then
		self.range = range
		self.light.Range = range
	end
end

function LampRig.Destroy(self: Rig)
	self.part:Destroy()
end

return LampRig
