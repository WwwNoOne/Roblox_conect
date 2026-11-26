--!strict
-- Pone un ProximityPrompt en cada volumen `Escondite` de los mapas fijos (Workspace.Maps) y gestiona entrar/salir.
-- Pulsar E en una caja = esconderse; pulsar E estando escondido = salir. Parámetros: Config.Hiding.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Hiding = require(script.Parent:WaitForChild("Hiding"))
local Runs = require(script.Parent:WaitForChild("Runs"))

local H = Config.Hiding
local lastUse: { [Player]: number } = {}

local function addPrompt(volume: BasePart)
	if volume:FindFirstChildOfClass("ProximityPrompt") then
		return
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "EsconderPrompt"
	prompt.ActionText = H.PromptText
	prompt.ObjectText = H.ObjectText
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = H.HoldSeconds
	prompt.MaxActivationDistance = H.Distance
	prompt.RequiresLineOfSight = false
	prompt.Parent = volume
	prompt.Triggered:Connect(function(player: Player)
		local now = os.clock()
		if now - (lastUse[player] or 0) < H.Cooldown then
			return
		end
		lastUse[player] = now
		if Hiding.IsHidden(player) then
			Hiding.Release(player)
		else
			Hiding.Hide(player, volume)
		end
	end)
end

local function scan(level: Instance)
	for _, d in level:GetDescendants() do
		if d:IsA("BasePart") and d.Name == "Escondite" then
			addPrompt(d)
		end
	end
end

local function start()
	-- Runs mete y saca los mapas del Workspace.Maps según la etapa: se vigilan los que entren.
	local maps = workspace:FindFirstChild("Maps") or workspace:WaitForChild("Maps", 60)
	if maps then
		scan(maps)
		maps.DescendantAdded:Connect(function(d)
			if d:IsA("BasePart") and d.Name == "Escondite" then
				addPrompt(d)
			end
		end)
	end
end
task.spawn(start)

Players.PlayerRemoving:Connect(function(player)
	lastUse[player] = nil
end)

-- Al terminar la partida o cambiar de etapa nadie se queda escondido.
Runs.StateChanged:Connect(function(_code, state)
	if state == "Descending" or state == "Stopover" or state == "Won" or state == "Lost" then
		Hiding.ReleaseAll()
	end
end)
