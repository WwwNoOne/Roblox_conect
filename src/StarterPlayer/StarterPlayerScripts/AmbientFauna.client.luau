--!strict
-- Fauna ambiental pacífica, solo en el cliente (no gasta red ni afecta a la partida).
--  * Gigantes (manta, nautilo): cruzan lejos y por debajo de la zona jugable por rutas fijas, como siluetas en la niebla.
--  * Peces: cardúmenes que nadan cerca del jugador y se retiran al alejarse.
-- Plantillas: ReplicatedStorage.AmbientFauna. Rutas: Workspace.Maps.<Nivel>.AmbientRoutes.<Ruta>.P01, P02...
-- Parámetros: Config.Ambient.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local KeyframeSequenceProvider = game:GetService("KeyframeSequenceProvider")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local A = Config.Ambient
local player = Players.LocalPlayer
local templates = ReplicatedStorage:WaitForChild("AmbientFauna", 30)
if not templates then
	return
end

local live = Instance.new("Folder")
live.Name = "AmbientFaunaLive"
live.Parent = workspace

local rng = Random.new()
local idCache: { [string]: string } = {}

-- Los modelos importados tienen el pivote girado respecto a la malla (ejes de Blender): se coloca la malla
-- (PrimaryPart) directamente para que el frente sea -Z y el arriba +Y, igual que en los huesos.
local function setCF(model: Model, cf: CFrame)
	local pp = model.PrimaryPart
	if pp then
		pp.CFrame = cf
	else
		model:PivotTo(cf)
	end
end

local function getCF(model: Model): CFrame
	local pp = model.PrimaryPart
	return if pp then pp.CFrame else model:GetPivot()
end

