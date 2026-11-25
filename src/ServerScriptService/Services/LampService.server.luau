--!strict
-- Estado de la lámpara (servidor autoritativo). La luz se dibuja en los clientes (LampClient)
-- a partir de los atributos LampOn / LampDir del Player.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local toggleLamp = remotes:WaitForChild("ToggleLamp") :: RemoteEvent
local aimLamp = remotes:WaitForChild("AimLamp") :: RemoteEvent

local AIM_MIN_INTERVAL = 0.08 -- máx ~12 Hz por cliente (límite del proyecto: 20 Hz)

local lastToggle: { [Player]: number } = {}
local lastAim: { [Player]: number } = {}

local function onPlayer(player: Player)
	player:SetAttribute("LampOn", false)
	player:SetAttribute("LampDir", Vector3.new(0, 0, -1))
	player.CharacterAdded:Connect(function()
		player:SetAttribute("LampOn", false)
	end)
end

toggleLamp.OnServerEvent:Connect(function(player: Player)
	local now = os.clock()
	if now - (lastToggle[player] or 0) < Config.LampToggleCooldown then
		return
	end
	lastToggle[player] = now
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return
	end
	player:SetAttribute("LampOn", not player:GetAttribute("LampOn"))
end)

aimLamp.OnServerEvent:Connect(function(player: Player, dir: unknown)
	if typeof(dir) ~= "Vector3" or dir.X ~= dir.X or dir.Y ~= dir.Y or dir.Z ~= dir.Z then
		return
	end
	local now = os.clock()
	if now - (lastAim[player] or 0) < AIM_MIN_INTERVAL then
		return
	end
	if dir.Magnitude < 0.5 or dir.Magnitude > 1.5 then
		return
	end
	lastAim[player] = now
	player:SetAttribute("LampDir", dir.Unit)
end)

Players.PlayerAdded:Connect(onPlayer)
for _, p in Players:GetPlayers() do
	onPlayer(p)
end
Players.PlayerRemoving:Connect(function(p)
	lastToggle[p] = nil
	lastAim[p] = nil
end)
