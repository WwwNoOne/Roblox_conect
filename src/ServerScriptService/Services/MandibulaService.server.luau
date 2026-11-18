--!strict
-- Mandíbulas radiales (Nivel 2): Config.Mandibula.Count criaturas que rondan todo el mapa (puntos al azar dentro de `Bounds`,
-- esquivando estructuras). Persiguen a los jugadores que vean fuera del submarino y los muerden (daño + empujón); tras morder
-- se alejan unos segundos. Más lentas que el nado del jugador. Plantilla: AbismoAssets.Creatures.Mandibula_Radial.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local KeyframeSequenceProvider = game:GetService("KeyframeSequenceProvider")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Types = require(Shared:WaitForChild("Types"))
local Runs = require(script.Parent:WaitForChild("Runs"))
local Assets = require(script.Parent:WaitForChild("Assets"))

local M = Config.Mandibula
local rng = Random.new()

type Mandibula = {
	model: Model,
	state: string, -- Roam | Chase | Recover
	pos: Vector3,
	dir: Vector3,
	avoid: Vector3?,
	avoidUntil: number,
	probeAt: number,
	target: Vector3?,
	stuckAt: number,
	lastDist: number,
	timer: number,
	chasing: Player?,
	hitAt: { [Player]: number },
	blockedSince: number,
	tracks: { [string]: AnimationTrack? },
}

type Group = {
	code: string,
	map: Instance,
	bounds: BasePart?,
	list: { Mandibula },
	params: RaycastParams,
	overlap: OverlapParams,
}

local group: Group? = nil

local function dbg(msg: string)
	if M.Debug then
		print("[Mandibula] " .. msg)
	end
end

local function playerRoot(player: Player): BasePart?
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if humanoid and humanoid.Health > 0 and root and root:IsA("BasePart") then
		return root
	end
	return nil
end

local function eligibleRoot(player: Player, g: Group): BasePart?
	local run = Runs.GetByUser(player.UserId)
	if not run or run.code ~= g.code or run.state ~= "Level" then
		return nil
	end
	if player:GetAttribute("Hidden") == true then
		return nil -- escondido en una caja: no lo ven
	end
	local root = playerRoot(player)
	if not root or Runs.IsUserInside(player.UserId) then
		return nil
	end
	return root
end

local function inBounds(g: Group, p: Vector3, margin: number): boolean
	local b = g.bounds
	if not b then
		return true
	end
	local rel = b.CFrame:PointToObjectSpace(p)
	local half = b.Size / 2 - Vector3.new(margin, margin, margin)
	return math.abs(rel.X) <= half.X and math.abs(rel.Y) <= half.Y and math.abs(rel.Z) <= half.Z
end

local function dockPos(g: Group): Vector3?
	local dock = g.map:FindFirstChild("SubDock", true)
	return if dock and dock:IsA("BasePart") then dock.Position else nil
end

-- Punto al azar dentro de Bounds, libre de estructuras. `awayFrom`: distancia mínima a ese punto.
local function pickPoint(g: Group, awayFrom: Vector3?, minDistance: number): Vector3
	local b = g.bounds
	for _ = 1, 30 do
		local p: Vector3
		if b then
			local half = b.Size / 2 - Vector3.new(M.RoamMargin, M.RoamMargin, M.RoamMargin)
			p = b.CFrame:PointToWorldSpace(Vector3.new(rng:NextNumber(-half.X, half.X), rng:NextNumber(-half.Y, half.Y), rng:NextNumber(-half.Z, half.Z)))
		else
			p = Vector3.new(rng:NextNumber(-300, 300), rng:NextNumber(-100, 100), rng:NextNumber(-300, 300))
		end
		if (not awayFrom or (p - awayFrom).Magnitude >= minDistance) and #workspace:GetPartBoundsInRadius(p, M.ProbeRadius * 2, g.overlap) == 0 then
			return p
		end
	end
	return if b then b.Position else Vector3.zero
end

local function loadTrack(c: Mandibula, name: string): AnimationTrack?
	if c.tracks[name] ~= nil then
		return c.tracks[name]
	end
	local folder = c.model:FindFirstChild("Animaciones")
	local src = folder and folder:FindFirstChild(name)
	local controller = c.model:FindFirstChildOfClass("AnimationController")
	local animator = controller and controller:FindFirstChildOfClass("Animator")
	if not src or not animator or not src:IsA("KeyframeSequence") then
		return nil
	end
	-- Solo vale en Studio; en el juego real hay que publicar la animación y poner su id en el atributo AnimationId.
	local id = src:GetAttribute("AnimationId")
	if type(id) ~= "string" or id == "" then
		local ok, reg = pcall(function()
			return KeyframeSequenceProvider:RegisterKeyframeSequence(src)
		end)
		if not ok then
			return nil
		end
		id = reg
	end
	local anim = Instance.new("Animation")
	anim.AnimationId = id :: string
	local ok, track = pcall(function()
		return animator:LoadAnimation(anim)
	end)
	c.tracks[name] = if ok then track else nil
	return c.tracks[name]
