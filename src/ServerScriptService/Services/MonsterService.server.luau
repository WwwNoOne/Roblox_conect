--!strict
-- Enemigos agresivos del laberinto (especies de Config.Monster.Species; salen Config.Monster.PerLevel por nivel). Patrullan siguiendo
-- la red de pasillos (LevelState.nav, que genera MazeGenerator.NavGraph) y, en cuanto te detectan (vista con línea de visión, oído),
-- te persiguen, te cortan el paso adelantándose a tu movimiento y te atacan con un zarpazo en tres fases: preparación (se frena y te
-- encara, avisando), embestida (se lanza con velocidad extra y daña a quien toque su cuerpo) y recuperación (queda vulnerable un
-- instante). Si te pierden, rastrean la zona del último punto visto antes de volver a patrullar, y avisan a los otros enemigos cercanos.
-- No ven a quien está escondido (atributo Hidden) salvo pegados a su caja: si se quedan ahí olisqueando DiscoverSeconds lo descubren (lo sacan
-- de la caja); si no, pierden el rastro a los HiddenLoseSeconds, rastrean la zona y se marchan lejos. Tampoco ven a quien está dentro del
-- ascensor, a salvo en la sala_0 (SafeZone: tampoco pueden entrar ahí) ni fuera del laberinto.
-- Se mueven con velocidad y aceleración propias y chocan contra las paredes del laberinto (esferas de colisión): se deslizan en vez
-- de atravesarlas. Parámetros: Config.Monster. Plantillas: ServerStorage.GameAssets.Creatures (o Workspace.Creatures).
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
local Hiding = require(script.Parent:WaitForChild("Hiding"))
local SafeZone = require(script.Parent:WaitForChild("SafeZone"))

local playerHit = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("PlayerHit") :: RemoteEvent

local K = Config.Monster
local rng = Random.new()

-- Hidden (aún no sale) | Patrol | Investigate (va a donde oyó/vio a alguien) | Chase | Windup | Lunge | Recover | Search
type Monster = {
	k: any, -- parámetros de la especie (Config.Monster con lo de Config.Monster.Species[i] encima)
	dead: boolean,
	model: Model,
	root: BasePart,
	state: string,
	stateT: number, -- segundos que lleva en el estado actual
	timer: number, -- cuenta atrás de aparición
	pos: Vector3,
	vel: Vector3,
	dir: Vector3, -- hacia dónde mira (la cabeza apunta a -Z del pivote)
	path: { Vector3 },
	idx: number,
	target: Player?,
	lastSeen: Vector3?,
	lostAt: number,
	scanAt: number,
	repathAt: number,
	lookAt: number, -- próximo recorte de camino
	attackAt: number, -- no ataca antes de este instante
	lunDir: Vector3,
	hitDone: boolean,
	searchUntil: number,
	sniffT: number, -- segundos pegado a la caja donde se esconde el jugador (al llegar a DiscoverSeconds lo descubre)
	stuckPos: Vector3,
	stuckAt: number,
	code: string,
	params: RaycastParams, -- solo el laberinto: línea de visión y colisión
}

local actives: { Monster } = {}
local lastHit: { [Player]: number } = {}

local function dbg(msg: string)
	if K.Debug then
		print("[Monstruos] " .. msg)
	end
end

-- ===== Plantilla =====
local function findTemplate(name: string): Model?
	local store = ServerStorage:FindFirstChild("Plantillas")
	for _, root in { store, workspace:FindFirstChild("Creatures") } do
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

-- ===== Red de navegación =====
local function nearestVertex(nav: any, pos: Vector3, ahead: Vector3?): number
	local best, bestScore = 1, math.huge
	for i, p in nav.points do
		local d = (p - pos).Magnitude
		local score = d
		if ahead and d > 1.5 and (p - pos).Unit:Dot(ahead) < 0 then
			score += 30 -- prefiere los vértices por delante (evita volver atrás)
		end
		if score < bestScore then
			best, bestScore = i, score
		end
	end
	return best
