--!strict
-- Servicio de criaturas 2.5D del laberinto (T05; ver docs/criaturas.md).
-- Gestiona 3 categorías con navegación sobre mapas fijos (MapNav / PathfindingService) y reacción a Noise.Emitted:
--   * Aggressive: patrulla, detecta vista (x linterna) y oído, persigue con frenesí y mata al atraparte (Windup -> Lunge).
--   * Stalker: observa a distancia desde pasillos oscuros; huye si lo miras fijo y delata tu posición si lo ignoras.
--   * Ambusher: espera en esquinas o cajas HideSpot/Escondite; lanza screamer 2D animado, quita vida y huye.
-- Variantes con comportamiento propio (campo `Behavior` de la especie en Config.Monster.Species):
--   * SujetoFeliz (Aggressive): aparece lejos y observa; si su objetivo lo mira fijo, embiste; si aparta la vista, desaparece.
--   * FinalPursuit (Stalker): acecha como el Acosador y, en el tramo final del nivel, persigue despacio y sin descanso.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Types = require(Shared:WaitForChild("Types"))
local Sfx = require(Shared:WaitForChild("Sfx"))
local Runs = require(script.Parent:WaitForChild("Runs"))
local Assets = require(script.Parent:WaitForChild("Assets"))
local LevelState = require(script.Parent:WaitForChild("LevelState"))
local MapNav = require(script.Parent:WaitForChild("MapNav"))
local Hiding = require(script.Parent:WaitForChild("Hiding"))
local SafeZone = require(script.Parent:WaitForChild("SafeZone"))
local Noise = require(script.Parent:WaitForChild("Noise"))

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local playerHit = remotes:WaitForChild("PlayerHit") :: RemoteEvent
local creatureScreamer = remotes:WaitForChild("CreatureScreamer") :: RemoteEvent

local K = Config.Monster
local rng = Random.new()

type Monster = {
	k: any,
	category: string,
	dead: boolean,
	model: Model,
	root: BasePart,
	state: string,
	stateT: number,
	timer: number,
	pos: Vector3,
	vel: Vector3,
	dir: Vector3,
	path: { Vector3 },
	idx: number,
	target: Player?,
	lastSeen: Vector3?,
	lostAt: number,
	scanAt: number,
	repathAt: number,
	lookAt: number,
	attackAt: number,
	lunDir: Vector3,
	hitDone: boolean,
	searchUntil: number,
	sniffT: number,
	-- Stalker
	watchedT: number,
	stalkIgnoredT: number,
	cooldownUntil: number,
	-- Variantes (SujetoFeliz / FinalPursuit)
	behavior: string,
	gazeT: number, -- s seguidos que el objetivo lo mira
	awayT: number, -- s seguidos mirando a otro lado
	seenOnce: boolean, -- el objetivo ya lo miró al menos una vez en esta aparición
	-- Ambusher
	ambushSpot: MapNav.AmbushSpot?,
	lastAmbushPos: Vector3?,
	-- Anti-atasco
	stuckPos: Vector3,
	stuckAt: number,
	pathReq: number, -- id de la última petición de camino: un resultado de PathfindingService anterior se descarta
	pending: boolean, -- esperando a PathfindingService sin camino del grafo: follow() no lo da por llegado
	code: string,
	params: RaycastParams,
}

local actives: { Monster } = {}
local lastHit: { [Player]: number } = {}

local function dbg(msg: string)
	if K.Debug then
		print("[Monstruos] " .. msg)
	end
end

-- ===== Plantillas (Studio o generación automática 2.5D desde Config.Monster.Species) =====
local function findTemplate(name: string): Model?
	local creatures = ServerStorage:FindFirstChild("GameAssets") and ServerStorage.GameAssets:FindFirstChild("Creatures")
	local stash = ServerStorage:FindFirstChild("Plantillas")
	for _, root in { creatures, stash, workspace:FindFirstChild("Creatures") } do
		if root then
			for _, d in root:GetDescendants() do
				if d.Name == name and d:IsA("Model") then
					return d
				end
			end
		end
	end
	local a = Assets.Find(name)
	return if a and a:IsA("Model") then a else nil
end

local function makeBillboard(name: string, childName: string, image: string, size: Vector2, offset: Vector3, lightInfluence: number, zIndex: number, cols: number, rows: number, root: BasePart)
	local bb = Instance.new("BillboardGui")
	bb.Name = name
	bb.Adornee = root
	bb.AlwaysOnTop = false
	bb.LightInfluence = lightInfluence
	bb.MaxDistance = 240
	bb.Size = UDim2.fromScale(size.X, size.Y)
	bb.StudsOffset = offset
	bb.Parent = root

	local img = Instance.new("ImageLabel")
	img.Name = childName
	img.Size = UDim2.fromScale(1, 1)
	img.BackgroundTransparency = 1
	img.Image = image
	img.ScaleType = Enum.ScaleType.Fit
	img.ImageRectSize = Vector2.new(math.floor(1024 / math.max(1, cols)), math.floor(1024 / math.max(1, rows)))
	img.ImageRectOffset = Vector2.zero
	img.ZIndex = zIndex
	img.Parent = bb
end

local function buildFallbackTemplate(k: any): Model
	local model = Instance.new("Model")
	model.Name = k.TemplateName

	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = Vector3.new(2, 8, 2)
	root.Transparency = 1
	root.Anchored = true
	root.CanCollide = false
	root.CanQuery = false
	root.CanTouch = false
	root.CastShadow = false
	root.Massless = true
	root.Parent = model
	model.PrimaryPart = root

	local grab = Instance.new("Attachment")
	grab.Name = "Grab"
	grab.Position = Vector3.new(0, 0.5, -1)
	grab.Parent = root

	local cols = k.SpriteCols or 4
	local rows = k.SpriteRows or 4
	local bbSize: Vector2 = k.BillboardSize or Vector2.new(8.5, 8.5)
	local offset: Vector3 = k.StudsOffset or Vector3.new(0, 0, 0)

	if k.BodyImage and k.BodyImage ~= "" then
		makeBillboard("BodyBillboard", "Sprite", k.BodyImage, bbSize, offset, 1, 1, cols, rows, root)
	end
	if k.EyesImage and k.EyesImage ~= "" then
		makeBillboard("EyesBillboard", "Eyes", k.EyesImage, bbSize, offset, 0, 2, cols, rows, root)
	end

	return model
end