end

local function place(c: Mandibula)
	local up = if math.abs(c.dir.Y) > 0.97 then Vector3.xAxis else Vector3.yAxis
	c.model:PivotTo(CFrame.lookAt(c.pos, c.pos + c.dir, up)) -- la cabeza está en -Z
end

local function destroy()
	if group then
		for _, c in group.list do
			c.model:Destroy()
		end
		group = nil
	end
end

local function overlapsAt(g: Group, pos: Vector3): boolean
	return #workspace:GetPartBoundsInRadius(pos, M.ProbeRadius * 0.85, g.overlap) > 0
end

local function steer(g: Group, c: Mandibula, desired: Vector3, speed: number, now: number, dt: number): Vector3
	if now >= c.probeAt then
		c.probeAt = now + 0.12
		local hit = workspace:Spherecast(c.pos, M.ProbeRadius, c.dir * (M.ProbeDistance + speed), g.params)
		if hit then
			local n = hit.Normal
			local slide = desired - n * desired:Dot(n)
			local away = slide + n * 0.9
			c.avoid = if away.Magnitude > 0.01 then away.Unit else n
			c.avoidUntil = now + 0.8
		elseif now > c.avoidUntil then
			c.avoid = nil
		end
	end
	local want = if c.avoid and now < c.avoidUntil then c.avoid else desired
	local d = c.dir:Lerp(want, 1 - math.exp(-dt * M.TurnRate * (if c.avoid then 2 else 1)))
	return if d.Magnitude > 0.01 then d.Unit else want
end

local function findPrey(g: Group, c: Mandibula): Player?
	local best: Player? = nil
	local bestDist = math.huge
	for _, player in Players:GetPlayers() do
		local root = eligibleRoot(player, g)
		if root then
			local range = M.DetectRange * (if player:GetAttribute("LampOn") then M.LampDetectMultiplier else 1)
			local d = (root.Position - c.pos).Magnitude
			if d <= range and d < bestDist then
				best, bestDist = player, d
			end
		end
	end
	return best
end

local function tryBite(g: Group, c: Mandibula, now: number)
	local head = c.pos + c.dir * 6
	for _, player in Players:GetPlayers() do
		local root = eligibleRoot(player, g)
		if root and now >= (c.hitAt[player] or 0) and (root.Position - head).Magnitude <= M.BiteReach then
			c.hitAt[player] = now + M.BiteCooldown
			local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
			if humanoid then
				humanoid:TakeDamage(M.Damage)
			end
			local offset = root.Position - c.pos
			local away = if offset.Magnitude > 0.01 then offset.Unit else Vector3.yAxis
			root.AssemblyLinearVelocity = away * M.Knockback
			local attack = loadTrack(c, "Attack")
			if attack then
				attack.Looped = false
				attack:Play()
			end
			c.chasing = nil
			c.target = c.pos - away * 150
			c.timer = M.RecoverSeconds
			c.stuckAt = now + M.StuckSeconds
			c.lastDist = math.huge
			c.state = "Recover"
			return
		end
	end
end

local function step(g: Group, c: Mandibula, dt: number)
	local now = os.clock()
	local goal: Vector3
	local speed: number
	if c.state == "Chase" then
		local root = c.chasing and eligibleRoot(c.chasing, g)
		if not root or (root.Position - c.pos).Magnitude > M.DetectRange * M.LampDetectMultiplier * M.LoseRangeMultiplier then
			c.chasing = nil
			c.target = pickPoint(g, nil, 0)
			c.state = "Roam"
			return
		end
		goal, speed = root.Position, M.ChaseSpeed
	else
		if c.state == "Recover" then
			c.timer -= dt
			speed = M.RecoverSpeed
			if c.timer <= 0 then
				c.target = pickPoint(g, nil, 0)
				c.state = "Roam"
				return
			end
		else
			speed = M.RoamSpeed
			local prey = findPrey(g, c)
			if prey then
				c.chasing = prey
				c.state = "Chase"
				return
			end
		end
		local target = c.target
		if not target then
			c.target = pickPoint(g, nil, 0)
			return
		end
		local dist = (target - c.pos).Magnitude
		if dist < M.ReachDistance then
			c.target = pickPoint(g, nil, 0)
			c.stuckAt = now + M.StuckSeconds
			c.lastDist = math.huge
			return
		end
		if dist < c.lastDist - 2 then
			c.lastDist = dist
			c.stuckAt = now + M.StuckSeconds
		elseif now > c.stuckAt then
			c.target = pickPoint(g, nil, 0)
			c.stuckAt = now + M.StuckSeconds
			c.lastDist = math.huge
			return
		end
		goal = target
	end

	local to = goal - c.pos
	if to.Magnitude > 0.01 then
		c.dir = steer(g, c, to.Unit, speed, now, dt)
	end
	local nextPos = c.pos + c.dir * speed * dt
	if not inBounds(g, nextPos, 10) then
		c.target = pickPoint(g, nil, 0)
		if c.state == "Chase" then
			c.chasing = nil
			c.state = "Roam"
		end
		return
	end
	-- Colisión dura (como el kraken): no avanza si tocaría algo sólido; se desliza o, tras 1 s bloqueada, cambia de objetivo.
	if overlapsAt(g, nextPos) and not overlapsAt(g, c.pos) then
		local alt = if c.avoid then c.pos + c.avoid * speed * dt else nil
		if alt and not overlapsAt(g, alt) and inBounds(g, alt, 10) then
			nextPos = alt
			c.blockedSince = 0
		else
			nextPos = c.pos
			if c.blockedSince == 0 then
				c.blockedSince = now
			elseif now - c.blockedSince > 1 then
				c.blockedSince = 0
				c.target = pickPoint(g, nil, 0)
				c.avoid = nil
				if c.state == "Chase" then
					c.chasing = nil
					c.state = "Roam"
				end
				return
			end
		end
	else
		c.blockedSince = 0
	end
	c.pos = nextPos
	place(c)
	if c.state ~= "Recover" then
		tryBite(g, c, now)
	end
