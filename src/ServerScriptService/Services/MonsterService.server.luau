--!strict
-- Enemigos agresivos del laberinto (Pez Pelícano y las especies de Config.Monster.Species; salen Config.Monster.PerLevel por nivel). Patrulla siguiendo la red de pasillos (LevelState.nav, que genera
-- MazeGenerator.NavGraph) y, en cuanto te detecta (vista con línea de visión, oído a corta distancia), corre hacia ti por la red y
-- muerde. No ve a quien está escondido (atributo Hidden) salvo muy cerca, ni a quien está dentro del submarino o fuera del laberinto.
-- Se mueve de forma cinemática (sin colisión): el cuerpo es rígido y puede cortar esquinas. Parámetros: Config.Monster.
-- Plantilla: Workspace.Creatures.Pez_Pelicano_Abisal (LevelService la mueve a ServerStorage.Plantillas.Creatures al arrancar).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local KeyframeSequenceProvider = game:GetService("KeyframeSequenceProvider")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Types = require(Shared:WaitForChild("Types"))
local Runs = require(script.Parent:WaitForChild("Runs"))
local Assets = require(script.Parent:WaitForChild("Assets"))
local LevelState = require(script.Parent:WaitForChild("LevelState"))

local K = Config.Monster
local rng = Random.new()
local CollectionService = game:GetService("CollectionService")
local Sfx = require(Shared:WaitForChild("Sfx"))

type Monster = {
	k: any, -- parámetros de la especie (Config.Monster con lo de Config.Monster.Species[i] encima)
	dead: boolean,
	model: Model,
	root: BasePart,
	state: string, -- Hidden | Patrol | Chase | Search
	armed: boolean,
	timer: number,
	pos: Vector3,
	dir: Vector3,
	path: { Vector3 },
	idx: number,
	target: Player?,
	lastSeen: Vector3?,
	lostAt: number,
	scanAt: number,
	repathAt: number,
	attackAt: number,
	code: string,
	tracks: { [string]: AnimationTrack? },
	anim: string?,
	params: RaycastParams,
}

local actives: { Monster } = {}

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

-- ===== Animaciones (KeyframeSequences guardadas en AnimSaves) =====
local function loadTrack(m: Monster, name: string): AnimationTrack?
	if m.tracks[name] ~= nil then
		return m.tracks[name]
	end
	local saves = m.model:FindFirstChild("AnimSaves") or m.model:FindFirstChild("Animaciones")
	local src = saves and saves:FindFirstChild(name)
	local controller = m.model:FindFirstChildOfClass("AnimationController")
	local animator = controller and controller:FindFirstChildOfClass("Animator")
	if not src or not src:IsA("KeyframeSequence") or not animator then
		m.tracks[name] = false :: any
		return nil
	end
	-- Solo vale en Studio; en el juego real hay que publicar la animación y poner su id en el atributo AnimationId.
	local id = src:GetAttribute("AnimationId")
	if type(id) ~= "string" or id == "" then
		local ok, reg = pcall(function()
			return KeyframeSequenceProvider:RegisterKeyframeSequence(src)
		end)
		if not ok then
			m.tracks[name] = false :: any
			return nil
		end
		id = reg
	end
	local anim = Instance.new("Animation")
	anim.AnimationId = id :: string
	local ok, track = pcall(function()
		return animator:LoadAnimation(anim)
	end)
	if ok and track then
		m.tracks[name] = track
		return track
	end
	m.tracks[name] = false :: any
	return nil
end

local function play(m: Monster, name: string, looped: boolean)
	if m.anim == name then
		return
	end
	local track = loadTrack(m, name)
	if not track then
		return
	end
	for other, t in m.tracks do
		if t and other ~= name and t.IsPlaying and other:sub(1, 6) ~= "Ataque" then
			t:Stop(0.2)
		end
	end
	track.Looped = looped
	track:Play(0.2)
	m.anim = name
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
	local from = nearestVertex(nav, m.pos, m.dir)
	local to = nearestVertex(nav, targetPos, nil)
	m.path = shortestPath(nav, from, to)
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

-- Jugador de esta partida, vivo, fuera del submarino y dentro del laberinto.
local function eligibleRoot(player: Player, m: Monster): BasePart?
	local run = Runs.GetByUser(player.UserId)
	if not run or run.code ~= m.code or run.state ~= "Level" then
		return nil
	end
	local root = playerRoot(player)
	if not root or Runs.IsUserInside(player.UserId) or not inMaze(root.Position) then
		return nil
	end
	return root
end

local function headPos(m: Monster): Vector3
	return m.pos + m.dir * (m.k.HeadOffset or 4)
end

local function hasLineOfSight(m: Monster, target: BasePart): boolean
	local from = headPos(m)
	local result = workspace:Raycast(from, target.Position - from, m.params)
	return result == nil
end

-- Mejor jugador detectado: vista (con línea de visión) u oído; escondido solo se detecta muy cerca.
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
				seen = d <= m.k.HearRange or (d <= sight and hasLineOfSight(m, root))
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

-- Avanza hacia el siguiente punto del camino; devuelve true si llegó al final.
local function follow(m: Monster, speed: number, dt: number): boolean
	local target = m.path[m.idx]
	if not target then
		return true
	end
	local to = target - m.pos
	local dist = to.Magnitude
	if dist < 1.2 then
		m.idx += 1
		return m.idx > #m.path
	end
	local desired = to.Unit
	m.dir = m.dir:Lerp(desired, 1 - math.exp(-m.k.TurnRate * dt))
	if m.dir.Magnitude < 0.01 then
		m.dir = desired
	end
	m.dir = m.dir.Unit
	m.pos += m.dir * math.min(dist, speed * dt)
	place(m)
	return false
