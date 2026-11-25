--!strict
-- Estado de salas en memoria (T02). Lógica pura; los remotos los conecta RoomHandlers.
-- Un jugador está como máximo en una sala. Código de sala: letras/números sin ambiguos.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Types = require(Shared:WaitForChild("Types"))

local ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"

type Room = {
	code: string,
	host: number,
	members: { number }, -- UserIds en orden de entrada
	state: Types.RunState,
}

export type Result = { ok: boolean, code: string?, err: string? }

local Rooms = {}

local rooms: { [string]: Room } = {}
local roomOf: { [number]: string } = {}

-- Aviso a otros servicios; (room: Types.RoomState).
local changed = Instance.new("BindableEvent")
Rooms.Changed = changed.Event
-- Aviso de que el anfitrión inició (T03 lo escucha); (code: string).
local started = Instance.new("BindableEvent")
Rooms.Started = started.Event

local function snapshot(room: Room): Types.RoomState
	return { code = room.code, host = room.host, members = table.clone(room.members), state = room.state }
end

local function newCode(): string
	for _ = 1, 50 do
		local chars = table.create(Config.RoomCodeLength)
		for i = 1, Config.RoomCodeLength do
			local k = math.random(1, #ALPHABET)
			chars[i] = string.sub(ALPHABET, k, k)
		end
		local code = table.concat(chars)
		if not rooms[code] then
			return code
		end
	end
	error("no se pudo generar un código de sala")
end

local function notify(room: Room)
	changed:Fire(snapshot(room))
end

function Rooms.GetByUser(userId: number): Types.RoomState?
	local code = roomOf[userId]
	local room = code and rooms[code]
	return if room then snapshot(room) else nil
end

function Rooms.Get(code: string): Types.RoomState?
	local room = rooms[code]
	return if room then snapshot(room) else nil
end

function Rooms.Leave(userId: number)
	local code = roomOf[userId]
	if not code then
		return
	end
	roomOf[userId] = nil
	local room = rooms[code]
	if not room then
		return
	end
	local idx = table.find(room.members, userId)
	if idx then
		table.remove(room.members, idx)
	end
	if #room.members == 0 then
		rooms[code] = nil
		changed:Fire({ code = code, host = 0, members = {}, state = room.state } :: Types.RoomState)
		return
	end
	if room.host == userId then
		room.host = room.members[1] -- el siguiente en entrar pasa a ser anfitrión
	end
	notify(room)
end

function Rooms.Create(userId: number): Result
	if roomOf[userId] then
		return { ok = false, err = "ALREADY_IN_ROOM" }
	end
	local code = newCode()
	local room: Room = { code = code, host = userId, members = { userId }, state = "Lobby" }
	rooms[code] = room
	roomOf[userId] = code
	notify(room)
	return { ok = true, code = code }
end

function Rooms.Join(userId: number, rawCode: unknown): Result
	if roomOf[userId] then
		return { ok = false, err = "ALREADY_IN_ROOM" }
	end
	if type(rawCode) ~= "string" or #rawCode ~= Config.RoomCodeLength then
		return { ok = false, err = "INVALID_CODE" }
	end
	local room = rooms[string.upper(rawCode)]
	if not room then
		return { ok = false, err = "ROOM_NOT_FOUND" }
	end
	if room.state ~= "Lobby" then
		return { ok = false, err = "RUN_IN_PROGRESS" }
	end
	if #room.members >= Config.MaxPlayers then
		return { ok = false, err = "ROOM_FULL" }
	end
	table.insert(room.members, userId)
	roomOf[userId] = room.code
	notify(room)
	return { ok = true, code = room.code }
end

-- Cualquier miembro puede pedirlo; solo el anfitrión tiene efecto.
function Rooms.Start(userId: number): Result
	local code = roomOf[userId]
	local room = code and rooms[code]
	if not room then
		return { ok = false, err = "NOT_IN_ROOM" }
	end
	if room.host ~= userId then
		return { ok = false, err = "NOT_HOST" }
	end
	if room.state ~= "Lobby" then
		return { ok = false, err = "ALREADY_STARTED" }
	end
	if #room.members < Config.MinPlayers then
		return { ok = false, err = "NOT_ENOUGH_PLAYERS" }
	end
	room.state = "Descending"
	notify(room)
	started:Fire(room.code)
	return { ok = true, code = room.code }
end

-- T03/T06 cambian el estado de la sala desde aquí.
function Rooms.SetState(code: string, state: Types.RunState)
	local room = rooms[code]
	if room and room.state ~= state then
		room.state = state
		notify(room)
	end
end

Players.PlayerRemoving:Connect(function(player)
	Rooms.Leave(player.UserId)
end)

return Rooms
