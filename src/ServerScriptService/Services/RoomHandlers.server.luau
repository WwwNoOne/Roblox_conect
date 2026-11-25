--!strict
-- Conecta CreateRoom / JoinRoom / StartRun / RoomUpdate con Rooms. Solo el servidor decide.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Rooms = require(script.Parent:WaitForChild("Rooms"))
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local createRoom = remotes:WaitForChild("CreateRoom") :: RemoteFunction
local joinRoom = remotes:WaitForChild("JoinRoom") :: RemoteFunction
local startRun = remotes:WaitForChild("StartRun") :: RemoteEvent
local roomUpdate = remotes:WaitForChild("RoomUpdate") :: RemoteEvent

local COOLDOWN = 0.5 -- frena fuerza bruta de códigos y spam
local last: { [Player]: { [string]: number } } = {}

-- Cada acción (create/join/start) tiene su propio enfriamiento: una no descarta a la otra.
local function throttled(player: Player, action: string): boolean
	local now = os.clock()
	local mine = last[player] or {}
	last[player] = mine
	if now - (mine[action] or 0) < COOLDOWN then
		return true
	end
	mine[action] = now
	return false
end

createRoom.OnServerInvoke = function(player: Player)
	if throttled(player, "create") then
		return { ok = false, err = "TOO_FAST" }
	end
	return Rooms.Create(player.UserId)
end

joinRoom.OnServerInvoke = function(player: Player, code: unknown)
	if throttled(player, "join") then
		return { ok = false, err = "TOO_FAST" }
	end
	return Rooms.Join(player.UserId, code)
end

startRun.OnServerEvent:Connect(function(player: Player)
	if throttled(player, "start") then
		return
	end
	Rooms.Start(player.UserId)
end)

-- Difunde el estado a los miembros; quien sale de la sala recibe nil.
local known: { [string]: { number } } = {}
Rooms.Changed:Connect(function(room)
	local previous = known[room.code] or {}
	local current: { [number]: boolean } = {}
	for _, userId in room.members do
		current[userId] = true
		local p = Players:GetPlayerByUserId(userId)
		if p then
			roomUpdate:FireClient(p, room)
		end
	end
	for _, userId in previous do
		if not current[userId] then
			local p = Players:GetPlayerByUserId(userId)
			if p then
				roomUpdate:FireClient(p, nil)
			end
		end
	end
	known[room.code] = if #room.members > 0 then room.members else nil
end)

Players.PlayerRemoving:Connect(function(player)
	last[player] = nil
end)
