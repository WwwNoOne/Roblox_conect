--!strict
-- Inicio de partida: con E se entra al submarino (en el lobby). Cuando todos los jugadores del servidor
-- están dentro, empieza la partida y el submarino viaja (Runs lo coloca en el SubDock del Nivel 1).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Rooms = require(script.Parent:WaitForChild("Rooms"))
local Runs = require(script.Parent:WaitForChild("Runs"))

local WorldRefs = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("WorldRefs"))

local START_DELAY = 2 -- segundos entre el último en entrar y el inicio

local sub = WorldRefs.WaitSubmarine(30)
if not sub then
	warn("[Boarding] No hay Workspace.Submarine")
	return
end
local hatch = sub:WaitForChild("Hatch")
local outsideAtt = hatch:FindFirstChild("OutsidePrompt", true) :: Attachment

local prompt = Instance.new("ProximityPrompt")
prompt.Name = "BoardPrompt"
prompt.ActionText = "Entrar al submarino"
prompt.ObjectText = "Submarino"
prompt.KeyboardKeyCode = Enum.KeyCode.E
prompt.HoldDuration = 0.3
prompt.MaxActivationDistance = 10
prompt.RequiresLineOfSight = false
prompt.Parent = outsideAtt

local lobbyCode: string? = nil
local lobbyWasOpen = true -- para reconocer la vuelta al lobby tras una partida
local starting = false

local function boardedCount(): number
	local n = 0
	for _, p in Players:GetPlayers() do
		if p:GetAttribute("Boarded") == true then
			n += 1
		end
	end
	return n
end

local function allBoarded(): boolean
	local total = #Players:GetPlayers()
	return total > 0 and boardedCount() == total and total >= Config.MinPlayers
end

local function tryStart()
	if starting or not lobbyCode or not allBoarded() then
		return
	end
	starting = true
	task.delay(START_DELAY, function()
		starting = false
		local code = lobbyCode
		local room = code and Rooms.Get(code)
		if not room or room.state ~= "Lobby" or not allBoarded() then
			return -- alguien salió o se desconectó durante la espera
		end
		Rooms.Start(room.host)
	end)
end

-- Una sola sala abierta en el servidor: el primero la crea, los demás se unen.
local function enterRoom(player: Player): boolean
	if Rooms.GetByUser(player.UserId) then
		return true
	end
	local room = lobbyCode and Rooms.Get(lobbyCode)
	if room and room.state == "Lobby" then
		return (Rooms.Join(player.UserId, room.code)).ok
	end
	local result = Rooms.Create(player.UserId)
	if result.ok then
		lobbyCode = result.code
	end
	return result.ok
end

prompt.Triggered:Connect(function(player: Player)
	if Runs.GetByUser(player.UserId) or player:GetAttribute("Boarded") == true then
		return
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not humanoid or humanoid.Health <= 0 or not root then
		return
	end
	if not enterRoom(player) then
		return -- sala llena o ya hay una partida
	end
	local room = Rooms.GetByUser(player.UserId)
	local index = if room then table.find(room.members, player.UserId) or 1 else 1
	local spawn = sub:FindFirstChild("SpawnPoint" .. index, true)
	if spawn and spawn:IsA("BasePart") then
		root.CFrame = spawn.CFrame + Vector3.new(0, 3, 0)
		root.AssemblyLinearVelocity = Vector3.zero
	end
	player:SetAttribute("Boarded", true)
	tryStart()
end)

-- El botón solo funciona en el lobby; al terminar la partida se vuelve a abrir.
Rooms.Changed:Connect(function(room)
	if room.code ~= lobbyCode then
		return
	end
	if #room.members == 0 then
		lobbyCode = nil
		prompt.Enabled = true
		return
	end
	local inLobby = room.state == "Lobby"
	prompt.Enabled = inLobby
	local reopened = inLobby and not lobbyWasOpen
	lobbyWasOpen = inLobby
	if reopened then
		for _, userId in room.members do
			local p = Players:GetPlayerByUserId(userId)
			if p and not Runs.GetByUser(userId) then
				p:SetAttribute("Boarded", false)
			end
		end
	end
end)

-- Durante una partida el botón de abordaje debe estar apagado: comparte tecla con el de la compuerta (HatchPrompt) y,
-- si sigue activo junto a la puerta, "gana" al estar más cerca y el de la compuerta no responde.
Runs.StateChanged:Connect(function(_code: string, state: string)
	if state == "Descending" or state == "Level" or state == "Stopover" then
		prompt.Enabled = false
	end
end)

Players.PlayerRemoving:Connect(function(player)
	player:SetAttribute("Boarded", false)
	task.defer(tryStart) -- puede que quien faltaba fuera el que se fue
end)

Players.PlayerAdded:Connect(function(player)
	player:SetAttribute("Boarded", false)
end)
for _, p in Players:GetPlayers() do
	p:SetAttribute("Boarded", false)
end
