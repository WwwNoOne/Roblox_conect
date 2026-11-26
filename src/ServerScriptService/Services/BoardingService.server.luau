--!strict
-- Inicio de partida en el lobby: la puerta del ascensor está abierta y se entra andando. Quien está dentro de InteriorZone
-- queda apuntado a la sala del servidor (atributo Boarded) y ve "Esperando jugadores". Con todos los jugadores del servidor
-- dentro, la puerta se cierra y, tras una pausa, empieza la partida (Runs lleva el ascensor al Nivel 1).
-- Si alguien sale o llega un jugador nuevo antes del arranque, la puerta se vuelve a abrir.
-- Estado para los clientes (BoardingHud), en atributos del Model del ascensor: BoardPhase, BoardCount, BoardTotal.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Sfx = require(Shared:WaitForChild("Sfx"))
local WorldRefs = require(Shared:WaitForChild("WorldRefs"))
local Rooms = require(script.Parent:WaitForChild("Rooms"))
local Runs = require(script.Parent:WaitForChild("Runs"))

local Cfg = Config.Boarding

local sub = WorldRefs.WaitElevator(30)
if not sub then
	warn("[Boarding] No hay Workspace.Elevator")
	return
end
local gate = sub:WaitForChild("Gate")
local door = gate:WaitForChild("Door") :: BasePart
local doorClosed = gate:FindFirstChild("DoorClosed", true) :: Attachment
local doorOpen = gate:FindFirstChild("DoorOpen", true) :: Attachment
local entryAtt = gate:FindFirstChild("EntryPoint", true) :: Attachment?
local zone = sub:FindFirstChild("InteriorZone", true) :: BasePart

-- El botón de abordaje antiguo (teletransporte) ya no se usa: se entra por la puerta.
local oldPrompt = gate:FindFirstChild("BoardPrompt", true)
if oldPrompt then
	oldPrompt:Destroy()
end

type Phase = "Waiting" | "Closing" | "Starting" | "Away"

local phase: Phase = "Waiting"
local lobbyCode: string? = nil
local doorTween: Tween? = nil
local doorIsOpen = false
local cycle = 0 -- invalida cierres en curso cuando se reabre la puerta
-- Quien vuelve de una partida dentro del ascensor debe salir y volver a entrar (si no, arrancaría otra partida sola).
local mustExit: { [Player]: boolean } = {}

