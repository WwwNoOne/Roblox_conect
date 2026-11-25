--!strict
-- Estado de partida en memoria (T03): dinero común, cuotas, paradas y viaje entre niveles.
-- Un solo servidor aloja la partida (sin matchmaking entre servidores). Los miembros vienen de Rooms.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Types = require(Shared:WaitForChild("Types"))
local WorldRefs = require(Shared:WaitForChild("WorldRefs"))

export type Item = { size: string, value: number, glyph: string? } -- glyph: icono de la ranura del HUD

export type Run = {
	code: string,
	members: { number },
	state: Types.RunState,
	money: number,
	zone: number, -- índice de la etapa alcanzada (0 = inicio)
	travelT: number,
	ended: boolean,
	carried: { [number]: { Item } }, -- tesoros cargados por jugador (UserId)
	upgrades: { [string]: number }, -- niveles de mejora del equipo
	deposited: number, -- valor depositado en el nivel actual (se cobra al cerrarlo)
	failures: number, -- cuotas falladas
	advanceDeadline: number?, -- os.clock() en que parte el ascensor (cuenta atrás de Avanzar)
	levelDeadline: number?, -- os.clock() en que se acaba el tiempo del nivel (Config.Run.LevelSeconds); nil fuera de un nivel
}

export type Result = { ok: boolean, err: string? }

local Runs = {}

local homePivot: CFrame? = nil -- posición inicial del ascensor (se restaura al empezar otra partida)
local defaultRespawn = Players.RespawnTime
local RESPAWN_LOCK = 1e5 -- durante una partida los muertos no reaparecen (espectador)

local runs: { [string]: Run } = {}
local runOf: { [number]: string } = {}

local stateChanged = Instance.new("BindableEvent")
Runs.StateChanged = stateChanged.Event -- (code: string, state: Types.RunState)
export type Settlement = {
	quota: number,
	deposited: number,
	met: boolean,
	payout: number,
	bonus: number,
	failures: number,
	lostItems: number,
	lost: boolean,
}

local settled = Instance.new("BindableEvent")
Runs.Settled = settled.Event -- (code: string, info: Settlement)
local ended = Instance.new("BindableEvent")
Runs.Ended = ended.Event -- (code: string, result: "Won" | "Lost", reason: string)

local function elevator(): Model?
	return WorldRefs.Elevator()
end

-- ===== Carga de mapas bajo demanda =====
-- Los mapas (Workspace.Maps.<Nivel>) se guardan en ServerStorage.MapStorage al arrancar el servidor y solo el de la etapa
-- actual está en el Workspace. En Studio (edición) no se toca nada: solo ocurre al jugar.
local ServerStorage = game:GetService("ServerStorage")
local mapStore = ServerStorage:FindFirstChild("MapStorage") or Instance.new("Folder")
mapStore.Name = "MapStorage"
mapStore.Parent = ServerStorage

local function mapNames(): { [string]: boolean }
	local names: { [string]: boolean } = {}
	for _, def in Config.Run.Stages do
		names[def.Map] = true
	end
	return names
end

local function setMapLoaded(name: string, loaded: boolean)
	local maps = workspace:FindFirstChild("Maps")
	if not maps then
		return
	end
	local from = if loaded then mapStore else maps
	local to = if loaded then maps else mapStore
	for _, m in from:GetChildren() do
		if m.Name == name then
			m.Parent = to
		end
	end
end

-- Deja en el Workspace solo el mapa `keep` (nil = ninguno, p. ej. en el lobby).
local function showOnlyMap(keep: string?)
	if keep then
		setMapLoaded(keep, true)
	end
	for name in mapNames() do
		if name ~= keep then
			setMapLoaded(name, false)
		end
	end
end

showOnlyMap(nil)

local function dockOf(stage: number): BasePart?
	local def = Config.Run.Stages[stage]
	local maps = workspace:FindFirstChild("Maps")
	local map = def and maps and maps:FindFirstChild(def.Map)
	local dock = map and map:FindFirstChild("ElevatorDock", true)
	if dock and dock:IsA("BasePart") then
		return dock
	end
	-- Sin dock en el mapa de la etapa: el ascensor aparece en Workspace.Sala_0.ElevatorDock (su pivote = el del ascensor).
	local sala = workspace:FindFirstChild("Sala_0")
	local salaDock = sala and sala:FindFirstChild("ElevatorDock", true)
	return if salaDock and salaDock:IsA("BasePart") then salaDock else nil
