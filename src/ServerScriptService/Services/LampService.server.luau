--!strict
-- Lámpara de buceo (luz en la cabeza, modelo provisional). Se alterna con ToggleLamp.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local toggleLamp = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("ToggleLamp") :: RemoteEvent

local lastToggle: { [Player]: number } = {}

local function addLamp(character: Model)
	local head = character:WaitForChild("Head", 5)
	if not head or head:FindFirstChild("DiveLamp") then
		return
	end
	local light = Instance.new("SpotLight")
	light.Name = "DiveLamp"
	light.Face = Enum.NormalId.Front
	light.Range = Config.LampRange
	light.Angle = 70
	light.Brightness = 3
	light.Enabled = false
	light.Parent = head
end

local function onPlayer(player: Player)
	player:SetAttribute("LampOn", false)
	player.CharacterAdded:Connect(function(character)
		player:SetAttribute("LampOn", false)
		addLamp(character)
	end)
	if player.Character then
		task.spawn(addLamp, player.Character)
	end
end

toggleLamp.OnServerEvent:Connect(function(player: Player)
	local now = os.clock()
	if now - (lastToggle[player] or 0) < Config.LampToggleCooldown then
		return
	end
	lastToggle[player] = now
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local light = character and character:FindFirstChild("Head") and character.Head:FindFirstChild("DiveLamp") :: SpotLight?
	if not humanoid or humanoid.Health <= 0 or not light then
		return
	end
	light.Enabled = not light.Enabled
	player:SetAttribute("LampOn", light.Enabled)
end)

Players.PlayerAdded:Connect(onPlayer)
for _, p in Players:GetPlayers() do
	onPlayer(p)
end
Players.PlayerRemoving:Connect(function(p)
	lastToggle[p] = nil
end)