local function moveDoor(open: boolean)
	if doorIsOpen == open and not doorTween then
		return
	end
	doorIsOpen = open
	if doorTween then
		doorTween:Cancel()
	end
	local target = if open then doorOpen.WorldCFrame else doorClosed.WorldCFrame
	local info = TweenInfo.new(Cfg.DoorSeconds, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
	local tween = TweenService:Create(door, info, { CFrame = target })
	doorTween = tween
	tween.Completed:Connect(function()
		if doorTween == tween then
			doorTween = nil
		end
	end)
	tween:Play()
	local sound = if open then Config.Sfx.ElevatorExit else Config.Sfx.ElevatorEnter
	Sfx.Play(sound, door, Config.Audio.ElevatorVolume, Config.Audio.ElevatorRollOff)
end

local function aliveRoot(player: Player): BasePart?
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if humanoid and humanoid.Health > 0 and root and root:IsA("BasePart") then
		return root
	end
	return nil
end

local function isInside(root: BasePart): boolean
	local rel = zone.CFrame:PointToObjectSpace(root.Position)
	local half = zone.Size / 2 + Vector3.new(0.5, 1, 0.5)
	return math.abs(rel.X) <= half.X and math.abs(rel.Y) <= half.Y and math.abs(rel.Z) <= half.Z
end

-- Jugadores que cuentan para el abordaje: los que no están en una partida.
local function lobbyPlayers(): { Player }
	local list = {}
	for _, p in Players:GetPlayers() do
		if not Runs.GetByUser(p.UserId) then
			table.insert(list, p)
		end
	end
	return list
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

local function leaveRoom(player: Player)
	local room = Rooms.GetByUser(player.UserId)
	if room and room.state == "Lobby" then
		Rooms.Leave(player.UserId)
	end
end

local function setPhase(p: Phase)
	phase = p
	sub:SetAttribute("BoardPhase", p)
end

local function reopen()
	cycle += 1
	setPhase("Waiting")
	moveDoor(true)
end

local function allBoarded(list: { Player }): boolean
	if #list == 0 or #list < Config.MinPlayers then
		return false
	end
	for _, p in list do
		if p:GetAttribute("Boarded") ~= true then
			return false
		end
	end
	return true
end

-- Quien esté en el umbral al cerrar pasa dentro: la hoja es anclada y lo dejaría atrapado.
local function clearDoorway(list: { Player })
	if not entryAtt then
		return
	end
	local n = 0
	for _, p in list do
		local root = aliveRoot(p)
		if root then
			local rel = doorClosed.WorldCFrame:PointToObjectSpace(root.Position)
			if math.abs(rel.Z) < Cfg.DoorwayClear and math.abs(rel.X) < door.Size.X / 2 + 1 then
				-- Cada uno en un hueco distinto: dos personajes en el mismo punto se solapan y uno cae al vacío.
				local offset = Vector3.new(((n % 3) - 1) * 2.5, 0, -math.floor(n / 3) * 2.5)
				n += 1
				root.CFrame = entryAtt.WorldCFrame * CFrame.new(offset)
				root.AssemblyLinearVelocity = Vector3.zero
			end
		end
	end
end

local function beginClose(list: { Player })
	cycle += 1
	local myCycle = cycle
	setPhase("Closing")
	clearDoorway(list)
	moveDoor(false)
	task.delay(Cfg.DoorSeconds + Cfg.StartDelay, function()
		if cycle ~= myCycle or phase ~= "Closing" then
			return
		end
		local room = lobbyCode and Rooms.Get(lobbyCode)
		if not room or room.state ~= "Lobby" or not allBoarded(lobbyPlayers()) then
			reopen() -- alguien salió o llegó un jugador nuevo durante el cierre
			return
		end
		setPhase("Starting")
		local result = Rooms.Start(room.host)
		if not result.ok then
			warn("[Boarding] No se pudo iniciar:", result.err)
			reopen()
		end
	end)
end

local function poll()
	if phase == "Away" or phase == "Starting" then
		return
	end
	local list = lobbyPlayers()
	local count = 0
	for _, p in list do
		local root = aliveRoot(p)
		local inside = root ~= nil and isInside(root :: BasePart)
		if not inside and mustExit[p] then
			mustExit[p] = nil
			p:SetAttribute("BoardMustExit", nil)
		end
		local boarded = p:GetAttribute("Boarded") == true
		if inside and not boarded and not mustExit[p] then
			if enterRoom(p) then
				p:SetAttribute("Boarded", true)
				boarded = true
			end
		elseif not inside and boarded then
			leaveRoom(p)
			p:SetAttribute("Boarded", false)
			boarded = false
		end
		if boarded then
			count += 1
		end
	end
	sub:SetAttribute("BoardCount", count)
	sub:SetAttribute("BoardTotal", #list)

	local ready = allBoarded(list)
	if phase == "Waiting" and ready then
		beginClose(list)
	elseif phase == "Closing" and not ready then
		reopen()
	end
end

-- Partida en marcha: el ascensor se va; la puerta la controla ElevatorService.
Runs.StateChanged:Connect(function(_code: string, state: string)
	if state == "Descending" or state == "Level" or state == "Stopover" then
		cycle += 1
		if doorTween then
			doorTween:Cancel()
			doorTween = nil
		end
		doorIsOpen = false
		setPhase("Away")
	end
end)

-- Vuelta al lobby tras una partida: se reabre la puerta y quien llega dentro tiene que salir y volver a entrar.
Rooms.Changed:Connect(function(room)
	if room.code ~= lobbyCode then
		return
	end
	if #room.members == 0 then
		lobbyCode = nil
		return
	end
	if room.state ~= "Lobby" or phase ~= "Away" then
		return
	end
	-- Primero se suelta la sala (los Leave de abajo vuelven a disparar Changed y deben ignorarse).
	lobbyCode = nil
	setPhase("Waiting")
	for _, userId in table.clone(room.members) do
		local p = Players:GetPlayerByUserId(userId)
		if p and not Runs.GetByUser(userId) then
			p:SetAttribute("Boarded", false)
			local root = aliveRoot(p)
			local inside = root ~= nil and isInside(root :: BasePart)
			mustExit[p] = if inside then true else nil
			p:SetAttribute("BoardMustExit", if inside then true else nil)
			Rooms.Leave(userId) -- sala nueva para la siguiente partida
		end
	end
	task.defer(reopen) -- deja que Runs termine de devolver el ascensor antes de mover la puerta
end)

Players.PlayerAdded:Connect(function(player)
	player:SetAttribute("Boarded", false)
end)
Players.PlayerRemoving:Connect(function(player)
	player:SetAttribute("Boarded", false)
	mustExit[player] = nil
end)
for _, p in Players:GetPlayers() do
	p:SetAttribute("Boarded", false)
end

door.CFrame = doorClosed.WorldCFrame
reopen()
task.spawn(function()
	while true do
		task.wait(Cfg.PollInterval)
		poll()
	end
end)