end

-- Camino más corto (Dijkstra) entre dos vértices; devuelve la lista de posiciones.
local function shortestPath(nav: any, from: number, to: number): { Vector3 }
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

local function setPath(m: Monster, targetPos: Vector3)
	local nav = LevelState.nav
	if not nav then
		return
	end
	-- desde el vértice más cercano por delante (si ya hay camino y el actual sigue siendo bueno no cambia de sentido)
	local from = nearestVertex(nav, m.pos, m.dir)
	local to = nearestVertex(nav, targetPos, nil)
	local full = shortestPath(nav, from, to)
	-- el camino se corta antes de entrar en la zona vetada (sala_0 y tramo del pozo)
	local path: { Vector3 } = {}
	for _, p in full do
		if SafeZone.BarsMonster(p) then
			break
		end
		table.insert(path, p)
	end
	m.path = path
	m.idx = 1
end

-- ===== Jugadores =====
local function inMaze(pos: Vector3): boolean
	local c = LevelState.container
	local b = c and c:FindFirstChild("Bounds")
	if not b or not b:IsA("BasePart") then
		return false
	end
	local rel = pos - b.Position
	local h = b.Size / 2 + Vector3.new(6, 6, 6)
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

-- Jugador de esta partida, vivo, fuera del ascensor y dentro del laberinto.
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

local function headPos(m: Monster): Vector3
	return m.pos + m.dir * (m.k.HeadOffset or m.k.Length * 0.45)
end

-- Distancia de un punto al cuerpo del monstruo (segmento cola-cabeza).
local function bodyDistance(m: Monster, point: Vector3): number
	local head = headPos(m)
	local tail = m.pos - m.dir * (m.k.Length * 0.45)
	local seg = head - tail
	local t = math.clamp((point - tail):Dot(seg) / math.max(seg:Dot(seg), 1e-3), 0, 1)
	return (point - (tail + seg * t)).Magnitude
end

-- Hay paso libre (para un cuerpo de radio `radius`) entre dos puntos del laberinto.
local function clearBetween(m: Monster, a: Vector3, b: Vector3, radius: number): boolean
	local d = b - a
	if d.Magnitude < 0.5 then
		return true
	end
	return workspace:Spherecast(a, radius, d, m.params) == nil
end

-- Línea de visión de la cabeza al jugador: el filtro solo incluye el laberinto, así que ni el propio personaje ni otros
-- monstruos tapan la vista.
local function hasLineOfSight(m: Monster, target: BasePart): boolean
	local from = headPos(m)
	return workspace:Raycast(from, target.Position - from, m.params) == nil
end

-- Mejor jugador detectado: vista (con línea de visión) u oído (más lejos si va corriendo); escondido solo se detecta muy cerca.
local function detect(m: Monster): (Player?, BasePart?)
	local best: Player? = nil
	local bestRoot: BasePart? = nil
	local bestDist = math.huge
	for _, player in Players:GetPlayers() do
		local root = eligibleRoot(player, m)
		if root then
			local d = (root.Position - m.pos).Magnitude
			local seen = false
			if player:GetAttribute("Hidden") == true then
				seen = d <= m.k.HiddenRange
			else
				local sight = m.k.SightRange * (if player:GetAttribute("LampOn") then m.k.LampSightMultiplier else 1)
				local noisy = player:GetAttribute("Sprinting") == true -- correr hace ruido
				local hear = if noisy then m.k.NoiseRange else m.k.HearRange
				if not noisy and player:GetAttribute("Crouching") == true then
					hear *= Config.Movement.CrouchHearFactor -- agachado se hace menos ruido
				end
				seen = d <= hear or (d <= sight and hasLineOfSight(m, root))
			end
			if seen and d < bestDist then
				best, bestRoot, bestDist = player, root, d
			end
		end
	end
	return best, bestRoot
