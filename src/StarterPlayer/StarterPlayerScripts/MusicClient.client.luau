--!strict
-- Música de fondo por contexto (Workspace.sonidos.Musica_background): Lobby fuera de partida, una pista por nivel
-- (Config.Audio.Music.Levels) y silencio gradual en la Parada y durante los viajes. Cruce suave entre pistas.
-- El contexto sale del HUD de partida (UpdateHUD: runState y zone); sin partida suena el Lobby.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local M = Config.Audio.Music
local updateHud = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("UpdateHUD") :: RemoteEvent
local player = Players.LocalPlayer

-- Pista por nombre exacto (sin distinguir mayúsculas) en cualquier subcarpeta de Workspace.sonidos.
local function findTrack(name: string): Sound?
	local root = workspace:FindFirstChild("sonidos") or workspace:WaitForChild("sonidos", 10)
	if not root then
		return nil
	end
	local lower = string.lower(name)
	for _, d in root:GetDescendants() do
		if d:IsA("Sound") and string.lower(d.Name) == lower then
			return d
		end
	end
	return nil
end

local current: Sound? = nil
local currentName: string? = nil

local function fadeOut(sound: Sound)
	local tween = TweenService:Create(sound, TweenInfo.new(M.FadeSeconds), { Volume = 0 })
	tween.Completed:Once(function()
		sound:Destroy()
	end)
	tween:Play()
end

local function setTrack(name: string?)
	if name == currentName then
		return
	end
	currentName = name
	if current then
		fadeOut(current)
		current = nil
	end
	if not name then
		return
	end
	local template = findTrack(name)
	if not template then
		warn("[Music] No hay pista '" .. name .. "' en Workspace.sonidos")
		return
	end
	local sound = template:Clone()
	sound.Name = "Music_" .. name
	sound.Looped = true
	sound.Volume = 0
	sound.Parent = SoundService
	sound:Play()
	TweenService:Create(sound, TweenInfo.new(M.FadeSeconds), { Volume = M.Volume }):Play()
	current = sound
end

local state: string? = nil
local zone = 0

local function refresh()
	local inRun = player:GetAttribute("InRun") == true
	if not inRun then
		setTrack(M.Lobby)
	elseif state == "Level" then
		local stage = (Config.Run.Stages :: any)[zone]
		setTrack(stage and (M.Levels :: any)[stage.Map])
	else
		setTrack(nil) -- viaje, Parada o final de partida: sin música
	end
end

updateHud.OnClientEvent:Connect(function(payload: any)
	local newState = payload.runState
	local newZone = payload.zone or 0
	if newState ~= state or newZone ~= zone then
		state, zone = newState, newZone
		refresh()
	end
end)
player:GetAttributeChangedSignal("InRun"):Connect(function()
	if player:GetAttribute("InRun") ~= true then
		state, zone = nil, 0
	end
	refresh()
end)
task.spawn(refresh)
