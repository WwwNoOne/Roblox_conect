--!strict
-- Ciclo día/noche: avanza Lighting.ClockTime y oscurece la luz ambiente de noche.
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local TimeOfDay = require(Shared:WaitForChild("TimeOfDay"))

local DAY_AMBIENT = Color3.fromRGB(70, 70, 70)
local NIGHT_AMBIENT = Color3.fromRGB(8, 10, 22)
local DAY_BRIGHTNESS = 3
local NIGHT_BRIGHTNESS = 0.5
local hoursPerSecond = 24 / Config.DayLengthSeconds

local function apply()
	local n = TimeOfDay.Nightness(Lighting.ClockTime)
	local ambient = DAY_AMBIENT:Lerp(NIGHT_AMBIENT, n)
	Lighting.Ambient = ambient
	Lighting.OutdoorAmbient = ambient
	Lighting.Brightness = DAY_BRIGHTNESS + (NIGHT_BRIGHTNESS - DAY_BRIGHTNESS) * n
end

Lighting.ClockTime = Config.StartClockTime
apply()

while true do
	local dt = task.wait(1)
	-- Para pruebas: Lighting:SetAttribute("PauseCycle", true) congela la hora.
	if not Lighting:GetAttribute("PauseCycle") then
		Lighting.ClockTime = (Lighting.ClockTime + hoursPerSecond * dt) % 24
	end
	apply()
end
