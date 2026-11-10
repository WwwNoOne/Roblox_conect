--!strict
-- Densidad del agua local al cliente: solo cuando la cámara está dentro de agua de Terrain.
-- Más profundo = más denso y oscuro. La lámpara encendida (y su mejora) reduce la densidad,
-- así que se ve más lejos. Usa Atmosphere: Lighting.Fog no se aplica dentro de agua de Terrain.
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local TimeOfDay = require(Shared:WaitForChild("TimeOfDay"))
local W = Config.Water
local player = Players.LocalPlayer
local camera = workspace.CurrentCamera :: Camera
local terrain = workspace.Terrain

-- Atmosphere propia si la plantilla no trae una; guarda los valores de fuera del agua.
local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
if not atmosphere then
	atmosphere = Instance.new("Atmosphere")
	atmosphere.Parent = Lighting
end
local atm = atmosphere :: Atmosphere
local base = {
	Density = atm.Density,
	Offset = atm.Offset,
	Haze = atm.Haze,
	Color = atm.Color,
	Decay = atm.Decay,
}

-- Corrección de color propia (solo local, no se replica).
local grade = Instance.new("ColorCorrectionEffect")
grade.Name = "UnderwaterGrade"
grade.Parent = Lighting

local underwaterTarget = 0
local uw = 0 -- 0 = fuera del agua, 1 = dentro (suavizado)
local checkAccum = 0

local function cameraInWater(): boolean
	local p = camera.CFrame.Position
	local region = Region3.new(p - Vector3.new(2, 2, 2), p + Vector3.new(2, 2, 2)):ExpandToGrid(4)
	local materials = terrain:ReadVoxels(region, 4)
	return materials[1][1][1] == Enum.Material.Water
end

local function restore()
	atm.Density = base.Density
	atm.Offset = base.Offset
	atm.Haze = base.Haze
	atm.Color = base.Color
	atm.Decay = base.Decay
	grade.Brightness = 0
	grade.TintColor = Color3.new(1, 1, 1)
end

RunService.RenderStepped:Connect(function(dt)
	checkAccum += dt
	if checkAccum >= 0.1 then
		checkAccum = 0
		underwaterTarget = if cameraInWater() then 1 else 0
	end
	uw += (underwaterTarget - uw) * math.min(1, dt * W.TransitionSpeed)

	if uw < 0.002 then
		if uw > 0 then
			uw = 0
			restore()
		end
		return
	end

	local depth = math.max(0, Config.SeaLevelY - camera.CFrame.Position.Y)
	local t = math.clamp(depth / W.DeepDepth, 0, 1)

	-- Densidad: sube con la profundidad; la lámpara encendida y su mejora la reducen.
	local density = W.SurfaceDensity + (W.DeepDensity - W.SurfaceDensity) * t
	if player:GetAttribute("LampOn") then
		local level = (player:GetAttribute("Up_Lamp") :: number?) or 0
		density -= W.LampDensityReduction + level * W.LampDensityPerLevel
	end
	density = math.max(W.MinDensity, density)
	local haze = W.SurfaceHaze + (W.DeepHaze - W.SurfaceHaze) * t

	-- Color del agua: claro arriba, casi negro abajo, más oscuro de noche.
	local night = TimeOfDay.Nightness(Lighting.ClockTime)
	local waterColor = W.SurfaceColor:Lerp(W.DeepColor, t):Lerp(Color3.new(0, 0, 0), night * W.NightDarkness)

	atm.Density = base.Density + (density - base.Density) * uw
	atm.Offset = base.Offset * (1 - uw)
	atm.Haze = base.Haze + (haze - base.Haze) * uw
	atm.Color = base.Color:Lerp(waterColor, uw)
	atm.Decay = base.Decay:Lerp(waterColor, uw)
	grade.Brightness = -W.DarkenAtDepth * t * uw
	grade.TintColor = Color3.new(1, 1, 1):Lerp(Color3.fromRGB(170, 210, 255), 0.5 * uw)
end)