end

-- ===== Movimiento =====
local function place(m: Monster)
	if m.k.Upright then
		-- siempre erguida (medusa): solo gira en horizontal
		local flat = Vector3.new(m.dir.X, 0, m.dir.Z)
		local look = if flat.Magnitude > 0.05 then flat.Unit else (m.model:GetPivot().LookVector * Vector3.new(1, 0, 1))
		if look.Magnitude < 0.05 then
			look = Vector3.xAxis
		end
		m.model:PivotTo(CFrame.lookAt(m.pos, m.pos + look.Unit, Vector3.yAxis))
		return
	end
	local up = if math.abs(m.dir.Y) > 0.9 then Vector3.xAxis else Vector3.yAxis
	m.model:PivotTo(CFrame.lookAt(m.pos, m.pos + m.dir, up)) -- la cabeza apunta a -Z del pivote
end

local function turnToward(m: Monster, desired: Vector3, rate: number, dt: number)
	if desired.Magnitude < 0.01 then
		return
	end
	local d = m.dir:Lerp(desired.Unit, 1 - math.exp(-rate * dt))
	m.dir = if d.Magnitude < 0.01 then desired.Unit else d.Unit
end

-- Mueve con colisión contra el laberinto: si la esfera del cuerpo choca, se desliza por la pared. Devuelve true si chocó.
local function advance(m: Monster, dt: number): boolean
	local delta = m.vel * dt
	local dist = delta.Magnitude
	if dist < 1e-4 then
		return false
	end
	if SafeZone.BarsMonster(m.pos + delta) then
		m.vel = Vector3.zero -- la sala_0 es zona segura: no entran
		return true
	end
	local blocked = false
	local hit = workspace:Spherecast(m.pos, m.k.BodyRadius, delta.Unit * (dist + 0.4), m.params)
	if hit then
		blocked = true
		local n = hit.Normal
		m.vel -= n * m.vel:Dot(n) -- se desliza
		delta = m.vel * dt
		-- si seguía metido en la pared, sale despacio
		if hit.Distance < 0.05 then
			delta += n * math.min(dt * 6, 0.4)
		end
	end
	m.pos += delta
	return blocked
end

-- Acelera hacia `desiredVel` y avanza.
local function drive(m: Monster, desiredVel: Vector3, accel: number, dt: number): boolean
	local diff = desiredVel - m.vel
	local mag = diff.Magnitude
	local maxStep = accel * dt
	m.vel = if mag <= maxStep then desiredVel else m.vel + diff * (maxStep / mag)
	local blocked = advance(m, dt)
	if m.vel.Magnitude > 1.5 then
		turnToward(m, m.vel, m.k.TurnRate, dt)
	end
	place(m)
	return blocked
end

-- Punto del camino a `look` studs por delante de la posición, siguiendo los tramos desde el vértice actual.
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

-- Sigue el camino de vértices; recorta esquinas saltando a un punto posterior si hay paso libre. Devuelve true al llegar al final.
local function follow(m: Monster, speed: number, dt: number, now: number): boolean
	if #m.path == 0 then
		return true
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
	-- frena al acercarse al último punto para no pasarse
	local v = speed
	if m.idx >= #m.path then
		v = math.min(speed, math.max(4, dist * 2))
	end
	-- apunta a un punto por delante en el camino (no al siguiente vértice): las curvas salen suaves en vez de en zigzag
	local heading = to
	local look = math.clamp(speed * m.k.Carrot, 6, 16)
	local c = carrotPoint(m, look)
	if (c - m.pos).Magnitude > 0.5 and clearBetween(m, m.pos, c, radius) then
		heading = c - m.pos
	end
	drive(m, heading.Unit * v, m.k.Accel, dt)
	return false
end

