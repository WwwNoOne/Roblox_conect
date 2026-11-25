--!strict
-- Efectos de sonido del ascensor ligados al estado de la partida (los de la puerta están en ElevatorService):
--   inicio de partida, viajes (Avanzar_1/2 al azar), llegada y derrota.
-- Se reproducen en el servidor, en el cuerpo del ascensor (3D con alcance limitado), así los oyen todos los que estén cerca.
-- Los nombres de los sonidos están en Config.Sfx; la mezcla en Config.Audio.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Sfx = require(Shared:WaitForChild("Sfx"))
local Types = require(Shared:WaitForChild("Types"))
local WorldRefs = require(Shared:WaitForChild("WorldRefs"))
local Runs = require(script.Parent:WaitForChild("Runs"))

local A = Config.Audio

local function bodyPart(): Instance?
	local elevator = WorldRefs.Elevator()
	return elevator and (elevator:FindFirstChild("Body") or elevator.PrimaryPart or elevator:FindFirstChildWhichIsA("BasePart", true))
end

local function play(prefix: string)
	Sfx.Play(prefix, bodyPart(), A.ElevatorVolume, A.ElevatorRollOff)
end

Runs.StateChanged:Connect(function(code: string, state: Types.RunState)
	local run = Runs.Get(code)
	if not run then
		return
	end
	if state == "Descending" then
		if run.zone == 0 then
			play(Config.Sfx.ElevatorStart) -- todos a bordo: parte hacia el primer nivel
		else
			Sfx.PlayAny(Config.Sfx.ElevatorAdvance, bodyPart(), A.ElevatorVolume, A.ElevatorRollOff)
		end
	elseif state == "Level" or state == "Stopover" then
		play(Config.Sfx.ElevatorArrive) -- el viaje termina
	end
end)

Runs.Ended:Connect(function(_code: string, result: string, _reason: string)
	if result == "Lost" then
		play(Config.Sfx.ElevatorDefeat)
	end
end)
