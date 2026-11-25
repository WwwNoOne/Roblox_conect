--!strict
-- Zona segura: la sala_0 (Workspace.Sala_0, donde está el ascensor) por encima de su suelo.
--   * Un jugador dentro (IsPlayerSafe) no puede ser detectado ni atacado por los enemigos y no corre.
--   * Los enemigos no pueden entrar: BarsMonster marca el volumen de la sala_0 y el tramo del pozo (el primer pasillo bajo el agujero
--     de 16 × 16) hasta Config.SafeZone.MonsterBuffer studs por debajo del suelo, para que ni la cabeza de un enemigo largo asome.
-- La caja de la sala se calcula una vez a partir de las piezas de Workspace.Sala_0; la altura del suelo es LevelState.entry.Y (el
-- puerto del pozo, justo bajo el suelo).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local LevelState = require(script.Parent:WaitForChild("LevelState"))

local Z = Config.SafeZone

local SafeZone = {}

local box: { min: Vector3, max: Vector3 }? = nil

local function sala0Box(): { min: Vector3, max: Vector3 }?
	if box then
		return box
	end
	local folder = workspace:FindFirstChild("Sala_0")
	if not folder then
		return nil
	end
	local mn, mx = Vector3.one * math.huge, -Vector3.one * math.huge
	local found = false
	for _, d in folder:GetDescendants() do
		if d:IsA("BasePart") and d.Name ~= "ElevatorDock" then
			local h = d.Size / 2
			-- caja alineada con los ejes que contiene la pieza (suficiente: la sala es rectangular)
			local ext = Vector3.new(
				math.abs(d.CFrame.RightVector.X) * h.X + math.abs(d.CFrame.UpVector.X) * h.Y + math.abs(d.CFrame.LookVector.X) * h.Z,
				math.abs(d.CFrame.RightVector.Y) * h.X + math.abs(d.CFrame.UpVector.Y) * h.Y + math.abs(d.CFrame.LookVector.Y) * h.Z,
				math.abs(d.CFrame.RightVector.Z) * h.X + math.abs(d.CFrame.UpVector.Z) * h.Y + math.abs(d.CFrame.LookVector.Z) * h.Z
			)
			mn = mn:Min(d.Position - ext)
			mx = mx:Max(d.Position + ext)
			found = true
		end
	end
	if not found then
		return nil
	end
	box = { min = mn, max = mx }
	return box
end

local function insideXZ(b: { min: Vector3, max: Vector3 }, pos: Vector3, pad: number): boolean
	return pos.X >= b.min.X - pad and pos.X <= b.max.X + pad and pos.Z >= b.min.Z - pad and pos.Z <= b.max.Z + pad
end

-- ¿El jugador está en la sala_0 (por encima del suelo)? Quien baja por el pozo bajo el suelo no está a salvo.
function SafeZone.IsPlayerSafe(pos: Vector3): boolean
	local b, entry = sala0Box(), LevelState.entry
	if not b or not entry then
		return false
	end
	return insideXZ(b, pos, 0) and pos.Y > entry.Y + 0.5 and pos.Y <= b.max.Y + 4
end

-- ¿Un enemigo no puede estar en este punto? La sala_0 (con un margen) y el tramo del pozo bajo ella.
function SafeZone.BarsMonster(pos: Vector3): boolean
	local b, entry = sala0Box(), LevelState.entry
	if not b or not entry then
		return false
	end
	return insideXZ(b, pos, Z.PlanePad) and pos.Y > entry.Y - Z.MonsterBuffer
end

return SafeZone