-- Nuevo destino de patrulla: lejos del monstruo y, si se da `avoid`, también lejos de ese punto (p. ej. la caja donde se escondió el
-- jugador: así el enemigo se marcha de verdad en vez de volver al mismo sitio).
local function pickPatrolTarget(m: Monster, avoid: Vector3?)
	local nav = LevelState.nav
	if not nav then
		return
	end
	for _ = 1, 20 do
		local p = nav.points[rng:NextInteger(1, #nav.points)]
		if (p - m.pos).Magnitude > 60 and not SafeZone.BarsMonster(p) and (not avoid or (p - avoid).Magnitude >= m.k.AvoidRadius) then
			setPath(m, p)
			return
		end
	end
	setPath(m, nav.points[rng:NextInteger(1, #nav.points)])
end

-- Punto al azar de la red cerca de `around` (rastreo tras perder al jugador).
local function pickNear(m: Monster, around: Vector3)
	local nav = LevelState.nav
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

-- ===== Ataque =====
local function damagePlayer(player: Player, amount: number)
	local now = os.clock()
	if (lastHit[player] or 0) + K.HitGap > now then
		return
	end
	lastHit[player] = now
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid:TakeDamage(amount)
		playerHit:FireClient(player, amount) -- impacto y temblor de cámara (CameraFxClient)
	end
end

local function setState(m: Monster, state: string)
	m.state = state
	m.stateT = 0
	m.model:SetAttribute("Estado", state)
	m.model:SetAttribute("Atacando", state == "Windup" or state == "Lunge")
end

local function isAggressive(state: string): boolean
	return state == "Chase" or state == "Windup" or state == "Lunge" or state == "Recover"
end

-- Avisa a los demás enemigos cercanos del último punto donde se vio a alguien.
local function alertOthers(m: Monster, pos: Vector3)
	for _, o in actives do
		if o ~= m and not o.dead and (o.state == "Patrol" or o.state == "Search") and (o.pos - m.pos).Magnitude <= m.k.AlertRadius then
			o.lastSeen = pos
			setState(o, "Investigate")
			setPath(o, pos)
			dbg(o.model.Name .. " acude al aviso")
		end
	end
end

-- Fases del zarpazo. Windup: se frena y te encara. Lunge: se lanza y daña a quien toque su cuerpo. Recover: queda lento.
local function attackStep(m: Monster, dt: number, now: number)
	m.stateT += dt
	local player = m.target
	local root = player and eligibleRoot(player, m)
	if m.state == "Windup" then
		if not player or not root or player:GetAttribute("Hidden") == true then
			-- se perdió al objetivo (o se escondió a tiempo): a rastrear donde estaba
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
			m.lunDir = if aim.Magnitude > 0.1 then aim.Unit else m.dir
			m.hitDone = false
			setState(m, "Lunge")
		end
	elseif m.state == "Lunge" then
		if root then
			-- ligera persecución durante el lanzamiento (no esquivable al instante)
			local want = root.Position - headPos(m)
			if want.Magnitude > 0.1 then
				m.lunDir = m.lunDir:Lerp(want.Unit, math.min(1, dt * 3)).Unit
			end
		end
		turnToward(m, m.lunDir, m.k.TurnRate * 2, dt)
		m.vel = m.lunDir * m.k.LungeSpeed
		local blocked = advance(m, dt)
		place(m)
		-- daño a quien toque el cuerpo (una vez por embestida)
		if not m.hitDone then
			for _, p in Players:GetPlayers() do
				local r = eligibleRoot(p, m)
				if r and p:GetAttribute("Hidden") ~= true and bodyDistance(m, r.Position) <= m.k.HitRadius then
					damagePlayer(p, m.k.AttackDamage)
					m.hitDone = true
				end
			end
		end
		if m.stateT >= m.k.LungeSeconds or blocked or m.hitDone then
			m.attackAt = now + m.k.AttackCooldown
			setState(m, "Recover")
		end
	else -- Recover
		drive(m, m.dir * m.k.ChaseSpeed * 0.25, m.k.Brake, dt)
		if m.stateT >= m.k.RecoverSeconds then
			m.lostAt = now
			setState(m, "Chase")
		end
	end
end

-- ===== Lógica principal =====
local function step(m: Monster, dt: number)
	local now = os.clock()
	m.stateT += if m.state == "Windup" or m.state == "Lunge" or m.state == "Recover" then 0 else dt
	if m.state == "Hidden" then
		m.timer -= dt
		if m.timer <= 0 then
			local nav = LevelState.nav
			local entry = LevelState.entry
			if not nav or not entry then
				return
			end
			-- aparece en un vértice lejos del pozo
			local spawn = nav.points[1]
			for _ = 1, 40 do
				local p = nav.points[rng:NextInteger(1, #nav.points)]
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
			setState(m, "Patrol")
			pickPatrolTarget(m)
			dbg(m.model.Name .. " aparece en patrulla")
		end
		return
	end

	if m.state == "Windup" or m.state == "Lunge" or m.state == "Recover" then
		attackStep(m, dt, now)
		return
	end

	-- detección periódica
	if now >= m.scanAt then
		m.scanAt = now + 0.2
		local player, root = detect(m)
		if player and root then
			if m.state ~= "Chase" then
				dbg(m.model.Name .. " detecta a " .. player.Name)
				alertOthers(m, root.Position)
				setState(m, "Chase")
				m.attackAt = math.max(m.attackAt, now + 0.3)
				if m.k.Roar then
					Sfx.Play(m.k.Roar, m.root, 1, 160) -- rugido al detectarte
				end
			end
			m.target, m.lastSeen, m.lostAt = player, root.Position, now
		elseif m.state == "Chase" and now - m.lostAt > (if m.target and m.target:GetAttribute("Hidden") == true then m.k.HiddenLoseSeconds else m.k.LoseSeconds) then
			setState(m, "Search")
			m.target = nil
			m.searchUntil = now + m.k.SearchSeconds
			if m.lastSeen then
				setPath(m, m.lastSeen)
			end
			dbg(m.model.Name .. " pierde el rastro: rastrea")
		end
	end

	-- se atasca: sin avanzar este tiempo = recalcula el camino
	if now - m.stuckAt >= m.k.StuckSeconds then
		if (m.pos - m.stuckPos).Magnitude < 2 then
			if m.state == "Patrol" or m.state == "Search" then
				pickPatrolTarget(m)
			end
			m.repathAt = 0
			m.vel = Vector3.zero
		end
		m.stuckPos, m.stuckAt = m.pos, now
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
		local head = headPos(m)
		local hiding = player:GetAttribute("Hidden") == true
		local away = (root.Position - m.pos).Magnitude
		local sees = not hiding and hasLineOfSight(m, root)
		if hiding then
			-- escondido: solo lo delata estar pegado a la caja. Si el enemigo se queda ahí olisqueando, termina por descubrirlo
			-- (lo saca de la caja); si no, se le acaba el rastro (HiddenLoseSeconds) y se marcha.
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
		local dist = (root.Position - head).Magnitude
		-- ¿a tiro? Prepara el zarpazo (solo con paso libre hasta el jugador y fuera del enfriamiento)
		if sees and dist <= m.k.AttackStart and now >= m.attackAt then
			setState(m, "Windup")
			return
		end
		-- se anticipa: apunta a donde estará el jugador, no a donde está
		local aim = root.Position
		if sees then
			local lead = math.min(dist / math.max(m.k.ChaseSpeed, 1), m.k.LeadSeconds)
			aim = root.Position + root.AssemblyLinearVelocity * lead
			if not clearBetween(m, m.pos, aim, m.k.BodyRadius * 0.9) then
				aim = root.Position
			end
		end
		if sees and clearBetween(m, m.pos, aim, m.k.BodyRadius * 0.9) then
			-- a la vista: va directo
			m.path = { aim }
			m.idx = 1
		elseif now >= m.repathAt then
			m.repathAt = now + 0.35
			setPath(m, root.Position)
		end
		-- frenesí: cuanto más rato persigue sin parar, más rápido (hasta +FrenzyBonus)
		local frenzy = 1 + m.k.FrenzyBonus * math.clamp(m.stateT / m.k.FrenzySeconds, 0, 1)
		if follow(m, m.k.ChaseSpeed * frenzy, dt, now) then
			m.path = {}
		end
	elseif m.state == "Investigate" then
		if follow(m, m.k.ChaseSpeed * 0.75, dt, now) then
			setState(m, "Search")
			m.searchUntil = now + m.k.SearchSeconds
		end
	elseif m.state == "Search" then
		if now >= m.searchUntil then
			setState(m, "Patrol")
			pickPatrolTarget(m, m.lastSeen) -- se marcha lejos de donde perdió al jugador
		elseif follow(m, m.k.PatrolSpeed * m.k.SearchSpeedMul, dt, now) then
			pickNear(m, m.lastSeen or m.pos)
		end
	else
		if follow(m, m.k.PatrolSpeed, dt, now) then
			pickPatrolTarget(m)
		end
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

-- Parámetros de una especie: los de Config.Monster con los de la especie encima.
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

-- Elige `n` especies distintas al azar según Weight, solo entre las que tienen plantilla.
local function pickSpecies(n: number): { any }
	local pool = {}
	for _, spec in K.Species do
		if findTemplate(spec.TemplateName) then
			table.insert(pool, spec)
		else
			dbg("sin plantilla: " .. spec.TemplateName)
		end
	end
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
	if not template then
		warn("[Monstruos] Falta el modelo " .. k.TemplateName)
		return nil
	end
	local model = template:Clone()
	local root = model.PrimaryPart or model:FindFirstChild("Root")
	if not root or not root:IsA("BasePart") then
		-- Plantillas de un solo MeshPart (ForgeGUI): esa malla es la raíz.
		local only = model:FindFirstChildWhichIsA("BasePart", true)
		if only and #model:GetDescendants() > 0 then
			root = only
		end
	end
	if not root or not root:IsA("BasePart") then
		warn("[Monstruos] " .. k.TemplateName .. " no tiene PrimaryPart/Root")
		model:Destroy()
		return nil
	end
	model.PrimaryPart = root :: BasePart
	local extents = model:GetExtentsSize()
	local longest = math.max(extents.X, extents.Y, extents.Z)
	if k.Length > 0 and longest > 0 then
		model:ScaleTo(model:GetScale() * k.Length / longest)
	end
	-- La raíz anclada mueve todo el modelo; sin colisión propia (la colisión con el laberinto la calcula el servicio).
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
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { LevelState.container :: Instance }
	params.RespectCanCollide = true
	local hidden = Vector3.new(0, -2000, 0)
	model:PivotTo(CFrame.new(hidden))
	model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	model.Parent = workspace
	local m: Monster = {
		k = k,
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
		stuckPos = hidden,
		stuckAt = 0,
		params = params,
	}
	m.model:SetAttribute("Estado", "Hidden")
	dbg("preparado " .. k.Name .. " (aparece en " .. math.floor(m.timer) .. " s)")
	return m
end

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

Runs.StateChanged:Connect(function(code: string, state: Types.RunState)
	local run = Runs.Get(code)
	if not run then
		return
	end
	if state == "Level" then
		destroyAll()
		if LevelState.nav and LevelState.container then
			for idx, spec in pickSpecies(K.PerLevel) do
				local m = prepare(code, spec, (idx - 1) * K.SpawnStagger)
				if m then
					table.insert(actives, m)
				end
			end
		end
	elseif state == "Descending" or state == "Stopover" or state == "Won" or state == "Lost" then
		destroyAll()
	end
end)