end

local function aliveRoot(userId: number): BasePart?
	local player = Players:GetPlayerByUserId(userId)
	local character = player and player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if humanoid and humanoid.Health > 0 and root and root:IsA("BasePart") then
		return root
	end
	return nil
end

local function isInsideElevator(root: BasePart): boolean
	local sub = elevator()
	local zone = sub and sub:FindFirstChild("InteriorZone", true)
	if not zone or not zone:IsA("BasePart") then
		return true -- sin modelo de ascensor (pruebas): no se exige
	end
	local rel = zone.CFrame:PointToObjectSpace(root.Position)
	local half = zone.Size / 2 + Vector3.new(0.5, 1, 0.5)
	return math.abs(rel.X) <= half.X and math.abs(rel.Y) <= half.Y and math.abs(rel.Z) <= half.Z
end

local function setState(run: Run, state: Types.RunState)
	if run.state ~= state then
		run.state = state
		stateChanged:Fire(run.code, state)
	end
end

local function finish(run: Run, result: "Won" | "Lost", reason: string)
	if run.ended then
		return -- solo una vez, aunque coincidan dos condiciones de final
	end
	run.ended = true
	setState(run, result)
	ended:Fire(run.code, result, reason)
end

-- Mueve el ascensor y la tripulación que está dentro al dock de la parada (si el escenario existe).
local function moveElevatorTo(run: Run, zone: number)
	local def = Config.Run.Stages[zone]
	if def then
		showOnlyMap(def.Map) -- carga el mapa de la etapa y descarga los demás
	end
	local sub, dock = elevator(), dockOf(zone)
	if not sub or not dock then
		return
	end
	local old = sub:GetPivot()
	local new = dock.CFrame
	local delta = new * old:Inverse()
	local riders: { BasePart } = {}
	for _, userId in run.members do
		local root = aliveRoot(userId)
		if root and isInsideElevator(root) then
			table.insert(riders, root)
		end
	end
	sub:PivotTo(new)
	for _, root in riders do
		root.CFrame = delta * root.CFrame
	end
end

function Runs.Start(code: string, members: { number })
	local run: Run = {
		code = code,
		members = table.clone(members),
		state = "Descending",
		money = Config.Run.StartMoney,
		zone = 0,
		travelT = 0,
		ended = false,
		carried = {},
		upgrades = {},
		deposited = 0,
		failures = 0,
		advanceDeadline = nil,
		levelDeadline = nil,
	}
	runs[code] = run
	for _, userId in members do
		runOf[userId] = code
	end
	-- Colocar a la tripulación en los SpawnPoint del ascensor.
	local sub = elevator()
	if sub then
		if not homePivot then
			homePivot = sub:GetPivot()
		end
		sub:PivotTo(homePivot :: CFrame)
		for i, userId in run.members do
			local spawn = sub:FindFirstChild("SpawnPoint" .. i, true)
			local root = aliveRoot(userId)
			if spawn and spawn:IsA("BasePart") and root then
				root.CFrame = spawn.CFrame + Vector3.new(0, 0.5, 0)
			end
		end
	end
	Players.RespawnTime = RESPAWN_LOCK
	for _, userId in members do
		local p = Players:GetPlayerByUserId(userId)
		if p then
			p:SetAttribute("InRun", true)
			p:SetAttribute("RunAlive", true)
		end
	end
	stateChanged:Fire(code, "Descending")
end

-- ¿El jugador vivo está dentro de InteriorZone? (true si no hay modelo de ascensor: pruebas)
function Runs.IsUserInside(userId: number): boolean
	local root = aliveRoot(userId)
	return if root then isInsideElevator(root) else false
end

function Runs.Get(code: string): Run?
	return runs[code]
end

function Runs.GetByUser(userId: number): Run?
	local code = runOf[userId]
	return if code then runs[code] else nil
end