end

local function prepare(code: string, map: Instance)
	destroy()
	local template = Assets.Find("Mandibula_Radial") or workspace:FindFirstChild("Mandibula_Radial")
	if not template or not template:IsA("Model") then
		warn("[Mandibula] Falta el modelo Mandibula_Radial (AbismoAssets.Creatures)")
		return
	end
	local boundsPart = map:FindFirstChild("Bounds")
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.IgnoreWater = true
	params.RespectCanCollide = true
	local overlap = OverlapParams.new()
	overlap.FilterType = Enum.RaycastFilterType.Exclude
	overlap.RespectCanCollide = true
	local g: Group = {
		code = code,
		map = map,
		bounds = if boundsPart and boundsPart:IsA("BasePart") then boundsPart else nil,
		list = {},
		params = params,
		overlap = overlap,
	}
	local excluded: { Instance } = {}
	local dock = dockPos(g)
	for i = 1, M.Count do
		local model = template:Clone()
		local root = model.PrimaryPart or model:FindFirstChild("Root")
		if not root or not root:IsA("BasePart") then
			model:Destroy()
			break
		end
		model.PrimaryPart = root :: BasePart
		for _, d in model:GetDescendants() do
			if d:IsA("BasePart") then
				d.Anchored = true
				d.CanCollide = false
				d.CanQuery = false
				d.CanTouch = false
			end
		end
		model.Name = "MandibulaRadial" .. i
		local c: Mandibula = {
			model = model,
			state = "Roam",
			pos = pickPoint(g, dock, M.MinSpawnDistance),
			dir = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(-0.2, 0.2), rng:NextNumber(-1, 1)).Unit,
			avoid = nil,
			avoidUntil = 0,
			probeAt = 0,
			target = nil,
			stuckAt = os.clock() + M.StuckSeconds,
			lastDist = math.huge,
			timer = 0,
			chasing = nil,
			hitAt = {},
			blockedSince = 0,
			tracks = {},
		}
		c.target = pickPoint(g, nil, 0)
		place(c)
		model.Parent = workspace
		table.insert(excluded, model)
		table.insert(g.list, c)
		local swim = loadTrack(c, "Swim")
		if swim then
			swim.Looped = true
			swim:Play()
		end
	end
	params.FilterDescendantsInstances = excluded
	overlap.FilterDescendantsInstances = excluded
	group = g
	dbg(string.format("%d mandíbulas en %s", #g.list, map.Name))
end

RunService.Heartbeat:Connect(function(dt)
	local g = group
	if g then
		local run = Runs.Get(g.code)
		if not run or run.ended then
			destroy()
			return
		end
		for _, c in g.list do
			step(g, c, dt)
		end
	end
end)

local function mapNamed(name: string): Instance?
	local maps = workspace:FindFirstChild("Maps")
	local stored = game:GetService("ServerStorage"):FindFirstChild("MapStorage")
	return (maps and maps:FindFirstChild(name)) or (stored and stored:FindFirstChild(name))
end

Runs.StateChanged:Connect(function(code: string, state: Types.RunState)
	local run = Runs.Get(code)
	if not run then
		return
	end
	if state == "Level" then
		local def = Config.Run.Stages[run.zone]
		local map = def and def.Mandibula and mapNamed(def.Map)
		if map then
			if not group or group.code ~= code then
				prepare(code, map)
			end
		else
			destroy()
		end
	elseif state == "Descending" or state == "Stopover" or state == "Won" or state == "Lost" then
		destroy()
	end
end)
