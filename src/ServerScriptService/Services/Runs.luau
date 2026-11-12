--!strict
-- Estado de partida en memoria (T03): casco, profundidad, dinero común, paradas y presión.
-- Un solo servidor aloja la partida (sin matchmaking entre servidores). Los miembros vienen de Rooms.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Types = require(Shared:WaitForChild("Types"))

export type Item = { size: string, value: number }

export type Run = {
	code: string,
	members: { number },
	state: Types.RunState,
	hull: number,
	money: number,
	depth: number,
	zone: number, -- índice de la etapa alcanzada (0 = inicio)
	travelFrom: number,
	travelT: number,
	ended: boolean,
	carried: { [number]: { Item } }, -- tesoros cargados por jugador (UserId)
	upgrades: { [string]: number }, -- niveles de mejora del equipo
	deposited: number, -- valor depositado en el nivel actual (se cobra al cerrarlo)
	failures: number, -- cuotas falladas
}

export type Result = { ok: boolean, err: string? }

local Runs = {}

local homePivot: CFrame? = nil -- posición inicial del submarino (se restaura al empezar otra partida)
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

local function submarine(): Model?
	local m = workspace:FindFirstChild("Submarine")
	return if m and m:IsA("Model") then m else nil
end

local function dockOf(stage: number): BasePart?
	local def = Config.Run.Stages[stage]
	local maps = workspace:FindFirstChild("Maps")
	local map = def and maps and maps:FindFirstChild(def.Map)
	local dock = map and map:FindFirstChild("SubDock", true)
	return if dock and dock:IsA("BasePart") then dock else nil
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

local function isInsideSub(root: BasePart): boolean
	local sub = submarine()
	local zone = sub and sub:FindFirstChild("InteriorZone", true)
	if not zone or not zone:IsA("BasePart") then
		return true -- sin modelo de submarino (pruebas): no se exige
	end
	local rel = zone.CFrame:PointToObjectSpace(root.Position)
	local half = zone.Size / 2 + Vector3.new(0.5, 1, 0.5)
	return math.abs(rel.X) <= half.X and math.abs(rel.Y) <= half.Y and math.abs(rel.Z) <= half.Z
end

-- El agua del Terrain llena el interior del submarino: al acoplarlo se vacía la cabina y, al irse, se rellena.
local carved: { cf: CFrame, size: Vector3 }? = nil

local function restoreWater()
	if carved then
		workspace.Terrain:FillBlock(carved.cf, carved.size, Enum.Material.Water)
		carved = nil
	end
end

local function carveCabin()
	local sub = submarine()
	local zone = sub and sub:FindFirstChild("InteriorZone", true)
	if not zone or not zone:IsA("BasePart") then
		return
	end
	local terrain = workspace.Terrain
	local c = zone.Position
	local region = Region3.new(c - Vector3.new(4, 4, 4), c + Vector3.new(4, 4, 4)):ExpandToGrid(4)
	local materials = terrain:ReadVoxels(region, 4)
	if materials[1][1][1] ~= Enum.Material.Water then
		return -- sin agua (lobby): nada que vaciar
	end
	local size = zone.Size + Vector3.new(4, 4, 4) -- un voxel de margen: FillBlock solo vacía voxels cuyo centro cae dentro
	terrain:FillBlock(zone.CFrame, size, Enum.Material.Air)
	carved = { cf = zone.CFrame, size = size }
end

-- Daño por segundo al casco: constante en cada etapa; durante el viaje se interpola entre la etapa de origen y la de destino.
local function stageDps(index: number): number
	local def = Config.Run.Stages[index]
	return if def then def.PressureDps else 0
end

function Runs.PressureDps(run: Run): number
	if run.state == "Descending" then
		local alpha = math.clamp(run.travelT / Config.Run.TravelSeconds, 0, 1)
		local from, to = stageDps(run.zone), stageDps(run.zone + 1)
		return from + (to - from) * alpha
	end
	return stageDps(run.zone)
end

