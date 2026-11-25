--!strict
-- Nivel de calidad de efectos visuales, reutilizable por cualquier script de cliente (linterna, agua, partículas...).
--   local QualityTier = require(script.Parent.QualityTier)
--   QualityTier.Tier   -- 1 baja, 2 media, 3 alta
--   QualityTier.Level  -- 1-10 (equivalente a la calidad gráfica de Roblox)
--   QualityTier.IsLow  -- Tier == 1
--   QualityTier.Changed:Connect(function(tier, level) end)
-- Fuente del nivel, por prioridad:
--   1. workspace:SetAttribute("LampQualityOverride", 1..10)  (pruebas; 0 o nil = sin override)
--   2. Calidad gráfica guardada del jugador (SavedQualityLevel), si no es Automático
--   3. Automático: parte de Config.Quality.AutoStartLevel y sube/baja según el FPS, con histéresis
-- En táctil el nivel se limita a Config.Quality.TouchMaxLevel.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Q = Config.Quality

local changed = Instance.new("BindableEvent")

local QualityTier = {
	Tier = 2,
	Level = Q.AutoStartLevel,
	IsLow = false,
	Changed = changed.Event, -- (tier: number, level: number)
}

local autoLevel = Q.AutoStartLevel

local function tierOf(level: number): number
	if level >= Q.HighFrom then
		return 3
	elseif level >= Q.MediumFrom then
		return 2
	end
	return 1
end

local function savedLevel(): number?
	local ok, result = pcall(function()
		local setting = UserSettings():GetService("UserGameSettings").SavedQualityLevel
		if setting == Enum.SavedQualitySetting.Automatic then
			return nil
		end
		return tonumber(string.match(setting.Name, "%d+"))
	end)
	return if ok then result :: number? else nil
end

local function resolve()
	local level: number = autoLevel
	local override = workspace:GetAttribute("LampQualityOverride")
	if type(override) == "number" and override >= 1 then
		level = math.clamp(math.floor(override), 1, 10)
	else
		level = savedLevel() or autoLevel
		if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
			level = math.min(level, Q.TouchMaxLevel)
		end
	end
	local tier = tierOf(level)
	local tierChanged = tier ~= QualityTier.Tier
	QualityTier.Level = level
	QualityTier.Tier = tier
	QualityTier.IsLow = tier == 1
	if tierChanged then
		changed:Fire(tier, level)
	end
end

-- Medición de FPS solo en Automático: baja rápido (LowerHoldSeconds), sube despacio (RaiseHoldSeconds).
local accum, frames, lowFor, highFor = 0, 0, 0, 0
RunService.Heartbeat:Connect(function(dt)
	accum += dt
	frames += 1
	if accum < Q.SampleSeconds then
		return
	end
	local fps = frames / accum
	local window = accum
	accum, frames = 0, 0
	if savedLevel() or (workspace:GetAttribute("LampQualityOverride") :: number? or 0) >= 1 then
		lowFor, highFor = 0, 0
		return
	end
	if fps < Q.LowerBelowFps then
		lowFor += window
		highFor = 0
		if lowFor >= Q.LowerHoldSeconds and autoLevel > 1 then
			autoLevel -= 1
			lowFor = 0
			resolve()
		end
	elseif fps > Q.RaiseAboveFps then
		highFor += window
		lowFor = 0
		if highFor >= Q.RaiseHoldSeconds and autoLevel < 10 then
			autoLevel += 1
			highFor = 0
			resolve()
		end
	else
		lowFor, highFor = 0, 0
	end
end)

workspace:GetAttributeChangedSignal("LampQualityOverride"):Connect(resolve)
resolve()

return QualityTier
