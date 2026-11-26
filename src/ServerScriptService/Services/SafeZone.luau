--!strict
-- Zona segura: el interior del Ascensor (Elevator.InteriorZone).
--   * Un jugador dentro (IsPlayerSafe) no puede ser detectado ni atacado por los enemigos y no corre.
--   * Los enemigos no pueden entrar: BarsMonster marca el volumen del interior con un margen de Config.SafeZone.PlanePad.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local WorldRefs = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("WorldRefs"))

local Z = Config.SafeZone

local SafeZone = {}

local function inside(pos: Vector3, pad: number): boolean
	local elevator = WorldRefs.Elevator()
	local zone = elevator and elevator:FindFirstChild("InteriorZone", true)
	if not zone or not zone:IsA("BasePart") then
		return false
	end
	local rel = zone.CFrame:PointToObjectSpace(pos)
	local half = zone.Size / 2 + Vector3.one * pad
	return math.abs(rel.X) <= half.X and math.abs(rel.Y) <= half.Y and math.abs(rel.Z) <= half.Z
end

-- ¿El jugador está dentro del Ascensor?
function SafeZone.IsPlayerSafe(pos: Vector3): boolean
	return inside(pos, 0)
end

-- ¿Un enemigo no puede estar en este punto? El interior del Ascensor con un margen.
function SafeZone.BarsMonster(pos: Vector3): boolean
	return inside(pos, Z.PlanePad)
end

return SafeZone
