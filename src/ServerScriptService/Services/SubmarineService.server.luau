--!strict
-- Compuerta del submarino (T04): prompts salir/entrar, puerta abierta solo en niveles (no en la Parada), cabina sellada al viajar.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Types = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Types"))
local Runs = require(script.Parent:WaitForChild("Runs"))
local descentFx = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("DescentFx") :: RemoteEvent

local sub = workspace:WaitForChild("Submarine", 30)
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

local function makePrompt(parent: Attachment, action: string): ProximityPrompt
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = action
	prompt.ObjectText = "Compuerta"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0.3
	prompt.MaxActivationDistance = 8
	prompt.RequiresLineOfSight = false
	prompt.Enabled = false
	prompt.Parent = parent
	return prompt
end

local insidePrompt = makePrompt(insideAtt, "Salir")
local outsidePrompt = makePrompt(outsideAtt, "Entrar")

local function setHatch(open: boolean)
	hatchOpen = open
	insidePrompt.Enabled = open
	outsidePrompt.Enabled = open
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
	root.AssemblyLinearVelocity = Vector3.zero
end

insidePrompt.Triggered:Connect(function(player: Player)
	if Runs.IsUserInside(player.UserId) then
		cross(player, exitAtt)
	end
end)
outsidePrompt.Triggered:Connect(function(player: Player)
	if not Runs.IsUserInside(player.UserId) then
		cross(player, entryAtt)
	end
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
