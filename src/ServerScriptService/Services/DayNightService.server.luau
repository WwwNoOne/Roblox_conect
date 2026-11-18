--!strict
-- Ciclo día/noche: avanza Lighting.ClockTime y oscurece la luz ambiente de noche.
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local TimeOfDay = require(Shared:WaitForChild("TimeOfDay"))
local Runs = require(script.Parent:WaitForChild("Runs"))

local DAY_AMBIENT = Color3.fromRGB(70, 70, 70)
local NIGHT_AMBIENT = Color3.fromRGB(22, 34, 60)
local DAY_BRIGHTNESS = 3
local NIGHT_BRIGHTNESS = 0.9
local hoursPerSecond = 24 / Config.DayLengthSeconds

local function apply()
	local n = TimeOfDay.Nightness(Lighting.ClockTime)
	local ambient = DAY_AMBIENT:Lerp(NIGHT_AMBIENT, n)
	Lighting.Ambient = ambient
	Lighting.OutdoorAmbient = ambient
	Lighting.Brightness = DAY_BRIGHTNESS + (NIGHT_BRIGHTNESS - DAY_BRIGHTNESS) * n
end

-- Reloj de nivel (Stage.Clock): sube de Start a End y se queda en End. nil = ciclo libre.
local levelClock: { Start: number, End: number, Seconds: number, t: number }? = nil

Runs.StateChanged:Connect(function(code, state)
	local run = Runs.Get(code)
	if state == "Level" and run then
		local stage = (Config.Run.Stages :: any)[run.zone]
		local c = stage and stage.Clock
		if c then
			levelClock = { Start = c.Start, End = c.End, Seconds = c.Seconds, t = 0 }
			Lighting.ClockTime = c.Start
			apply()
		else
			levelClock = nil
		end
	elseif state == "Won" or state == "Lost" or state == "Lobby" then
		levelClock = nil
	end
end)

Lighting.ClockTime = Config.StartClockTime
apply()

while true do
	local dt = task.wait(1)
	-- Para pruebas: Lighting:SetAttribute("PauseCycle", true) congela la hora.
	if Lighting:GetAttribute("PauseCycle") then
		-- congelado
	elseif levelClock then
		levelClock.t = math.min(levelClock.t + dt, levelClock.Seconds)
		Lighting.ClockTime = levelClock.Start + (levelClock.End - levelClock.Start) * levelClock.t / levelClock.Seconds
	else
		Lighting.ClockTime = (Lighting.ClockTime + hoursPerSecond * dt) % 24
	end
	apply()
end