end

local function chooseAnim(m: Monster, base: string)
	if m.dir.Y > 0.6 then
		play(m, "Nado_Vertical_Ascenso", true)
	elseif m.dir.Y < -0.6 then
		play(m, "Nado_Vertical_Descenso", true)
	else
		play(m, base, true)
	end
end

local function pickPatrolTarget(m: Monster)
	local nav = LevelState.nav
	if not nav then
		return
	end
	for _ = 1, 12 do
		local p = nav.points[rng:NextInteger(1, #nav.points)]
		if (p - m.pos).Magnitude > 60 then
			setPath(m, p)
			return
		end
	end
	setPath(m, nav.points[rng:NextInteger(1, #nav.points)])
end

local function attack(m: Monster, player: Player, root: BasePart, now: number)
	m.attackAt = now + m.k.AttackCooldown
	local dy = root.Position.Y - m.pos.Y
	local name = if dy > 3 then "Ataque_Vertical_Ascenso" elseif dy < -3 then "Ataque_Vertical_Descenso" else "Ataque_Horizontal"
	local track = loadTrack(m, name)
	if track then
		track.Looped = false
		track:Play(0.1)
	end
	task.delay(0.45, function()
		if m.dead or not m.model.Parent then
			return
		end
		local r = eligibleRoot(player, m)
		if r and (r.Position - headPos(m)).Magnitude <= m.k.AttackReach * 1.6 and player:GetAttribute("Hidden") ~= true then
			local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
			if humanoid then
				humanoid:TakeDamage(m.k.AttackDamage)
			end
		end
	end)
end

local function step(m: Monster, dt: number)
	local now = os.clock()
	if m.state == "Hidden" then
		if not m.armed then
			return
		end
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
				if (p - entry).Magnitude >= m.k.MinSpawnDistance then
					spawn = p
					break
				end
			end
			m.pos = spawn
			m.dir = Vector3.new(1, 0, 0)
			place(m)
			m.state = "Patrol"
			pickPatrolTarget(m)
			dbg("aparece en patrulla")
		end
		return
	end

	-- detección periódica
	if now >= m.scanAt then
		m.scanAt = now + 0.2
		local player, root = detect(m)
		if player and root then
			if m.state ~= "Chase" then
				dbg("detecta a " .. player.Name .. ": corre hacia el")
			end
			m.state, m.target, m.lastSeen, m.lostAt = "Chase", player, root.Position, now
		elseif m.state == "Chase" and now - m.lostAt > m.k.LoseSeconds then
			m.state = "Search"
			m.target = nil
			if m.lastSeen then
				setPath(m, m.lastSeen)
			end
			dbg("pierde el rastro: busca")
		end
	end

	if m.state == "Chase" then
		local player = m.target
		local root = player and eligibleRoot(player, m)
		if not player or not root then
			m.state = "Search"
			m.target = nil
			return
		end
		if now - m.lostAt < 0.3 or hasLineOfSight(m, root) then
			m.lastSeen = root.Position
			m.lostAt = if hasLineOfSight(m, root) or (root.Position - m.pos).Magnitude <= m.k.HearRange then now else m.lostAt
		end
		local head = headPos(m)
		local dist = (root.Position - head).Magnitude
		if dist <= m.k.AttackReach and now >= m.attackAt and player:GetAttribute("Hidden") ~= true then
			attack(m, player, root, now)
		end
		if hasLineOfSight(m, root) and dist < 40 then
			-- a la vista y cerca: va directo hacia el jugador
			m.path = { root.Position }
			m.idx = 1
		elseif now >= m.repathAt then
			m.repathAt = now + 0.35
			setPath(m, root.Position)
		end
		chooseAnim(m, "Nado_Horizontal")
		follow(m, m.k.ChaseSpeed, dt)
	elseif m.state == "Search" then
		chooseAnim(m, "Nado_Horizontal")
		if follow(m, m.k.PatrolSpeed * 1.6, dt) then
			m.state = "Patrol"
			pickPatrolTarget(m)
		end
	else
		chooseAnim(m, "Patrullaje")
		if follow(m, m.k.PatrolSpeed, dt) then
			pickPatrolTarget(m)
		end
	end
	if K.Debug then
		m.model:SetAttribute("Estado", m.state)
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
	-- La raíz anclada mueve todo el rig; el resto queda sin anclar para que las animaciones (Motor6D) se apliquen.
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
	if k.ProcAnim then
		model:SetAttribute("ProcAnim", k.ProcAnim)
		CollectionService:AddTag(model, "ProcCreature")
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { model }
	params.RespectCanCollide = true
	params.IgnoreWater = true
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
		armed = true,
		timer = k.FirstDelay + delay,
		pos = hidden,
		dir = Vector3.new(1, 0, 0),
		path = {},
		idx = 1,
		target = nil,
		lastSeen = nil,
		lostAt = 0,
		scanAt = 0,
		repathAt = 0,
		attackAt = 0,
		tracks = {},
		anim = nil,
		params = params,
	}
	dbg("preparado " .. k.Name .. " (aparece en " .. math.floor(m.timer) .. " s)")
	return m
end

RunService.Heartbeat:Connect(function(dt)
	for i = #actives, 1, -1 do
		local m = actives[i]
		local run = Runs.Get(m.code)
		if not run or run.ended then
			m.dead = true
			m.model:Destroy()
			table.remove(actives, i)
		else
			local wasChasing = m.state == "Chase"
			step(m, dt)
			if m.state == "Chase" and not wasChasing and m.k.Roar then
				Sfx.Play(m.k.Roar, m.root, 1, 160) -- rugido al detectarte
			end
		end
	end
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
