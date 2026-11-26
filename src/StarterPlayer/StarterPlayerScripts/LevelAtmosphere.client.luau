--!strict
-- Ambiente por nivel (Config.LevelAtmosphere): cuando Runs carga un mapa en Workspace.Maps se pasa a su perfil (noche, niebla con
-- Atmosphere, corrección de color y bloom) con una transición; al volver al lobby se restaura lo que había al arrancar.
-- Solo cliente: no toca el servidor ni otros jugadores. La ColorCorrection propia se llama LevelGrade (SurvivalHud usa la suya).
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local A = Config.LevelAtmosphere

local function rgb(t: { number }): Color3
	return Color3.fromRGB(t[1], t[2], t[3])
end

local function ensure(className: string, name: string): Instance
	local found = Lighting:FindFirstChildOfClass(className :: any)
	if found then
		return found
	end
	local inst = Instance.new(className :: any)
	inst.Name = name
	inst.Parent = Lighting
	return inst
end

local atmosphere = ensure("Atmosphere", "Atmosphere") :: Atmosphere
local bloom = ensure("BloomEffect", "Bloom") :: BloomEffect
local grade = Lighting:FindFirstChild("LevelGrade") :: ColorCorrectionEffect?
if not grade then
	local g = Instance.new("ColorCorrectionEffect")
	g.Name = "LevelGrade"
	g.Parent = Lighting
	grade = g
end
local levelGrade = grade :: ColorCorrectionEffect

-- Estado del lobby (lo que trae el lugar), para volver a él.
local lobby = {
	lighting = {
		ClockTime = Lighting.ClockTime,
		Brightness = Lighting.Brightness,
		Ambient = Lighting.Ambient,
		OutdoorAmbient = Lighting.OutdoorAmbient,
		EnvironmentDiffuseScale = Lighting.EnvironmentDiffuseScale,
		EnvironmentSpecularScale = Lighting.EnvironmentSpecularScale,
		ExposureCompensation = Lighting.ExposureCompensation,
	},
	atmosphere = {
		Density = atmosphere.Density,
		Offset = atmosphere.Offset,
		Haze = atmosphere.Haze,
		Glare = atmosphere.Glare,
		Color = atmosphere.Color,
		Decay = atmosphere.Decay,
	},
	bloom = { Intensity = bloom.Intensity, Size = bloom.Size, Threshold = bloom.Threshold },
	grade = { TintColor = Color3.new(1, 1, 1), Contrast = 0, Saturation = 0 },
}

local tweens: { Tween } = {}
local function tweenTo(inst: Instance, props: { [string]: any }, seconds: number)
	local tw = TweenService:Create(inst, TweenInfo.new(seconds, Enum.EasingStyle.Sine), props)
	table.insert(tweens, tw)
	tw:Play()
end

local function apply(profile: any?)
	for _, tw in tweens do
		tw:Cancel()
	end
	table.clear(tweens)
	local s = A.FadeSeconds
	if not profile then
		-- ClockTime no se interpola (daría la vuelta al día): se fija directamente.
		Lighting.ClockTime = lobby.lighting.ClockTime
		local l = table.clone(lobby.lighting)
		l.ClockTime = nil
		tweenTo(Lighting, l, s)
		tweenTo(atmosphere, lobby.atmosphere, s)
		tweenTo(bloom, lobby.bloom, s)
		tweenTo(levelGrade, lobby.grade, s)
		return
	end
	Lighting.ClockTime = profile.ClockTime
	tweenTo(Lighting, {
		Brightness = profile.Brightness,
		Ambient = rgb(profile.Ambient),
		OutdoorAmbient = rgb(profile.OutdoorAmbient),
		EnvironmentDiffuseScale = profile.EnvironmentDiffuseScale,
		EnvironmentSpecularScale = profile.EnvironmentSpecularScale,
		ExposureCompensation = profile.ExposureCompensation,
	}, s)
	tweenTo(atmosphere, {
		Density = profile.Density,
		Offset = profile.Offset,
		Haze = profile.Haze,
		Glare = profile.Glare,
		Color = rgb(profile.Color),
		Decay = rgb(profile.Decay),
	}, s)
	tweenTo(bloom, { Intensity = profile.BloomIntensity, Size = profile.BloomSize, Threshold = profile.BloomThreshold }, s)
	tweenTo(levelGrade, { TintColor = rgb(profile.Tint), Contrast = profile.Contrast, Saturation = profile.Saturation }, s)
end

local current: string? = nil
local function refresh(maps: Instance)
	local found: string? = nil
	for _, m in maps:GetChildren() do
		if A.Profiles[m.Name] then
			found = m.Name
			break
		end
	end
	if found ~= current then
		current = found
		apply(if found then A.Profiles[found] else nil)
	end
end

local maps = workspace:WaitForChild("Maps", 60)
if maps then
	maps.ChildAdded:Connect(function()
		refresh(maps)
	end)
	maps.ChildRemoved:Connect(function()
		refresh(maps)
	end)
	refresh(maps)
end