-- Cierra el nivel: compara lo depositado con la cuota, paga y cuenta fallos. Niveles sin cuota: no hace nada.
local function settle(run: Run)
	local def = Config.Run.Stages[run.zone]
	local quota = def and def.Quota
	if not quota then
		return
	end
	local q = Config.Economy.Quota
	local deposited = run.deposited
	local met = deposited >= quota
	local bonus = if met then math.ceil(quota * q.BonusFraction) else 0
	local payout = if met then deposited + bonus else math.floor(deposited * q.ShortfallFactor)
	if not met then
		run.failures += 1
	end
	run.money += payout
	run.deposited = 0
	local lostItems = 0
	for userId, list in run.carried do
		lostItems += #list
		run.carried[userId] = {} -- lo no depositado se pierde al partir
	end
	local lost = run.failures >= q.MaxFailures
	settled:Fire(run.code, {
		quota = quota,
		deposited = deposited,
		met = met,
		payout = payout,
		bonus = bonus,
		failures = run.failures,
		lostItems = lostItems,
		lost = lost,
	} :: Settlement)
	if lost then
		finish(run, "Lost", "QuotaFailed")
	end
end

local function aliveMembers(run: Run): { number }
	local list = {}
	for _, id in run.members do
		if aliveRoot(id) then
			table.insert(list, id)
		end
	end
	return list
end

local function everyoneInside(run: Run): boolean
	for _, id in aliveMembers(run) do
		local root = aliveRoot(id)
		if root and not isInsideElevator(root) then
			return false
		end
	end
	return true
end

-- Parte hacia la siguiente etapa: cierra el nivel (cuota) y empieza el viaje sellado.
local function depart(run: Run)
	run.advanceDeadline = nil
	run.levelDeadline = nil
	if run.state == "Level" then
		settle(run)
		if run.ended then
			return -- la partida terminó por cuotas falladas
		end
	end
	run.travelT = 0
	setState(run, "Descending")
end

-- Cualquier miembro puede pedir avanzar. Solo (un único vivo): parte ya. Con más: cuenta atrás para que los demás entren.
function Runs.RequestDescend(userId: number): Result & { counting: boolean? }
	local run = Runs.GetByUser(userId)
	if not run or run.ended then
		return { ok = false, err = "NO_RUN" }
	end
	if run.state ~= "Level" and run.state ~= "Stopover" then
		return { ok = false, err = "NOT_DOCKED" }
	end
	if run.zone >= #Config.Run.Stages then
		return { ok = false, err = "ALREADY_AT_BOTTOM" }
	end
	if run.advanceDeadline then
		return { ok = false, err = "ALREADY_COUNTING" }
	end
	local root = aliveRoot(userId)
	if not root or not isInsideElevator(root) then
		return { ok = false, err = "NOT_INSIDE" }
	end
	if #aliveMembers(run) <= 1 or everyoneInside(run) then
		depart(run)
		return { ok = true }
	end
	run.advanceDeadline = os.clock() + Config.Run.AdvanceCountdown
	return { ok = true, counting = true }
end

-- Libera la partida terminada: los miembros dejan de ser espectadores y pueden reaparecer.
function Runs.Close(code: string)
	local run = runs[code]
	if not run then
		return
	end
	for _, userId in run.members do
		runOf[userId] = nil
		local p = Players:GetPlayerByUserId(userId)
		if p then
			p:SetAttribute("InRun", false)
			p:SetAttribute("RunAlive", true)
		end
	end
	runs[code] = nil
	if next(runs) == nil then
		Players.RespawnTime = defaultRespawn
	end
	Runs.ReturnHome(run.members)
	showOnlyMap(nil) -- de vuelta en el lobby no hace falta ningún nivel cargado
end

-- Devuelve el ascensor al lobby; quien estaba dentro viaja con él y quien estaba fuera aparece en la salida.
function Runs.ReturnHome(members: { number })
	local sub = elevator()
	if not sub or not homePivot then
		return
	end
	local old = sub:GetPivot()
	local delta = (homePivot :: CFrame) * old:Inverse()
	local inside: { BasePart } = {}
	local outside: { BasePart } = {}
	for _, userId in members do
		local root = aliveRoot(userId)
		if root then
			table.insert(if isInsideElevator(root) then inside else outside, root)
		end
	end
	sub:PivotTo(homePivot :: CFrame)
	for _, root in inside do
		root.CFrame = delta * root.CFrame
	end
	local exitAtt = sub:FindFirstChild("ExitPoint", true)
	for _, root in outside do
		if exitAtt and exitAtt:IsA("Attachment") then
			root.CFrame = exitAtt.WorldCFrame
		end
	end