local function applyAtmosphereDetails(model: Model, root: BasePart, k: any)
	-- Asegura los atributos del contrato 2.5D incluso si el modelo vino sin alguno
	if model:GetAttribute("Category") == nil then
		model:SetAttribute("Category", k.Category or "Aggressive")
	end
	if model:GetAttribute("SpriteCols") == nil then
		model:SetAttribute("SpriteCols", k.SpriteCols or 4)
	end
	if model:GetAttribute("SpriteRows") == nil then
		model:SetAttribute("SpriteRows", k.SpriteRows or 4)
	end
	if model:GetAttribute("AnimFps") == nil then
		model:SetAttribute("AnimFps", k.AnimFps or 12)
	end
	if k.BodyImage and model:GetAttribute("BodyImage") == nil then
		model:SetAttribute("BodyImage", k.BodyImage)
	end
	if k.EyesImage and model:GetAttribute("EyesImage") == nil then
		model:SetAttribute("EyesImage", k.EyesImage)
	end
	if k.ScreamerImage and model:GetAttribute("ScreamerImage") == nil then
		model:SetAttribute("ScreamerImage", k.ScreamerImage)
		model:SetAttribute("ScreamerCols", k.ScreamerCols or 4)
		model:SetAttribute("ScreamerRows", k.ScreamerRows or 4)
		model:SetAttribute("ScreamerFrames", k.ScreamerFrames or 12)
	end

	-- Luz tenue y partículas sutiles para dar presencia 3D en pasillos oscuros
	if not root:FindFirstChildOfClass("PointLight") then
		local light = Instance.new("PointLight")
		light.Name = "EyeLight"
		light.Color = k.LightColor or Color3.fromRGB(220, 120, 90)
		light.Range = if k.Category == "Stalker" then 10 else 8
		light.Brightness = if k.Category == "Ambusher" then 0.35 else 0.7
		light.Shadows = false
		light.Parent = root
	end
	if not root:FindFirstChildOfClass("ParticleEmitter") then
		local aura = Instance.new("ParticleEmitter")
		aura.Name = "AuraParticles"
		aura.Color = ColorSequence.new(Color3.fromRGB(14, 14, 18))
		aura.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.2), NumberSequenceKeypoint.new(1, 3.2) })
		aura.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.72), NumberSequenceKeypoint.new(1, 1) })
		aura.Lifetime = NumberRange.new(0.8, 1.6)
		aura.Rate = if k.Category == "Ambusher" then 4 else 8
		aura.Speed = NumberRange.new(0.5, 1.8)
		aura.SpreadAngle = Vector2.new(180, 180)
		aura.Parent = root
	end
end

-- ===== Red de navegación =====
local function nearestVertex(nav: MapNav.NavGraph, pos: Vector3, ahead: Vector3?): number
	local best, bestScore = 1, math.huge
	for i, p in nav.points do
		local d = (p - pos).Magnitude
		local score = d
		if ahead and d > 1.5 and (p - pos).Unit:Dot(ahead) < 0 then
			score += 30
		end
		if score < bestScore then
			best, bestScore = i, score
		end
	end
	return best
end

local function shortestPath(nav: MapNav.NavGraph, from: number, to: number): { Vector3 }
	local n = #nav.points
	local dist: { number } = table.create(n, math.huge)
	local prev: { number } = table.create(n, 0)
	local done: { boolean } = table.create(n, false)
	dist[from] = 0
	for _ = 1, n do
		local u, best = 0, math.huge
		for i = 1, n do
			if not done[i] and dist[i] < best then
				u, best = i, dist[i]
			end
		end
		if u == 0 or u == to then
			break
		end
		done[u] = true
		for _, e in nav.adj[u] do
			local nd = dist[u] + e.d
			if nd < dist[e.to] then
				dist[e.to] = nd
				prev[e.to] = u
			end
		end
	end
	local path: { Vector3 } = {}
	if dist[to] == math.huge then
		return path
	end
	local v = to
	while v ~= 0 do
		table.insert(path, 1, nav.points[v])
		v = prev[v]
	end
	return path
end

local function clearBetween(m: Monster, a: Vector3, b: Vector3, radius: number): boolean
	local d = b - a
	if d.Magnitude < 0.5 then
		return true
	end
	return workspace:Spherecast(a, radius, d, m.params) == nil
end

-- Camino directo (sin pasar por setPath): invalida cualquier respuesta pendiente de PathfindingService.
local function setDirect(m: Monster, p: Vector3)
	m.pathReq += 1
	m.pending = false
	m.path = { p }
	m.idx = 1
end

local function setPath(m: Monster, targetPos: Vector3)
	local nav = LevelState.nav :: MapNav.NavGraph?
	if not nav then
		return
	end
	if clearBetween(m, m.pos, targetPos, m.k.BodyRadius * 0.9) and not SafeZone.BarsMonster(targetPos) then
		setDirect(m, targetPos)
		return
	end
	-- Camino inmediato por el grafo Dijkstra (sin ceder el hilo de Heartbeat)
	local from = nearestVertex(nav, m.pos, m.dir)
	local to = nearestVertex(nav, targetPos, nil)
	local full = shortestPath(nav, from, to)
	local path: { Vector3 } = {}
	for _, p in full do
		if SafeZone.BarsMonster(p) then
			break
		end
		table.insert(path, p)
	end
	m.path = path
	m.idx = 1

	-- Refinamiento asíncrono con PathfindingService (esquiva paredes y puertas cerradas sin bloquear Heartbeat). Solo vale la
	-- respuesta de la última petición; si el grafo no dio camino, la criatura espera (pending) en vez de darlo por llegado.
	m.pathReq += 1
	local req = m.pathReq
	m.pending = #path == 0
	local origin = m.pos
	local radius = m.k.BodyRadius
	local centerY = m.k.CenterHeight
	task.spawn(function()
		local navMesh = MapNav.ComputeNavMeshPath(origin, targetPos, radius, centerY)
		if m.dead or req ~= m.pathReq then
			return
		end
		m.pending = false
		if navMesh and #navMesh > 0 then
			m.path = navMesh
			m.idx = 1
		end
	end)
end


-- ===== Jugadores y detección =====
local function inMaze(pos: Vector3): boolean
	local nav = LevelState.nav :: MapNav.NavGraph?
	if not nav then
		return false
	end
	local rel = pos - nav.boundsCenter
	local h = nav.boundsHalf
	return math.abs(rel.X) <= h.X and math.abs(rel.Y) <= h.Y and math.abs(rel.Z) <= h.Z
end

local function playerRoot(player: Player): BasePart?
	local c = player.Character
	local humanoid = c and c:FindFirstChildOfClass("Humanoid")
	local root = c and c:FindFirstChild("HumanoidRootPart")
	if humanoid and humanoid.Health > 0 and root and root:IsA("BasePart") then
		return root
	end
	return nil
end

local function eligibleRoot(player: Player, m: Monster): BasePart?
	local run = Runs.GetByUser(player.UserId)
	if not run or run.code ~= m.code or run.state ~= "Level" then
		return nil
	end
	local root = playerRoot(player)
	if not root or Runs.IsUserInside(player.UserId) or SafeZone.IsPlayerSafe(root.Position) or not inMaze(root.Position) then
		return nil
	end
	return root
end

local function eligiblePlayers(m: Monster): { { player: Player, root: BasePart } }
	local list = {}
	for _, player in Players:GetPlayers() do
		local root = eligibleRoot(player, m)
		if root then
			table.insert(list, { player = player, root = root })
		end
	end
	return list
end

local function headPos(m: Monster): Vector3
	return m.pos + m.dir * (m.k.HeadOffset or 0)
end

local function bodyDistance(m: Monster, point: Vector3): number
	return (point - m.pos).Magnitude
end

local function hasLineOfSight(m: Monster, target: BasePart): boolean
	local from = headPos(m)
	return workspace:Raycast(from, target.Position - from, m.params) == nil
