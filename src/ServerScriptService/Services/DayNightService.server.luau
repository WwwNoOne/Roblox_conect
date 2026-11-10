--!strict
-- Ciclo día/noche: avanza Lighting.ClockTime y oscurece la luz ambiente de noche.
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local DAY_AMBIENT = Color3.fromRGB(70, 70, 70)
local NIGHT_AMBIENT = Color3.fromRGB(8, 10, 22)
local DAY_BRIGHTNESS = 3
local NIGHT_BRIGHTNESS = 0.5
local hoursPerSecond = 24 / Config.DayLengthSeconds

-- 0 de día (7h-17h), 1 de noche (20h-4h), transiciones lineales de 3 h.
local function nightness(t: number): number
	if t >= 7 and t <= 17 then
		return 0
	elseif t >= 20 or t <= 4 then
		return 1
	elseif t > 17 then
		return (t - 17) / 3
	end
	return (7 - t) / 3
end

local function apply()
	local n = nightness(Lighting.ClockTime)
	local ambient = DAY_AMBIENT:Lerp(NIGHT_AMBIENT, n)
	Lighting.Ambient = ambient
	Lighting.OutdoorAmbient = ambient
	Lighting.Brightness = DAY_BRIGHTNESS + (NIGHT_BRIGHTNESS - DAY_BRIGHTNESS) * n
end

Lighting.ClockTime = Config.StartClockTime
apply()

while true do
	local dt = task.wait(1)
	Lighting.ClockTime = (Lighting.ClockTime + hoursPerSecond * dt) % 24
	apply()
end