end

function Runs.RemoveUser(userId: number)
	local code = runOf[userId]
	runOf[userId] = nil
	local run = code and runs[code]
	if not run then
		return
	end
	local idx = table.find(run.members, userId)
	if idx then
		table.remove(run.members, idx)
	end
	if #run.members == 0 then
		runs[code] = nil
		if next(runs) == nil then
			Players.RespawnTime = defaultRespawn
		end
	end
end

-- Sube a bordo (junto a la entrada) a quien sigue fuera del ascensor.
local function boardStragglers(run: Run)
	local sub = elevator()
	local entry = sub and sub:FindFirstChild("EntryPoint", true)
	for _, id in aliveMembers(run) do
		local root = aliveRoot(id)
		if root and not isInsideElevator(root) and entry and entry:IsA("Attachment") then
			root.CFrame = entry.WorldCFrame
			root.AssemblyLinearVelocity = Vector3.zero
		end
	end
end

function Runs.Step(dt: number)
	for _, run in runs do
		if run.ended then
			continue
		end
		-- Muertes: espectador, se pierde lo que cargaba; todos muertos = derrota.
		local alive = 0
		for _, userId in run.members do
			local p = Players:GetPlayerByUserId(userId)
			local humanoid = p and p.Character and p.Character:FindFirstChildOfClass("Humanoid")
			local dead = humanoid ~= nil and humanoid.Health <= 0
			if p then
				p:SetAttribute("RunAlive", not dead)
			end
			if dead then
				if p and #(run.carried[userId] or {}) > 0 then
					run.carried[userId] = {}
					p:SetAttribute("CarryCount", 0)
				end
			else
				alive += 1
			end
		end
		if alive == 0 and #run.members > 0 then
			finish(run, "Lost", "AllDead")
			continue
		end
		if run.state == "Descending" then
			run.travelT += dt
			local target = Config.Run.Stages[run.zone + 1]
			local alpha = math.clamp(run.travelT / Config.Run.TravelSeconds, 0, 1)
			if alpha >= 1 then
				run.zone += 1
				moveElevatorTo(run, run.zone)
				setState(run, if target.Kind == "Parada" then "Stopover" else "Level")
				run.levelDeadline = if target.Kind == "Parada" then nil else os.clock() + Config.Run.LevelSeconds
			end
		elseif run.advanceDeadline and (run.state == "Level" or run.state == "Stopover") then
			local timedOut = os.clock() >= run.advanceDeadline
			if timedOut or everyoneInside(run) then
				if timedOut then
					-- Quien no llegó a tiempo es subido a bordo para no quedar atrás.
					boardStragglers(run)
				end
				depart(run)
			end
		end
		-- Se acabó el tiempo del nivel: el ascensor parte solo (cuota incluida) y en el último nivel se pierde la partida.
		if not run.ended and run.state == "Level" and run.levelDeadline and os.clock() >= run.levelDeadline then
			run.levelDeadline = nil
			if run.zone >= #Config.Run.Stages then
				finish(run, "Lost", "TimeUp")
			else
				boardStragglers(run)
				depart(run)
			end
		end
	end
end

-- T05/T06 usan estos para dinero y final.
-- Segundos que quedan del nivel (nil si no hay temporizador activo).
function Runs.LevelTimeLeft(run: Run): number?
	local d = run.levelDeadline
	return if d and run.state == "Level" then math.max(0, d - os.clock()) else nil
end

function Runs.AddMoney(code: string, amount: number)
	local run = runs[code]
	if run and not run.ended then
		run.money += amount
	end
end

function Runs.Finish(code: string, result: "Won" | "Lost", reason: string)
	local run = runs[code]
	if run then
		finish(run, result, reason)
	end
end

Players.PlayerRemoving:Connect(function(player)
	Runs.RemoveUser(player.UserId)
end)

return Runs
