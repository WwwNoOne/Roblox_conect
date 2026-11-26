--!strict
-- Puerta del ascensor (T04): prompts salir/entrar, puerta abierta solo en niveles (no en la Parada), cabina sellada al viajar.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Types = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Types"))
local Runs = require(script.Parent:WaitForChild("Runs"))
local WorldRefs = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("WorldRefs"))
local Sfx = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Sfx"))
local descentFx = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("DescentFx") :: RemoteEvent

local sub = WorldRefs.WaitElevator(30)
if not sub then
	warn("[ElevatorService] No hay Workspace.Elevator; puerta desactivada")
	return
end

local gate = sub:WaitForChild("Gate")
local door = gate:WaitForChild("Door") :: BasePart
local insideAtt = gate:FindFirstChild("InsidePrompt", true) :: Attachment
local outsideAtt = gate:FindFirstChild("OutsidePrompt", true) :: Attachment
local entryAtt = gate:FindFirstChild("EntryPoint", true) :: Attachment
local exitAtt = gate:FindFirstChild("ExitPoint", true) :: Attachment
local doorClosed = gate:FindFirstChild("DoorClosed", true) :: Attachment

local gateOpen = false

-- Un solo botón para entrar y salir: dos botones casi en el mismo sitio se tapaban entre sí y, muy cerca de la puerta,
-- el que se mostraba era el del lado contrario (no hacía nada). El texto "Entrar"/"Salir" lo pone cada cliente (GatePromptText).
local gatePrompt = Instance.new("ProximityPrompt")
gatePrompt.Name = "GatePrompt"
gatePrompt.ActionText = "Puerta"
gatePrompt.ObjectText = "Ascensor"
gatePrompt.KeyboardKeyCode = Enum.KeyCode.E
gatePrompt.HoldDuration = 0.3
gatePrompt.MaxActivationDistance = 12
gatePrompt.RequiresLineOfSight = false
gatePrompt.Enabled = false
gatePrompt.Parent = gate:FindFirstChild("Frame") or insideAtt

local function setGate(open: boolean)
	gateOpen = open
	gatePrompt.Enabled = open
	-- La puerta permanece cerrada siempre: se entra y se sale solo con los botones (teletransporte).
	door.CFrame = doorClosed.WorldCFrame
	door.CanCollide = true
end

-- Punto libre junto a `att`: si otro jugador ya está ahí, prueba al lado y un paso más allá. Dos personajes teletransportados al
-- mismo punto se solapan y la física expulsa a uno bajo el suelo (cae al vacío y pierde el HumanoidRootPart).
local SPREAD = 2.5
local SPOT_OFFSETS = {
	Vector3.zero,
	Vector3.new(SPREAD, 0, 0),
	Vector3.new(-SPREAD, 0, 0),
	Vector3.new(0, 0, -SPREAD),
	Vector3.new(SPREAD, 0, -SPREAD),
	Vector3.new(-SPREAD, 0, -SPREAD),
}

local function freeSpot(att: Attachment, self: Player): CFrame
	local base = att.WorldCFrame
	for _, offset in SPOT_OFFSETS do
		local cf = base * CFrame.new(offset)
		local taken = false
		for _, other in Players:GetPlayers() do
			local r = other ~= self and other.Character and other.Character:FindFirstChild("HumanoidRootPart")
			if r and r:IsA("BasePart") and (r.Position - cf.Position).Magnitude < SPREAD - 0.3 then
				taken = true
				break
			end
		end
		if not taken then
			return cf
		end
	end
	return base
end

local function cross(player: Player, to: Attachment)
	local run = Runs.GetByUser(player.UserId)
	if not run or run.state ~= "Level" or not gateOpen then
		return
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not humanoid or humanoid.Health <= 0 or not root then
		return
	end
	root.CFrame = freeSpot(to, player)
	Sfx.Play(if to == entryAtt then Config.Sfx.ElevatorEnter else Config.Sfx.ElevatorExit, to.Parent, Config.Audio.ElevatorVolume, Config.Audio.ElevatorRollOff)
	root.AssemblyLinearVelocity = Vector3.zero
end

gatePrompt.Triggered:Connect(function(player: Player)
	if Runs.IsUserInside(player.UserId) then
		cross(player, exitAtt)
	else
		cross(player, entryAtt)
	end
end)

-- Botón "Salir" del panel del ascensor: mismo efecto que la puerta, solo desde dentro y en un nivel.
local requestExit = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("RequestExit") :: RemoteFunction
local lastExit: { [Player]: number } = {}
requestExit.OnServerInvoke = function(player: Player)
	local now = os.clock()
	if now - (lastExit[player] or 0) < 0.5 then
		return { ok = false, err = "TOO_FAST" }
	end
	lastExit[player] = now
	local run = Runs.GetByUser(player.UserId)
	if not run or run.state ~= "Level" or not gateOpen then
		return { ok = false, err = "NOT_LEVEL" }
	end
	if not Runs.IsUserInside(player.UserId) then
		return { ok = false, err = "NOT_INSIDE" }
	end
	cross(player, exitAtt)
	return { ok = true }
end
Players.PlayerRemoving:Connect(function(player)
	lastExit[player] = nil
end)

Runs.StateChanged:Connect(function(code: string, state: Types.RunState)
	local run = Runs.Get(code)
	if not run then
		return
	end
	local phase: string? = nil
	if state == "Descending" then
		setGate(false)
		phase = "Start"
	elseif state == "Level" then
		setGate(true) -- se sale a explorar
		phase = "End"
	elseif state == "Stopover" then
		setGate(false) -- Parada: nadie sale; se opera desde dentro
		phase = "End"
	end
	if phase then
		for _, userId in run.members do
			local p = Players:GetPlayerByUserId(userId)
			if p then
				descentFx:FireClient(p, phase)
			end
		end
	end
end)