end

local function detect(m: Monster): (Player?, BasePart?)
	local best: Player? = nil
	local bestRoot: BasePart? = nil
	local bestDist = math.huge
	for _, entry in eligiblePlayers(m) do
		local player, root = entry.player, entry.root
		local d = (root.Position - m.pos).Magnitude
		local seen = false
		if player:GetAttribute("Hidden") == true then
			seen = d <= m.k.HiddenRange
		else
			local sight = m.k.SightRange * (if player:GetAttribute("LampOn") then m.k.LampSightMultiplier else 1)
			local noisy = player:GetAttribute("Sprinting") == true
			local hear = if noisy then m.k.NoiseRange else m.k.HearRange
			if not noisy and player:GetAttribute("Crouching") == true then
				hear *= Config.Movement.CrouchHearFactor
			end
			seen = d <= hear or (d <= sight and hasLineOfSight(m, root))
		end
		if seen and d < bestDist then
			best, bestRoot, bestDist = player, root, d
		end
	end
	return best, bestRoot
end

-- ===== Movimiento y física =====
local function place(m: Monster)
	-- Los modelos 2.5D siempre van erguidos (solo giran en horizontal)
	local flat = Vector3.new(m.dir.X, 0, m.dir.Z)
	local look = if flat.Magnitude > 0.05 then flat.Unit else Vector3.zAxis * -1
	m.model:PivotTo(CFrame.lookAt(m.pos, m.pos + look, Vector3.yAxis))
end

local function turnToward(m: Monster, desired: Vector3, rate: number, dt: number)
	local flat = Vector3.new(desired.X, 0, desired.Z)
	if flat.Magnitude < 0.01 then
		return
	end
	local d = m.dir:Lerp(flat.Unit, 1 - math.exp(-rate * dt))
	m.dir = if d.Magnitude < 0.01 then flat.Unit else d.Unit
end

local function advance(m: Monster, dt: number): boolean
	local delta = m.vel * dt
	local dist = delta.Magnitude
	if dist < 1e-4 then
		return false
	end
	if SafeZone.BarsMonster(m.pos + delta) then
		m.vel = Vector3.zero
		return true
	end
	local blocked = false
	local hit = workspace:Spherecast(m.pos, m.k.BodyRadius, delta.Unit * (dist + 0.4), m.params)
	if hit then
		blocked = true
		local n = Vector3.new(hit.Normal.X, 0, hit.Normal.Z)
		if n.Magnitude > 0.05 then
			n = n.Unit
			m.vel -= n * m.vel:Dot(n)
		else
			m.vel = Vector3.zero
		end
		delta = m.vel * dt
		if hit.Distance < 0.05 then
			delta += hit.Normal * math.min(dt * 6, 0.4)
		end
	end
	m.pos += delta
	-- Mantener pegado al suelo para escaleras/desniveles suaves
	local floorHit = workspace:Raycast(m.pos + Vector3.new(0, 3, 0), Vector3.new(0, -10, 0), m.params)
	if floorHit then
		m.pos = Vector3.new(m.pos.X, floorHit.Position.Y + m.k.CenterHeight, m.pos.Z)
	end
	return blocked
end

local function drive(m: Monster, desiredVel: Vector3, accel: number, dt: number): boolean
	local diff = desiredVel - m.vel
	local mag = diff.Magnitude
	local maxStep = accel * dt
	m.vel = if mag <= maxStep then desiredVel else m.vel + diff * (maxStep / mag)
	local blocked = advance(m, dt)
	if m.vel.Magnitude > 1.2 then
		turnToward(m, m.vel, m.k.TurnRate, dt)
	end
	place(m)
	return blocked
end

