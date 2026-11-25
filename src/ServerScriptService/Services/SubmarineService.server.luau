--!strict
-- Compuerta del submarino (T04): prompts salir/entrar, puerta abierta solo en niveles (no en la Parada), cabina sellada al viajar.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Types = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Types"))
local Runs = require(script.Parent:WaitForChild("Runs"))
local WorldRefs = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("WorldRefs"))
local Sfx = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Sfx"))
local descentFx = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("DescentFx") :: RemoteEvent

local sub = WorldRefs.WaitSubmarine(30)
if not sub then
	warn("[SubmarineService] No hay Workspace.Submarine; compuerta desactivada")
	return
end

local hatch = sub:WaitForChild("Hatch")
local door = hatch:WaitForChild("Door") :: BasePart
local insideAtt = hatch:FindFirstChild("InsidePrompt", true) :: Attachment
local outsideAtt = hatch:FindFirstChild("OutsidePrompt", true) :: Attachment
local entryAtt = hatch:FindFirstChild("EntryPoint", true) :: Attachment
local exitAtt = hatch:FindFirstChild("ExitPoint", true) :: Attachment
local doorClosed = hatch:FindFirstChild("DoorClosed", true) :: Attachment

local hatchOpen = false

-- Un solo botón para entrar y salir: dos botones casi en el mismo sitio se tapaban entre sí y, muy cerca de la puerta,
-- el que se mostraba era el del lado contrario (no hacía nada). El texto "Entrar"/"Salir" lo pone cada cliente (HatchPromptText).
local hatchPrompt = Instance.new("ProximityPrompt")
hatchPrompt.Name = "HatchPrompt"
hatchPrompt.ActionText = "Compuerta"
hatchPrompt.ObjectText = "Compuerta"
hatchPrompt.KeyboardKeyCode = Enum.KeyCode.E
hatchPrompt.HoldDuration = 0.3
hatchPrompt.MaxActivationDistance = 12
hatchPrompt.RequiresLineOfSight = false
hatchPrompt.Enabled = false
hatchPrompt.Parent = hatch:FindFirstChild("Frame") or insideAtt

local function setHatch(open: boolean)
	hatchOpen = open
	hatchPrompt.Enabled = open
	-- La puerta permanece cerrada siempre: se entra y se sale solo con los botones (teletransporte).
	door.CFrame = doorClosed.WorldCFrame
	door.CanCollide = true
end

local function cross(player: Player, to: Attachment)
	local run = Runs.GetByUser(player.UserId)
	if not run or run.state ~= "Level" or not hatchOpen then
		return
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not humanoid or humanoid.Health <= 0 or not root then
		return
	end
	root.CFrame = to.WorldCFrame
	Sfx.Play(if to == entryAtt then Config.Sfx.SubEnter else Config.Sfx.SubExit, to.Parent, Config.Audio.SubVolume, Config.Audio.SubRollOff)
	root.AssemblyLinearVelocity = Vector3.zero
end

hatchPrompt.Triggered:Connect(function(player: Player)
	if Runs.IsUserInside(player.UserId) then
		cross(player, exitAtt)
	else
		cross(player, entryAtt)
	end
end)

-- Botón "Salir" del panel del submarino: mismo efecto que la compuerta, solo desde dentro y en un nivel.
local requestExit = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("RequestExit") :: RemoteFunction
local lastExit: { [Player]: number } = {}
requestExit.OnServerInvoke = function(player: Player)
	local now = os.clock()
	if now - (lastExit[player] or 0) < 0.5 then
		return { ok = false, err = "TOO_FAST" }
	end
	lastExit[player] = now
	local run = Runs.GetByUser(player.UserId)
	if not run or run.state ~= "Level" or not hatchOpen then
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
		setHatch(false)
		phase = "Start"
	elseif state == "Level" then
		setHatch(true) -- se sale a explorar
		phase = "End"
	elseif state == "Stopover" then
		setHatch(false) -- Parada: nadie sale; se opera desde dentro
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