-- Multiplicador de presión por el blindaje comprado.
local function armorFactor(run: Run): number
	local level = run.upgrades.Armor or 0
	return math.max(0.2, 1 - Config.Economy.Shop.Armor.PressureFactorPerLevel * level)
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

-- Mueve submarino y tripulación que está dentro al dock de la parada (si el escenario existe).
local function moveSubTo(run: Run, zone: number)
	local sub, dock = submarine(), dockOf(zone)
	if not sub or not dock then
		return
	end
	local old = sub:GetPivot()
	local new = dock.CFrame
	local delta = new * old:Inverse()
	local riders: { BasePart } = {}
	for _, userId in run.members do
		local root = aliveRoot(userId)
		if root and isInsideSub(root) then
			table.insert(riders, root)
		end
	end
	restoreWater()
	sub:PivotTo(new)
	carveCabin()
	for _, root in riders do
		root.CFrame = delta * root.CFrame
	end
end

function Runs.Start(code: string, members: { number })
	local run: Run = {
		code = code,
		members = table.clone(members),
		state = "Descending",
		hull = Config.Run.HullMax,
		money = Config.Run.StartMoney,
		depth = 0,
		zone = 0,
		travelFrom = 0,
		travelT = 0,
		ended = false,
		carried = {},
		upgrades = {},
		deposited = 0,
		failures = 0,
	}
	runs[code] = run
	for _, userId in members do
		runOf[userId] = code
	end
	-- Colocar a la tripulación en los SpawnPoint del submarino.
	local sub = submarine()
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

-- ¿El jugador vivo está dentro de InteriorZone? (true si no hay modelo de submarino: pruebas)
function Runs.IsUserInside(userId: number): boolean
	local root = aliveRoot(userId)
	return if root then isInsideSub(root) else false
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

function Runs.RequestDescend(userId: number, hostId: number): Result
	local run = Runs.GetByUser(userId)
	if not run or run.ended then
		return { ok = false, err = "NO_RUN" }
	end
	if userId ~= hostId then
		return { ok = false, err = "NOT_HOST" }
	end
	if run.state ~= "Level" and run.state ~= "Stopover" then
		return { ok = false, err = "NOT_DOCKED" }
	end
	if run.zone >= #Config.Run.Stages then
		return { ok = false, err = "ALREADY_AT_BOTTOM" }
	end
	for _, id in run.members do
		local root = aliveRoot(id)
		if root and not isInsideSub(root) then
			return { ok = false, err = "CREW_OUTSIDE" }
		end
	end
	if run.state == "Level" then
		settle(run)
		if run.ended then
			return { ok = true } -- la partida terminó por cuotas falladas
		end
	end
	run.travelFrom = run.depth
	run.travelT = 0
	setState(run, "Descending")
	return { ok = true }
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
end

-- Devuelve el submarino al lobby; quien estaba dentro viaja con él y quien estaba fuera aparece en la salida.
function Runs.ReturnHome(members: { number })
	local sub = submarine()
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
			table.insert(if isInsideSub(root) then inside else outside, root)
		end
	end
	restoreWater()
	sub:PivotTo(homePivot :: CFrame)
	carveCabin()
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
			run.depth = run.travelFrom + (target.Depth - run.travelFrom) * alpha
			if alpha >= 1 then
				run.zone += 1
				run.depth = target.Depth
				moveSubTo(run, run.zone)
				setState(run, if target.Kind == "Parada" then "Stopover" else "Level")
			end
		end
		if run.state == "Descending" or run.state == "Level" or run.state == "Stopover" then
			run.hull = math.max(0, run.hull - Runs.PressureDps(run) * armorFactor(run) * dt)
			if run.hull <= 0 then
				finish(run, "Lost", "Implosion")
			end
		end
	end
end

-- T05/T06 usan estos para dinero y final.
function Runs.OxygenMax(userId: number): number
	local run = Runs.GetByUser(userId)
	local level = run and run.upgrades.Oxygen or 0
	return Config.BaseOxygenSeconds + level * Config.Economy.Shop.Oxygen.SecondsPerLevel
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