local function carrotPoint(m: Monster, look: number): Vector3
	local p = m.pos
	local remaining = look
	for i = m.idx, #m.path do
		local seg = m.path[i] - p
		local d = seg.Magnitude
		if d >= remaining and d > 1e-3 then
			return p + seg.Unit * remaining
		end
		remaining -= d
		p = m.path[i]
	end
	return m.path[#m.path]
end

local function follow(m: Monster, speed: number, dt: number, now: number): boolean
	if #m.path == 0 then
		drive(m, Vector3.zero, m.k.Brake, dt)
		return not m.pending
	end
	local radius = m.k.BodyRadius * 0.9
	if now >= m.lookAt then
		m.lookAt = now + 0.12
		for j = math.min(#m.path, m.idx + 3), m.idx + 1, -1 do
			if clearBetween(m, m.pos, m.path[j], radius) then
				m.idx = j
				break
			end
		end
	end
	local target = m.path[m.idx]
	local to = target - m.pos
	local dist = to.Magnitude
	if dist < m.k.WaypointRadius then
		if m.idx >= #m.path then
			drive(m, Vector3.zero, m.k.Brake, dt)
			return true
		end
		m.idx += 1
		target = m.path[m.idx]
		to = target - m.pos
		dist = to.Magnitude
		if dist < 0.01 then
			return false
		end
	end
	local v = speed
	if m.idx >= #m.path then
		v = math.min(speed, math.max(4, dist * 2))
	end
	local heading = to
	local look = math.clamp(speed * m.k.Carrot, 6, 16)
	local c = carrotPoint(m, look)
	if (c - m.pos).Magnitude > 0.5 and clearBetween(m, m.pos, c, radius) then
		heading = c - m.pos
	end
	drive(m, heading.Unit * v, m.k.Accel, dt)
	return false
end

local function pickFarPoint(nav: MapNav.NavGraph, fromPos: Vector3, minDist: number, avoid: Vector3?, avoidRadius: number): Vector3
	for _ = 1, 25 do
		local p = nav.points[rng:NextInteger(1, #nav.points)]
		if (p - fromPos).Magnitude >= minDist and not SafeZone.BarsMonster(p) and (not avoid or (p - avoid).Magnitude >= avoidRadius) then
			return p
		end
	end
	for _ = 1, 15 do
		local p = nav.points[rng:NextInteger(1, #nav.points)]
		if not SafeZone.BarsMonster(p) then
			return p
		end
	end
	return nav.points[rng:NextInteger(1, #nav.points)]
end

local function pickPatrolTarget(m: Monster, avoid: Vector3?)
	local nav = LevelState.nav :: MapNav.NavGraph?
	if not nav then
		return
	end
	setPath(m, pickFarPoint(nav, m.pos, 50, avoid, m.k.AvoidRadius))
end

local function pickNear(m: Monster, around: Vector3)
	local nav = LevelState.nav :: MapNav.NavGraph?
	if not nav then
		return
	end
	local near = {}
	for _, p in nav.points do
		if (p - around).Magnitude <= m.k.LingerRadius and not SafeZone.BarsMonster(p) then
			table.insert(near, p)
		end
	end
	if #near == 0 then
		pickPatrolTarget(m)
		return
	end
	setPath(m, near[rng:NextInteger(1, #near)])
end

-- ===== Estado y daño =====
local function setState(m: Monster, state: string)
	if m.state == state then
		return
	end
	m.state = state
	m.stateT = 0
	m.model:SetAttribute("Estado", state)
	m.model:SetAttribute("Atacando", state == "Windup" or state == "Lunge" or state == "AmbushStrike")
end

local function damagePlayer(player: Player, amount: number)
	local now = os.clock()
	if (lastHit[player] or 0) + K.HitGap > now then
		return
	end
	lastHit[player] = now
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.Health > 0 then
		humanoid:TakeDamage(amount)
		playerHit:FireClient(player, amount)
	end
end

local function alertAggressives(source: Monster?, pos: Vector3, radius: number)
	if SafeZone.BarsMonster(pos) then
		return
	end
	for _, o in actives do
		if o ~= source and not o.dead and o.category == "Aggressive" and o.behavior == "" then
			if (o.state == "Patrol" or o.state == "Search" or o.state == "Investigate") and (o.pos - pos).Magnitude <= radius then
				o.lastSeen = pos
				setState(o, "Investigate")
				setPath(o, pos)
				dbg(o.model.Name .. " acude al aviso/ruido")
			end
		end
	end
end

-- ===== Aparición inicial =====
local function spawnMonster(m: Monster, now: number): boolean
	local nav = LevelState.nav :: MapNav.NavGraph?
	local entry = LevelState.entry
	if not nav or not entry then
		return false
	end
	local pool = if #nav.spawns > 0 then nav.spawns else nav.points
	local spawn = pool[1]
	for _ = 1, 40 do
		local p = pool[rng:NextInteger(1, #pool)]
		if (p - entry).Magnitude >= m.k.MinSpawnDistance and not SafeZone.BarsMonster(p) then
			spawn = p
			break
		end
	end
	m.pos = spawn
	m.vel = Vector3.zero
	m.dir = Vector3.new(1, 0, 0)
	m.stuckPos, m.stuckAt = spawn, now
	place(m)
	return true
end

local function checkStuck(m: Monster, now: number): boolean
	if now - m.stuckAt < m.k.StuckSeconds then
		return false
	end
	local stuck = (m.pos - m.stuckPos).Magnitude < 2
	m.stuckPos, m.stuckAt = m.pos, now
	if stuck then
		m.repathAt = 0
		m.vel = Vector3.zero
	end
	return stuck
end

-- ===== Categoría 1: Agresivo =====
local function attackStep(m: Monster, dt: number, now: number)
	m.stateT += dt
	local player = m.target
	local root = player and eligibleRoot(player, m)
	if m.state == "Windup" then
		if not player or not root or player:GetAttribute("Hidden") == true then
			setState(m, "Search")
			m.searchUntil = now + m.k.SearchSeconds
			if m.lastSeen then
				setPath(m, m.lastSeen)
			end
			return
		end
		local aim = root.Position - headPos(m)
		turnToward(m, aim, m.k.TurnRate * 3, dt)
		drive(m, m.dir * m.k.ChaseSpeed * 0.2, m.k.Brake, dt)
		if m.stateT >= m.k.WindupSeconds then
			m.lunDir = if aim.Magnitude > 0.1 then Vector3.new(aim.X, 0, aim.Z).Unit else m.dir
			m.hitDone = false
			setState(m, "Lunge")
		end
	elseif m.state == "Lunge" then
		if root then
			local want = Vector3.new(root.Position.X - m.pos.X, 0, root.Position.Z - m.pos.Z)
			if want.Magnitude > 0.1 then
				m.lunDir = m.lunDir:Lerp(want.Unit, math.min(1, dt * 3)).Unit
			end
		end
		turnToward(m, m.lunDir, m.k.TurnRate * 2, dt)
		m.vel = m.lunDir * m.k.LungeSpeed
		local blocked = advance(m, dt)
		place(m)
		if not m.hitDone then
			for _, entry in eligiblePlayers(m) do
				if entry.player:GetAttribute("Hidden") ~= true and bodyDistance(m, entry.root.Position) <= m.k.HitRadius then
					damagePlayer(entry.player, m.k.AttackDamage)
					m.hitDone = true
				end
			end
		end
		if m.stateT >= m.k.LungeSeconds or blocked or m.hitDone then
			m.attackAt = now + m.k.AttackCooldown
			setState(m, "Recover")
		end
	else
		drive(m, m.dir * m.k.ChaseSpeed * 0.25, m.k.Brake, dt)
		if m.stateT >= m.k.RecoverSeconds then
			m.lostAt = now
			setState(m, "Chase")
		end
	end
end

local function stepAggressive(m: Monster, dt: number, now: number)
	if m.state == "Hidden" then
		m.timer -= dt
		if m.timer <= 0 and spawnMonster(m, now) then
			setState(m, "Patrol")
			pickPatrolTarget(m)
			dbg(m.model.Name .. " (Agresivo) aparece")
		end
		return
	end

	if m.state == "Windup" or m.state == "Lunge" or m.state == "Recover" then
		attackStep(m, dt, now)
		return
	end

	if now >= m.scanAt then
		m.scanAt = now + 0.2
		local player, root = detect(m)
		if player and root then
			if m.state ~= "Chase" then
				dbg(m.model.Name .. " detecta a " .. player.Name)
				alertAggressives(m, root.Position, m.k.AlertRadius)
				setState(m, "Chase")
				m.attackAt = math.max(m.attackAt, now + 0.3)
				Sfx.Play(Config.Sfx.CreatureRoar, m.root, 0.9, 150)
			end
			m.target, m.lastSeen, m.lostAt = player, root.Position, now
		elseif m.state == "Chase" and now - m.lostAt > (if m.target and m.target:GetAttribute("Hidden") == true then m.k.HiddenLoseSeconds else m.k.LoseSeconds) then
			setState(m, "Search")
			m.target = nil
			m.searchUntil = now + m.k.SearchSeconds
			if m.lastSeen then
				setPath(m, m.lastSeen)
			end
		end
	end

	if checkStuck(m, now) and (m.state == "Patrol" or m.state == "Search") then
		pickPatrolTarget(m)
	end

	if m.state == "Chase" then
		local player = m.target
		local root = player and eligibleRoot(player, m)
		if not player or not root then
			setState(m, "Search")
			m.target = nil
			m.searchUntil = now + m.k.SearchSeconds
			return
		end
		local hiding = player:GetAttribute("Hidden") == true
		local away = (root.Position - m.pos).Magnitude
		local sees = not hiding and hasLineOfSight(m, root)
		if hiding then
			if away <= m.k.HiddenRange then
				m.lostAt = now
				m.sniffT += dt
				if m.sniffT >= m.k.DiscoverSeconds then
					m.sniffT = 0
					Hiding.Release(player)
					player:SetAttribute("HudNotice", "¡Te encontró!|" .. tostring(os.clock()))
				end
			else
				m.sniffT = math.max(0, m.sniffT - dt)
			end
		else
			m.sniffT = 0
			if sees then
				m.lastSeen = root.Position
				m.lostAt = now
			elseif away <= m.k.HearRange then
				m.lostAt = now
			end
		end
		if sees and away <= m.k.AttackStart and now >= m.attackAt then
			setState(m, "Windup")
			return
		end
		local aim = root.Position
		if sees then
			local lead = math.min(away / math.max(m.k.ChaseSpeed, 1), m.k.LeadSeconds)
			aim = root.Position + root.AssemblyLinearVelocity * lead
			if not clearBetween(m, m.pos, aim, m.k.BodyRadius * 0.9) then
				aim = root.Position
			end
		end
		if sees and clearBetween(m, m.pos, aim, m.k.BodyRadius * 0.9) then
			setDirect(m, aim)
		elseif now >= m.repathAt then
			m.repathAt = now + 0.45
			setPath(m, root.Position)
		end
		local frenzy = 1 + m.k.FrenzyBonus * math.clamp(m.stateT / m.k.FrenzySeconds, 0, 1)
		if follow(m, m.k.ChaseSpeed * frenzy, dt, now) then
			m.path = {}
		end
	elseif m.state == "Investigate" then
		if follow(m, m.k.ChaseSpeed * 0.8, dt, now) then
			setState(m, "Search")
			m.searchUntil = now + m.k.SearchSeconds
		end
	elseif m.state == "Search" then
		if now >= m.searchUntil then
			setState(m, "Patrol")
			pickPatrolTarget(m, m.lastSeen)
		elseif follow(m, m.k.PatrolSpeed * m.k.SearchSpeedMul, dt, now) then
			pickNear(m, m.lastSeen or m.pos)
		end
	else
		if follow(m, m.k.PatrolSpeed, dt, now) then
			pickPatrolTarget(m)
		end
	end
end

-- ===== Categoría 2: Acosador (Stalker) =====
local function pickStalkPoint(m: Monster, targetPos: Vector3): Vector3?
	local nav = LevelState.nav :: MapNav.NavGraph?
	if not nav then
		return nil
	end
	local best: Vector3? = nil
	local bestScore = math.huge
	for _, p in nav.points do
		if not SafeZone.BarsMonster(p) then
			local d = (p - targetPos).Magnitude
			if d >= m.k.StalkMinDist and d <= m.k.StalkMaxDist then
				-- Prefiere puntos con línea de visión hacia el jugador y lejos de su posición actual para variar ángulos
				local los = workspace:Raycast(p, targetPos - p, m.params) == nil
				local score = math.abs(d - 52) + (if los then 0 else 45)
				if score < bestScore then
					bestScore = score
					best = p
				end
			end
		end
	end
	return best or pickFarPoint(nav, targetPos, m.k.StalkMinDist, nil, 0)
end

-- En primera persona el HumanoidRootPart sigue el giro horizontal de la cámara. La cabeza no sirve: Turning.client la tuerce
-- hasta 60° respecto al cuerpo. Se compara en el plano horizontal.
local function isPlayerLookingAt(_player: Player, root: BasePart, pos: Vector3, cosLimit: number): boolean
	local look = root.CFrame.LookVector
	look = Vector3.new(look.X, 0, look.Z)
	local toMonster = pos - root.Position
	toMonster = Vector3.new(toMonster.X, 0, toMonster.Z)
	if toMonster.Magnitude < 1 or look.Magnitude < 0.01 then
		return true
	end
	return look.Unit:Dot(toMonster.Unit) >= cosLimit
end

local function stepStalker(m: Monster, dt: number, now: number)
	if m.state == "Hidden" then
		m.timer -= dt
		if m.timer <= 0 and spawnMonster(m, now) then
			setState(m, "StalkMove")
			dbg(m.model.Name .. " (Acosador) aparece")
		end
		return
	end

	local players = eligiblePlayers(m)
	if #players == 0 then
		if m.state ~= "Patrol" then
			setState(m, "Patrol")
			pickPatrolTarget(m)
		elseif follow(m, m.k.PatrolSpeed, dt, now) then
			pickPatrolTarget(m)
		end
		return
	end

	if m.state == "Cooldown" then
		drive(m, Vector3.zero, m.k.Brake, dt)
		if now >= m.cooldownUntil then
			setState(m, "StalkMove")
		end
		return
	end

	if m.state == "Flee" then
		if checkStuck(m, now) then
			pickPatrolTarget(m)
		end
		local done = follow(m, m.k.AmbushFleeSpeed, dt, now)
		if done or m.stateT >= 3.5 then
			m.cooldownUntil = now + m.k.StalkCooldown * 0.5
			setState(m, "Cooldown")
		end
		return
	end

	local chosen = players[1]
	for _, entry in players do
		if (entry.root.Position - m.pos).Magnitude < (chosen.root.Position - m.pos).Magnitude then
			chosen = entry
		end
	end
	m.target = chosen.player

	if m.state == "StalkMove" then
		if checkStuck(m, now) then
			m.path = {}
		end
		if #m.path == 0 or now >= m.repathAt then
			m.repathAt = now + 1.5
			local spot = pickStalkPoint(m, chosen.root.Position)
			if spot then
				setPath(m, spot)
			end
		end
		local arrived = follow(m, m.k.StalkSpeed, dt, now)
		local d = (chosen.root.Position - m.pos).Magnitude
		if arrived or (d >= m.k.StalkMinDist and d <= m.k.StalkMaxDist and hasLineOfSight(m, chosen.root)) then
			m.watchedT = 0
			m.stalkIgnoredT = 0
			setState(m, "StalkWatch")
		end
	elseif m.state == "StalkWatch" then
		drive(m, Vector3.zero, m.k.Brake, dt)
		turnToward(m, chosen.root.Position - m.pos, m.k.TurnRate * 1.5, dt)
		place(m)

		local d = (chosen.root.Position - m.pos).Magnitude
		if d < m.k.StalkTooClose then
			dbg(m.model.Name .. " se retira por cercanía")
			local nav = LevelState.nav :: MapNav.NavGraph?
			if nav then
				setPath(m, pickFarPoint(nav, chosen.root.Position, 65, nil, 0))
			end
			setState(m, "Flee")
			return
		end

		local sees = chosen.player:GetAttribute("Hidden") ~= true and d <= m.k.StalkMaxDist * 1.15 and hasLineOfSight(m, chosen.root)
		if not sees then
			if m.stateT > 4 then
				setState(m, "StalkMove")
			end
			return
		end

		-- Comprobar si algún jugador lo está mirando de frente
		local lookedAt = false
		for _, entry in players do
			local ed = (entry.root.Position - m.pos).Magnitude
			local dotLimit = if entry.player:GetAttribute("LampOn") == true then m.k.StalkLookDot - 0.08 else m.k.StalkLookDot
			if ed <= m.k.StalkMaxDist * 1.15 and hasLineOfSight(m, entry.root) and isPlayerLookingAt(entry.player, entry.root, m.pos, dotLimit) then
				lookedAt = true
				break
			end
		end

		if lookedAt then
			m.watchedT += dt
			m.stalkIgnoredT = math.max(0, m.stalkIgnoredT - dt * 0.5)
			if m.watchedT >= m.k.StalkBanishSeconds then
				dbg(m.model.Name .. " fue descubierto y huye")
				Sfx.Play(Config.Sfx.CreatureAlert, m.root, 0.75, 120)
				local nav = LevelState.nav :: MapNav.NavGraph?
				if nav then
					setPath(m, pickFarPoint(nav, chosen.root.Position, 75, nil, 0))
				end
				setState(m, "Flee")
			end
		else
			m.watchedT = math.max(0, m.watchedT - dt * 0.5)
			m.stalkIgnoredT += dt
			if m.stalkIgnoredT >= m.k.StalkAlertSeconds then
				dbg(m.model.Name .. " delata a " .. chosen.player.Name)
				chosen.player:SetAttribute("HudNotice", "Algo te está observando...| " .. tostring(os.clock()))
				Sfx.Play(Config.Sfx.CreatureAlert, m.root, 0.9, 140)
				alertAggressives(m, chosen.root.Position, 220)
				local nav = LevelState.nav :: MapNav.NavGraph?
				if nav then
					setPath(m, pickFarPoint(nav, chosen.root.Position, 75, nil, 0))
				end
				setState(m, "Flee")
			end
		end
	else
		setState(m, "StalkMove")
	end
end

-- ===== Categoría 3: Acechador (Ambusher) =====
local function spotTakenByOther(spotPos: Vector3, selfMonster: Monster): boolean
	for _, o in actives do
		if o ~= selfMonster and not o.dead and o.category == "Ambusher" and o.ambushSpot then
			if (o.ambushSpot.pos - spotPos).Magnitude < 12 then
				return true
			end
		end
	end
	return false
end

local function pickAmbushSpot(m: Monster): MapNav.AmbushSpot?
	local nav = LevelState.nav :: MapNav.NavGraph?
	if not nav or #nav.ambushSpots == 0 then
		return nil
	end
	local candidates: { MapNav.AmbushSpot } = {}
	for _, s in nav.ambushSpots do
		if not SafeZone.BarsMonster(s.pos) and not spotTakenByOther(s.pos, m) then
			if not m.lastAmbushPos or (s.pos - m.lastAmbushPos).Magnitude >= 20 then
				table.insert(candidates, s)
			end
		end
	end
	if #candidates == 0 then
		return nav.ambushSpots[rng:NextInteger(1, #nav.ambushSpots)]
	end
	return candidates[rng:NextInteger(1, #candidates)]
end

local function triggerScreamer(m: Monster, player: Player)
	creatureScreamer:FireClient(player, {
		image = m.k.ScreamerImage or m.k.BodyImage or "",
		cols = m.k.ScreamerCols or 4,
		rows = m.k.ScreamerRows or 4,
		frames = m.k.ScreamerFrames or 12,
		duration = m.k.AmbushScreamerSeconds,
		monsterName = m.k.Name,
	})
end

local function stepAmbusher(m: Monster, dt: number, now: number)
	if m.state == "Hidden" then
		m.timer -= dt
		if m.timer <= 0 and spawnMonster(m, now) then
			setState(m, "AmbushMove")
			dbg(m.model.Name .. " (Acechador) aparece")
		end
		return
	end

	if m.state == "Cooldown" then
		drive(m, Vector3.zero, m.k.Brake, dt)
		if now >= m.cooldownUntil then
			m.ambushSpot = nil
			setState(m, "AmbushMove")
		end
		return
	end

	if m.state == "AmbushStrike" then
		drive(m, Vector3.zero, m.k.Brake, dt)
		if m.target then
			local r = eligibleRoot(m.target, m)
			if r then
				turnToward(m, r.Position - m.pos, m.k.TurnRate * 4, dt)
				place(m)
			end
		end
		if m.stateT >= 0.65 then
			local nav = LevelState.nav :: MapNav.NavGraph?
			if nav then
				setPath(m, pickFarPoint(nav, m.pos, 70, m.lastAmbushPos, 35))
			end
			setState(m, "Flee")
		end
		return
	end

	if m.state == "Flee" then
		if checkStuck(m, now) then
			pickPatrolTarget(m)
		end
		if follow(m, m.k.AmbushFleeSpeed, dt, now) or m.stateT >= 3.2 then
			m.cooldownUntil = now + m.k.AmbushCooldown
			setState(m, "Cooldown")
		end
		return
	end

	if m.state == "AmbushMove" then
		if not m.ambushSpot then
			m.ambushSpot = pickAmbushSpot(m)
			if m.ambushSpot then
				setPath(m, m.ambushSpot.pos)
			end
		end
		if checkStuck(m, now) and m.ambushSpot then
			setPath(m, m.ambushSpot.pos)
		end
		if follow(m, m.k.AmbushMoveSpeed, dt, now) or m.stateT >= 14 then
			if m.ambushSpot then
				m.lastAmbushPos = m.ambushSpot.pos
			end
			setState(m, "AmbushWait")
		end
		return
	end

	-- AmbushWait: espera quieto en esquina o junto a HideSpot
	drive(m, Vector3.zero, m.k.Brake, dt)
	local players = eligiblePlayers(m)
	local spot = m.ambushSpot
	local triggerDist = if spot and spot.hideSpot then m.k.AmbushHideSpotRange else m.k.AmbushRange

	for _, entry in players do
		local player, root = entry.player, entry.root
		local d = (root.Position - m.pos).Magnitude
		local hidden = player:GetAttribute("Hidden") == true
		-- Escondido: solo lo saca si está en el escondite que vigila (o pegado a él); a la vista: si cruza el umbral.
		local inWatched = hidden and spot ~= nil and spot.hideSpot ~= nil and (root.Position - spot.hideSpot.Position).Magnitude <= 4
		if inWatched or (not hidden and d <= triggerDist and hasLineOfSight(m, root)) or (hidden and d <= 3) then
			if player:GetAttribute("Hidden") == true then
				Hiding.Release(player)
			end
			m.target = player
			turnToward(m, root.Position - m.pos, 30, dt)
			place(m)
			triggerScreamer(m, player)
			damagePlayer(player, m.k.AmbushDamage)
			dbg(m.model.Name .. " embosca con screamer a " .. player.Name)
			setState(m, "AmbushStrike")
			return
		end
	end

	if m.stateT >= m.k.AmbushRelocateSeconds then
		m.ambushSpot = nil
		setState(m, "AmbushMove")
	end
end

-- ===== Variante agresiva: SujetoFeliz =====
local HIDDEN_POS = Vector3.new(0, -2000, 0)

-- Desaparece (sin atacar) y vuelve a aparecer pasados `delay` segundos.
local function vanish(m: Monster, delay: number)
	m.pos = HIDDEN_POS
	m.vel = Vector3.zero
	m.path = {}
	m.pathReq += 1
	m.pending = false
	m.target = nil
	place(m)
	m.timer = delay
	setState(m, "Hidden")
end

local function felizRespawnDelay(m: Monster): number
	return rng:NextNumber(m.k.FelizRespawnMin, m.k.FelizRespawnMax)
end

-- Punto navegable a FelizAppearMin..Max del objetivo con línea de visión hacia él (fuera de la zona segura).
local function pickAppearPoint(m: Monster, target: BasePart): Vector3?
	local nav = LevelState.nav :: MapNav.NavGraph?
	if not nav then
		return nil
	end
	local candidates: { Vector3 } = {}
	for _, p in nav.points do
		local d = (p - target.Position).Magnitude
		if d >= m.k.FelizAppearMin and d <= m.k.FelizAppearMax and not SafeZone.BarsMonster(p) then
			if workspace:Raycast(p, target.Position - p, m.params) == nil then
				table.insert(candidates, p)
			end
		end
	end
	if #candidates == 0 then
		return nil
	end
	return candidates[rng:NextInteger(1, #candidates)]
end

local function stepSujetoFeliz(m: Monster, dt: number, now: number)
	if m.state == "Hidden" then
		m.timer -= dt
		if m.timer > 0 or not LevelState.nav then
			return
		end
		local visible = {}
		for _, entry in eligiblePlayers(m) do
			if entry.player:GetAttribute("Hidden") ~= true then
				table.insert(visible, entry)
			end
		end
		local chosen = if #visible > 0 then visible[rng:NextInteger(1, #visible)] else nil
		local spot = chosen and pickAppearPoint(m, chosen.root)
		if not chosen or not spot then
			m.timer = 2 -- nadie a tiro o ningún punto con vista: reintenta pronto
			return
		end
		local face = Vector3.new(chosen.root.Position.X - spot.X, 0, chosen.root.Position.Z - spot.Z)
		m.pos = spot
		m.vel = Vector3.zero
		m.dir = if face.Magnitude > 0.1 then face.Unit else m.dir
		m.stuckPos, m.stuckAt = spot, now
		m.target = chosen.player
		m.gazeT, m.awayT, m.seenOnce = 0, 0, false
		place(m)
		setState(m, "Stare")
		dbg(m.model.Name .. " aparece y observa a " .. chosen.player.Name)
		return
	end

	local player = m.target
	local root = player and eligibleRoot(player, m)
	if not player or not root or player:GetAttribute("Hidden") == true then
		vanish(m, felizRespawnDelay(m)) -- el objetivo murió, se escondió o volvió al Ascensor
		return
	end

	if m.state == "Stare" then
		drive(m, Vector3.zero, m.k.Brake, dt)
		turnToward(m, root.Position - m.pos, m.k.TurnRate, dt)
		place(m)
		-- Solo cuenta la mirada del objetivo; una pared en medio es perder la vista.
		local looking = hasLineOfSight(m, root) and isPlayerLookingAt(player, root, m.pos, m.k.FelizLookDot)
		if looking then
			m.seenOnce = true
			m.awayT = 0
			m.gazeT += dt
			if m.gazeT >= m.k.FelizGazeSeconds then
				dbg(m.model.Name .. " embiste a " .. player.Name)
				Sfx.Play(Config.Sfx.CreatureRoar, m.root, 0.95, 160)
				m.repathAt = 0
				setState(m, "Charge")
			end
		else
			m.gazeT = 0
			if m.seenOnce then
				m.awayT += dt
				if m.awayT >= m.k.FelizLookAwaySeconds then
					dbg(m.model.Name .. " desaparece (apartó la vista)")
					vanish(m, felizRespawnDelay(m))
				end
			elseif m.stateT >= m.k.FelizInitialWindow then
				dbg(m.model.Name .. " desaparece (no lo miró)")
				vanish(m, felizRespawnDelay(m))
			end
		end
		return
	end

	-- Charge: una vez lanzada, apartar la mirada ya no la cancela. La ruta respeta paredes, puertas y el Ascensor.
	if m.stateT >= m.k.FelizChargeMaxSeconds then
		vanish(m, felizRespawnDelay(m))
		return
	end
	if clearBetween(m, m.pos, root.Position, m.k.BodyRadius * 0.9) and not SafeZone.BarsMonster(root.Position) then
		setDirect(m, root.Position)
	elseif now >= m.repathAt then
		m.repathAt = now + 0.3
		setPath(m, root.Position)
	end
	follow(m, m.k.FelizChargeSpeed, dt, now)
	if bodyDistance(m, root.Position) <= m.k.HitRadius then
		damagePlayer(player, m.k.AttackDamage)
		vanish(m, felizRespawnDelay(m))
	end
end

-- ===== Variante del Acosador: persecución del tramo final =====
local function nearestEligible(m: Monster): (Player?, BasePart?)
	local best: Player? = nil
	local bestRoot: BasePart? = nil
	local bestD = math.huge
	for _, entry in eligiblePlayers(m) do
		local d = (entry.root.Position - m.pos).Magnitude
		if entry.player:GetAttribute("Hidden") == true then
			d += 1e4 -- prefiere a quien está a la vista
		end
		if d < bestD then
			best, bestRoot, bestD = entry.player, entry.root, d
		end
	end
	return best, bestRoot
end

-- Aparición para la persecución final: el punto navegable más cercano que esté a FinalSpawnMinDist o más del objetivo.
local function pickFinalSpawn(m: Monster, target: BasePart): Vector3?
	local nav = LevelState.nav :: MapNav.NavGraph?
	if not nav then
		return nil
	end
	local best: Vector3? = nil
	local bestD = math.huge
	for _, p in nav.points do
		local d = (p - target.Position).Magnitude
		if d >= m.k.FinalSpawnMinDist and d < bestD and not SafeZone.BarsMonster(p) then
			best, bestD = p, d
		end
	end
	return best
end

local function stepFinalPursuit(m: Monster, dt: number, now: number)
	if m.state ~= "FinalChase" then
		local run = Runs.Get(m.code)
		local left = run and Runs.LevelTimeLeft(run)
		if not left or left > m.k.FinalPhaseSeconds then
			stepStalker(m, dt, now)
			return
		end
		local player, root = nearestEligible(m)
		if not player or not root then
			stepStalker(m, dt, now) -- nadie fuera del Ascensor todavía
			return
		end
		if m.state == "Hidden" or m.pos.Y < -500 then
			local spot = pickFinalSpawn(m, root)
			if not spot then
				return
			end
			m.pos = spot
			m.vel = Vector3.zero
			m.stuckPos, m.stuckAt = spot, now
			place(m)
		end
		m.target = player
		m.lastSeen = root.Position
		m.repathAt = 0
		Sfx.Play(Config.Sfx.CreatureAlert, m.root, 0.95, 160)
		dbg(m.model.Name .. " empieza la persecución final tras " .. player.Name)
		setState(m, "FinalChase")
		return
	end

	-- FinalChase: hasta que termine el nivel. Si su objetivo muere o entra al Ascensor, cambia a otro jugador válido.
	local player = m.target
	local root = player and eligibleRoot(player, m)
	if not player or not root then
		player, root = nearestEligible(m)
		m.target = player
		if root then
			m.lastSeen = root.Position
			m.repathAt = 0
		end
	end
	if not player or not root then
		drive(m, Vector3.zero, m.k.Brake, dt)
		return
	end
	local hidden = player:GetAttribute("Hidden") == true
	local sees = not hidden and hasLineOfSight(m, root)
	if sees then
		m.lastSeen = root.Position
	end
	local goal = m.lastSeen or root.Position
	if sees and clearBetween(m, m.pos, goal, m.k.BodyRadius * 0.9) and not SafeZone.BarsMonster(goal) then
		setDirect(m, goal)
	elseif now >= m.repathAt then
		m.repathAt = now + 0.8
		setPath(m, goal)
	end
	if checkStuck(m, now) then
		m.repathAt = 0
	end
	-- Llega a la última posición conocida sin verlo: retoma el rastro hacia donde está ahora (si no está escondido).
	if follow(m, m.k.FinalChaseSpeed, dt, now) and not sees and not hidden then
		m.lastSeen = root.Position
		m.repathAt = 0
	end
	if not hidden and bodyDistance(m, root.Position) <= m.k.HitRadius then
		damagePlayer(player, m.k.FinalAttackDamage)
	end
end

-- ===== Despacho principal =====
local function step(m: Monster, dt: number)
	local now = os.clock()
	local freezeStateT = m.state == "Windup" or m.state == "Lunge" or m.state == "Recover" or m.state == "AmbushStrike"
	if not freezeStateT then
		m.stateT += dt
	end

	if m.behavior == "SujetoFeliz" then
		stepSujetoFeliz(m, dt, now)
	elseif m.behavior == "FinalPursuit" then
		stepFinalPursuit(m, dt, now)
	elseif m.category == "Stalker" then
		stepStalker(m, dt, now)
	elseif m.category == "Ambusher" then
		stepAmbusher(m, dt, now)
	else
		stepAggressive(m, dt, now)
	end
end

-- ===== Ciclo de vida =====
local function destroyAll()
	for _, m in actives do
		m.dead = true
		m.model:Destroy()
	end
	table.clear(actives)
end

local function speciesParams(spec: any): any
	local k = {}
	for key, v in K :: any do
		if key ~= "Species" then
			k[key] = v
		end
	end
	for key, v in spec do
		k[key] = v
	end
	return k
end

local function pickSpecies(n: number): { any }
	local pool = table.clone(K.Species)
	local chosen = {}
	while #chosen < n and #pool > 0 do
		local total = 0
		for _, spec in pool do
			total += spec.Weight or 1
		end
		local r = rng:NextNumber() * total
		for idx, spec in pool do
			r -= spec.Weight or 1
			if r <= 0 then
				table.insert(chosen, spec)
				table.remove(pool, idx)
				break
			end
		end
	end
	return chosen
end

local function prepare(code: string, spec: any, delay: number): Monster?
	local k = speciesParams(spec)
	local template = findTemplate(k.TemplateName)
	local model = if template then template:Clone() else buildFallbackTemplate(k)

	local root = model.PrimaryPart or model:FindFirstChild("Root")
	if not root or not root:IsA("BasePart") then
		local only = model:FindFirstChildWhichIsA("BasePart", true)
		if only then
			root = only
		end
	end
	if not root or not root:IsA("BasePart") then
		warn("[Monstruos] " .. k.TemplateName .. " no tiene PrimaryPart/Root")
		model:Destroy()
		return nil
	end
	model.PrimaryPart = root :: BasePart

	if not k.KeepModelScale then
		local extents = model:GetExtentsSize()
		local longest = math.max(extents.X, extents.Y, extents.Z)
		if k.Length > 0 and longest > 0 then
			model:ScaleTo(model:GetScale() * k.Length / longest)
		end
	end

	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = false
			d.CanCollide = false
			d.CanTouch = false
			d.CanQuery = false
			d.Massless = true
		end
	end
	root.Anchored = true
	model.Name = k.Name
	model:SetAttribute("Species", k.Name)
	applyAtmosphereDetails(model, root :: BasePart, k)
	CollectionService:AddTag(model, "ProcCreature")

	local filter: { Instance } = { LevelState.container :: Instance }
	local runObj = workspace:FindFirstChild("RunObjectives")
	if runObj then
		table.insert(filter, runObj)
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = filter
	params.RespectCanCollide = true

	local hidden = Vector3.new(0, -2000, 0)
	model:PivotTo(CFrame.new(hidden))
	model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	model.Parent = workspace

	local m: Monster = {
		k = k,
		category = k.Category or "Aggressive",
		dead = false,
		code = code,
		model = model,
		root = root :: BasePart,
		state = "Hidden",
		stateT = 0,
		timer = k.FirstDelay + delay,
		pos = hidden,
		vel = Vector3.zero,
		dir = Vector3.new(1, 0, 0),
		path = {},
		idx = 1,
		target = nil,
		lastSeen = nil,
		lostAt = 0,
		scanAt = 0,
		repathAt = 0,
		lookAt = 0,
		attackAt = 0,
		lunDir = Vector3.xAxis,
		hitDone = false,
		searchUntil = 0,
		sniffT = 0,
		watchedT = 0,
		stalkIgnoredT = 0,
		cooldownUntil = 0,
		behavior = k.Behavior or "",
		gazeT = 0,
		awayT = 0,
		seenOnce = false,
		ambushSpot = nil,
		lastAmbushPos = nil,
		stuckPos = hidden,
		stuckAt = 0,
		pathReq = 0,
		pending = false,
		params = params,
	}
	m.model:SetAttribute("Estado", "Hidden")
	dbg("preparado " .. k.Name .. " [" .. m.category .. "] (aparece en " .. math.floor(m.timer) .. " s)")
	return m
end

-- Ruidos del mundo (generadores, cajas fuertes, puertas) atraen al Agresivo
Noise.Emitted:Connect(function(position: Vector3, radius: number, source: string)
	if #actives == 0 then
		return
	end
	dbg("ruido recibido (" .. source .. ", radio " .. math.floor(radius) .. ")")
	alertAggressives(nil, position, math.max(radius, K.AlertRadius * 0.75))
end)

RunService.Heartbeat:Connect(function(dt)
	dt = math.min(dt, 0.1)
	for i = #actives, 1, -1 do
		local m = actives[i]
		local run = Runs.Get(m.code)
		if not run or run.ended then
			m.dead = true
			m.model:Destroy()
			table.remove(actives, i)
		else
			step(m, dt)
		end
	end
end)

Players.PlayerRemoving:Connect(function(player)
	lastHit[player] = nil
end)

local function findLoadedMap(run: Runs.Run): Instance?
	local maps = workspace:FindFirstChild("Maps")
	if not maps then
		return nil
	end
	local def = Config.Run.Stages[run.zone]
	local named = def and maps:FindFirstChild(def.Map)
	if named then
		return named
	end
	return maps:FindFirstChildWhichIsA("Model")
end

Runs.StateChanged:Connect(function(code: string, state: Types.RunState)
	local run = Runs.Get(code)
	if not run then
		return
	end
	if state == "Level" then
		destroyAll()
		-- Medio segundo después: ObjectiveService ya colocó las persianas (RunObjectives) y la red de navegación las tiene en cuenta.
		task.delay(0.5, function()
			local now = Runs.Get(code)
			if not now or now.state ~= "Level" or now.ended then
				return
			end
			local map = findLoadedMap(now)
			if map then
				MapNav.Build(map)
			end
			if LevelState.nav and LevelState.container then
				for idx, spec in pickSpecies(K.PerLevel) do
					local m = prepare(code, spec, (idx - 1) * K.SpawnStagger)
					if m then
						table.insert(actives, m)
					end
				end
			end
		end)
	elseif state == "Descending" or state == "Stopover" or state == "Won" or state == "Lost" then
		destroyAll()
		MapNav.Clear()
	end
end)
