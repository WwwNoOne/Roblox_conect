--!strict
-- Efectos de sonido del submarino ligados al estado de la partida (los de la compuerta están en SubmarineService):
--   inicio de partida, viajes (Avanzar_1/2 al azar o el de casco muy dañado), derrota (implosión u otra) y sirena de casco bajo.
-- Se reproducen en el servidor, en el casco del submarino (3D con alcance limitado), así los oyen todos los que estén cerca.
-- Los nombres de los sonidos están en Config.Sfx; la mezcla en Config.Audio.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Sfx = require(Shared:WaitForChild("Sfx"))
local Types = require(Shared:WaitForChild("Types"))
local WorldRefs = require(Shared:WaitForChild("WorldRefs"))
local Runs = require(script.Parent:WaitForChild("Runs"))

local A = Config.Audio

local function hullPart(): Instance?
	local sub = WorldRefs.Submarine()
	return sub and (sub:FindFirstChild("Hull") or sub.PrimaryPart or sub:FindFirstChildWhichIsA("BasePart", true))
end

local function play(prefix: string)
	Sfx.Play(prefix, hullPart(), A.SubVolume, A.SubRollOff)
end

local sirenArmed: { [string]: boolean } = {} -- por partida: la sirena ya sonó y el casco sigue bajo

Runs.StateChanged:Connect(function(code: string, state: Types.RunState)
	local run = Runs.Get(code)
	if not run then
		return
	end
	if state == "Descending" then
		if run.zone == 0 then
			play(Config.Sfx.SubStart) -- todos a bordo: parte hacia el primer nivel
		elseif run.hull / Config.Run.HullMax <= A.DamagedHullFraction then
			play(Config.Sfx.SubAdvanceDamaged)
		else
			Sfx.PlayAny(Config.Sfx.SubAdvance, hullPart(), A.SubVolume, A.SubRollOff)
		end
	end
end)

-- Llegada a un nivel o a la Parada (el viaje termina).
Runs.StateChanged:Connect(function(code: string, state: Types.RunState)
	if state == "Level" or state == "Stopover" then
		play(Config.Sfx.SubArrive)
	end
end)

Runs.Ended:Connect(function(_code: string, result: string, reason: string)
	if result ~= "Lost" then
		return
	end
	if reason == "Implosion" then
		play(Config.Sfx.SubImplode)
		play(Config.Sfx.SubDefeatAlarm)
	else
		play(Config.Sfx.SubDefeatShort)
	end
end)

-- Sirena al cruzar el umbral de casco bajo (una vez; se rearma si se repara por encima del umbral).
local known: { [string]: boolean } = {}
Runs.StateChanged:Connect(function(code: string)
	known[code] = true
end)
task.spawn(function()
	while true do
		task.wait(0.5)
		for code in known do
			local run = Runs.Get(code)
			if not run then
				known[code] = nil
				sirenArmed[code] = nil
			elseif not run.ended then
				local low = run.hull / Config.Run.HullMax <= A.LowHullFraction
				if low and not sirenArmed[code] then
					sirenArmed[code] = true
					play(Config.Sfx.SubLowHullSiren)
				elseif not low then
					sirenArmed[code] = nil
				end
			end
		end
	end
end)