-- ===== Animación =====
-- Si el KeyframeSequence tiene el atributo AnimationId (rbxassetid://...) se usa la animación publicada.
-- Si no, se registra al vuelo (solo vale dentro de Studio hasta que se publiquen las animaciones).
local function playClip(model: Model, clip: string, template: Model)
	local controller = model:FindFirstChildWhichIsA("AnimationController", true)
	local folder = model:FindFirstChild("Animaciones")
	local seq = folder and folder:FindFirstChild(clip)
	if not controller or not seq or not seq:IsA("KeyframeSequence") then
		return
	end
	local animator = controller:FindFirstChildOfClass("Animator") or Instance.new("Animator", controller)
	local key = template.Name .. "/" .. clip
	local id = idCache[key]
	if not id then
		local published = seq:GetAttribute("AnimationId")
		if type(published) == "string" and published ~= "" then
			id = published
		else
			local ok, registered = pcall(function()
				return KeyframeSequenceProvider:RegisterKeyframeSequence(seq)
			end)
			if not ok then
				return
			end
			id = registered
		end
		idCache[key] = id
	end
	local anim = Instance.new("Animation")
	anim.AnimationId = id
	local ok, track = pcall(function()
		return animator:LoadAnimation(anim)
	end)
	if ok and track then
		track.Looped = true
		track:Play(0)
		track.TimePosition = rng:NextNumber(0, math.max(0.1, track.Length)) -- que no muevan la cola al unísono
	end
end

-- ===== Mapa activo =====
local function currentMap(root: BasePart): Instance?
	local maps = workspace:FindFirstChild("Maps")
	if not maps then
		return nil
	end
	for _, map in maps:GetChildren() do
		local bounds = map:FindFirstChild("Bounds")
		if bounds and bounds:IsA("BasePart") then
			local rel = bounds.CFrame:PointToObjectSpace(root.Position)
			local half = bounds.Size / 2
			if math.abs(rel.X) <= half.X and math.abs(rel.Y) <= half.Y and math.abs(rel.Z) <= half.Z then
				return map
			end
		end
	end
	return nil
end

-- ===== Rutas (Catmull-Rom) =====
type Path = { points: { Vector3 }, cum: { number }, length: number }

local function buildPath(routeFolder: Instance): Path?
	local parts: { BasePart } = {}
	for _, c in routeFolder:GetChildren() do
		if c:IsA("BasePart") then
			table.insert(parts, c)
		end
	end
	if #parts < 2 then
		return nil
	end
	table.sort(parts, function(a, b)
		return a.Name < b.Name
	end)
	local ctrl: { Vector3 } = {}
	for _, p in parts do
		table.insert(ctrl, p.Position)
	end
	local points: { Vector3 } = {}
	local STEPS = 14
	for i = 1, #ctrl - 1 do
		local p0 = ctrl[math.max(1, i - 1)]
		local p1, p2 = ctrl[i], ctrl[i + 1]
		local p3 = ctrl[math.min(#ctrl, i + 2)]
		for s = 0, STEPS - 1 do
			local t = s / STEPS
			local t2, t3 = t * t, t * t * t
			table.insert(
				points,
				0.5
					* (
						2 * p1
						+ (p2 - p0) * t
						+ (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2
						+ (3 * p1 - p0 - 3 * p2 + p3) * t3
					)
			)
		end
	end
	table.insert(points, ctrl[#ctrl])
	local cum = { 0 }
	for i = 2, #points do
		cum[i] = cum[i - 1] + (points[i] - points[i - 1]).Magnitude
	end
	return { points = points, cum = cum, length = cum[#cum] }
end

local function sample(path: Path, dist: number): (Vector3, Vector3)
	local cum = path.cum
	local i = 1
	while i < #cum - 1 and cum[i + 1] < dist do
		i += 1
	end
	local a, b = path.points[i], path.points[i + 1]
	local seg = cum[i + 1] - cum[i]
	local t = if seg > 0 then (dist - cum[i]) / seg else 0
	return a:Lerp(b, math.clamp(t, 0, 1)), (b - a).Unit
end

-- ===== Gigantes =====
type Giant = { model: Model, path: Path, speed: number, dist: number }
type Schedule = { def: { [string]: any }, nextAt: number, active: Giant? }

local giantSchedules: { Schedule } = {}

local function clearGiants()
	for _, s in giantSchedules do
		if s.active then
			s.active.model:Destroy()
			s.active = nil
		end
	end
	giantSchedules = {}
end

local function startMap(map: Instance)
	clearGiants()
	local defs = (A.Giants :: any)[map.Name]
	if not defs then
		return
	end
	local now = os.clock()
	for _, def in defs do
		table.insert(giantSchedules, { def = def, nextAt = now + def.FirstDelay, active = nil })
	end
end

local function spawnGiant(map: Instance, s: Schedule)
	local routes = map:FindFirstChild("AmbientRoutes")
	local folder = routes and routes:FindFirstChild(s.def.Route)
	local template = templates:FindFirstChild(s.def.Template)
	if not folder or not template or not template:IsA("Model") then
		s.nextAt = os.clock() + s.def.Interval
		return
	end
	local path = buildPath(folder)
	if not path then
		s.nextAt = os.clock() + s.def.Interval
		return
	end
	local model = template:Clone()
	model.Parent = live
	local pos, dir = sample(path, 0)
	setCF(model, CFrame.lookAt(pos, pos + dir))
	playClip(model, "Swim", template)
	s.active = { model = model, path = path, speed = s.def.Speed, dist = 0 }
end

local function stepGiants(map: Instance?, dt: number)
	local now = os.clock()
	for _, s in giantSchedules do
		local g = s.active
		if g then
			g.dist += g.speed * dt
			if g.dist >= g.path.length then
				g.model:Destroy()
				s.active = nil
				s.nextAt = now + s.def.Interval
			else
				local pos, dir = sample(g.path, g.dist)
				setCF(g.model, CFrame.lookAt(pos, pos + dir))
			end
		elseif map and now >= s.nextAt then
			spawnGiant(map, s)
		end
	end
end

-- ===== Peces =====
type Member = { model: Model, offset: Vector3 }
type School = { pos: Vector3, dir: Vector3, wish: Vector3, speed: number, turnAt: number, checkAt: number, members: { Member } }

local schools: { School } = {}
local fishCount = 0

local function destroySchool(school: School)
	for _, m in school.members do
		m.model:Destroy()
	end
	fishCount -= #school.members
end

local function clearFish()
	for _, sc in schools do
		destroySchool(sc)
	end
	schools = {}
	fishCount = 0
end

local function insideSub(pos: Vector3): boolean
	local sub = workspace:FindFirstChild("Submarine")
	local zone = sub and sub:FindFirstChild("InteriorZone", true)
	if zone and zone:IsA("BasePart") then
		local rel = zone.CFrame:PointToObjectSpace(pos)
		local half = zone.Size / 2 + Vector3.new(8, 8, 8)
		return math.abs(rel.X) <= half.X and math.abs(rel.Y) <= half.Y and math.abs(rel.Z) <= half.Z
	end
	return false
end

local function inBounds(map: Instance, pos: Vector3): boolean
	local bounds = map:FindFirstChild("Bounds")
	if not bounds or not bounds:IsA("BasePart") then
		return false
	end
	local rel = bounds.CFrame:PointToObjectSpace(pos)
	local half = bounds.Size / 2 - Vector3.new(15, 15, 15)
	return math.abs(rel.X) <= half.X and math.abs(rel.Y) <= half.Y and math.abs(rel.Z) <= half.Z
end

local overlap = OverlapParams.new()
overlap.FilterType = Enum.RaycastFilterType.Exclude
local ray = RaycastParams.new()
ray.FilterType = Enum.RaycastFilterType.Exclude
ray.IgnoreWater = true -- el agua del Terrain no es un obstáculo

local function spawnSchool(map: Instance, root: BasePart)
	local F = A.Fish
	local size = rng:NextInteger(F.SchoolMin, F.SchoolMax)
	if fishCount + size > F.MaxFish then
		return
	end
	local origin: Vector3? = nil
	for _ = 1, 12 do
		local angle = rng:NextNumber(0, math.pi * 2)
		local d = rng:NextNumber(F.SpawnMin, F.SpawnMax)
		local p = root.Position + Vector3.new(math.cos(angle) * d, rng:NextNumber(-12, 18), math.sin(angle) * d)
		if inBounds(map, p) and not insideSub(p) and #workspace:GetPartBoundsInRadius(p, 6, overlap) == 0 then
			origin = p
			break
		end
	end
	if not origin then
		return
	end
	local species = F.Species[rng:NextInteger(1, #F.Species)]
	local template = templates:FindFirstChild(species)
	if not template or not template:IsA("Model") then
		return
	end
	local dir = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(-0.1, 0.1), rng:NextNumber(-1, 1)).Unit
	local school: School = {
		pos = origin,
		dir = dir,
		wish = dir,
		speed = rng:NextNumber(F.Speed[1], F.Speed[2]),
		turnAt = 0,
		checkAt = 0,
		members = {},
	}
	for _ = 1, size do
		local model = template:Clone()
		model.Parent = live
		playClip(model, "Swim", template)
		table.insert(school.members, {
			model = model,
			offset = Vector3.new(rng:NextNumber(-4, 4), rng:NextNumber(-2, 2), rng:NextNumber(-4, 4)),
		})
	end
	fishCount += size
	table.insert(schools, school)
end

local function stepFish(map: Instance, root: BasePart, dt: number)
	local F = A.Fish
	local now = os.clock()
	for i = #schools, 1, -1 do
		local sc = schools[i]
		if (sc.pos - root.Position).Magnitude > F.DespawnDistance then
			destroySchool(sc)
			table.remove(schools, i)
			continue
		end
		if now >= sc.turnAt then
			sc.turnAt = now + rng:NextNumber(4, 9)
			sc.wish = (sc.dir + Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(-0.2, 0.2), rng:NextNumber(-1, 1))).Unit
		end
		if now >= sc.checkAt then
			sc.checkAt = now + 0.35
			-- Evita paredes y rocas: si hay algo delante, gira.
			local hit = workspace:Raycast(sc.pos, sc.dir * 28, ray)
			if hit then
				sc.wish = (sc.dir - 2 * sc.dir:Dot(hit.Normal) * hit.Normal + hit.Normal * 0.6).Unit
			end
		end
		sc.dir = sc.dir:Lerp(sc.wish, math.min(1, dt * 1.2))
		if sc.dir.Magnitude < 0.01 then
			sc.dir = sc.wish
		end
		sc.dir = sc.dir.Unit
		sc.pos += sc.dir * sc.speed * dt
		local basis = CFrame.lookAt(sc.pos, sc.pos + sc.dir)
		for _, m in sc.members do
			local target = basis * CFrame.new(m.offset)
			setCF(m.model, getCF(m.model):Lerp(target, math.min(1, dt * 3)))
		end
	end
	if fishCount < F.MaxFish and rng:NextNumber() < dt * 0.6 then
		spawnSchool(map, root)
	end
end

-- ===== Bucle =====
local checkAccum = 0
local lastMap: Instance? = nil

RunService.Heartbeat:Connect(function(dt)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	checkAccum += dt
	if checkAccum >= 0.5 then
		checkAccum = 0
		local map: Instance? = nil
		if root and root:IsA("BasePart") and player:GetAttribute("InRun") == true then
			map = currentMap(root)
		end
		if map ~= lastMap then
			lastMap = map
			clearFish()
			if map then
				startMap(map)
			else
				clearGiants()
			end
		end
		-- Los vivos y la nave no cuentan como obstáculo al buscar sitio.
		local excluded: { Instance } = { live }
		if character then
			table.insert(excluded, character)
		end
		overlap.FilterDescendantsInstances = excluded
		ray.FilterDescendantsInstances = excluded
	end
	if lastMap and root and root:IsA("BasePart") then
		stepGiants(lastMap, dt)
		stepFish(lastMap, root, dt)
	end
end)
