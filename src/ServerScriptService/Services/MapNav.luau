--!strict
-- Construye la red de navegación y los puntos tácticos sobre el mapa fijo cargado en Workspace.Maps (T05).
-- Publica LevelState.nav, LevelState.container y LevelState.entry para MonsterService.
-- Usa los marcadores del manifiesto (ElevatorDock, Patrol1..N, CreatureSpawn, MachineSpawn, TreasureSpawn, HideSpot/Escondite)
-- y PathfindingService (con respaldo del grafo de visibilidad) respetando las puertas cerradas de Workspace.RunObjectives.
local PathfindingService = game:GetService("PathfindingService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local LevelState = require(script.Parent:WaitForChild("LevelState"))
local SafeZone = require(script.Parent:WaitForChild("SafeZone"))

local MapNav = {}

export type Edge = { to: number, d: number }
export type AmbushSpot = { pos: Vector3, hideSpot: BasePart? }
export type NavGraph = {
	points: { Vector3 },
	adj: { { Edge } },
	spawns: { Vector3 },
	ambushSpots: { AmbushSpot },
	boundsCenter: Vector3,
	boundsHalf: Vector3,
}

local function makeMapFilter(map: Instance): RaycastParams
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	local list: { Instance } = { map }
	local obj = workspace:FindFirstChild("RunObjectives")
	if obj then
		table.insert(list, obj)
	end
	params.FilterDescendantsInstances = list
	params.RespectCanCollide = true
	return params
end

-- Proyecta un punto sobre el suelo del mapa y lo eleva al centro del cuerpo de la criatura. Los marcadores están a ras de suelo:
-- el rayo sale de poco más arriba para no caer encima de muebles o maquinaria.
local function snapToFloor(pos: Vector3, centerY: number, params: RaycastParams): Vector3
	local hit = workspace:Raycast(pos + Vector3.new(0, 1.5, 0), Vector3.new(0, -8, 0), params)
	if hit then
		return hit.Position + Vector3.new(0, centerY, 0)
	end
	return Vector3.new(pos.X, pos.Y + centerY, pos.Z)
end

local function isTooClose(list: { Vector3 }, p: Vector3, minDist: number): boolean
	for _, existing in list do
		if (existing - p).Magnitude < minDist then
			return true
		end
	end
	return false
end

local function addUnique(list: { Vector3 }, p: Vector3, minDist: number)
	if not isTooClose(list, p, minDist) then
		table.insert(list, p)
	end
end

local function isPatrolAttachment(inst: Instance): number?
	if not inst:IsA("Attachment") then
		return nil
	end
	local num = string.match(inst.Name, "^Patrol(%d+)$")
	return if num then tonumber(num) else nil
end

-- Construye el grafo de navegación del mapa activo y actualiza LevelState.
function MapNav.Build(map: Instance): NavGraph
	local centerY = Config.Monster.CenterHeight
	local radius = Config.Monster.BodyRadius * 0.85
	local params = makeMapFilter(map)
	local doorPrefix = Config.Objectives.Door.SpawnPrefix
	local spacing = Config.Monster.NavGridSpacing

	local patrolList: { { n: number, pos: Vector3 } } = {}
	local spawns: { Vector3 } = {}
	local ambushSpots: { AmbushSpot } = {}
	local extras: { Vector3 } = {}
	local dockPos: Vector3? = nil
	local hideParts: { BasePart } = {}

	for _, d in map:GetDescendants() do
		if d.Name == "ElevatorDock" and d:IsA("BasePart") then
			dockPos = d.Position
		elseif d:IsA("Attachment") then
			local pNum = isPatrolAttachment(d)
			if pNum then
				table.insert(patrolList, { n = pNum, pos = snapToFloor(d.WorldPosition, centerY, params) })
			elseif d.Name == "CreatureSpawn" then
				table.insert(spawns, snapToFloor(d.WorldPosition, centerY, params))
			elseif d.Name == "MachineSpawn" or d.Name == "TreasureSpawn" or d.Name == "PuzzleSpawn" then
				-- Los PuzzleSpawn de puertas quedan dentro de la persiana: no sirven de nodo.
				local owner = d.Parent
				if not (d.Name == "PuzzleSpawn" and owner and string.sub(owner.Name, 1, #doorPrefix) == doorPrefix) then
					table.insert(extras, snapToFloor(d.WorldPosition, centerY, params))
				end
			end
		elseif d:IsA("BasePart") and (d.Name == "HideSpot" or d.Name == "Escondite") then
			-- El volumen está dentro del mueble (taquilla): su punto de emboscada se elige después, junto a él, en la red.
			table.insert(hideParts, d)
		end
	end

	table.sort(patrolList, function(a, b)
		return a.n < b.n
	end)

	local points: { Vector3 } = {}
	for _, entry in patrolList do
		addUnique(points, entry.pos, 3)
		table.insert(ambushSpots, { pos = entry.pos, hideSpot = nil })
	end
	for _, p in spawns do
		addUnique(points, p, 3)
	end
	for _, p in extras do
		addUnique(points, p, 8)
	end

	-- Respaldo si el mapa tiene pocos marcadores: malla ligera sobre la caja del nivel
	local cf, size = (map :: Model):GetBoundingBox()
	local boundsPart = map:FindFirstChild("Bounds")
	local boundsCenter = cf.Position
	local boundsHalf = size / 2 + Vector3.new(8, 12, 8)
	if boundsPart and boundsPart:IsA("BasePart") then
		boundsCenter = boundsPart.Position
		boundsHalf = boundsPart.Size / 2 + Vector3.new(6, 6, 6)
	end

	if #points == 0 then
		table.insert(points, snapToFloor(boundsCenter, centerY, params))
	end

	-- Malla de puntos sobre el suelo de la planta de los marcadores de patrulla (la más baja): sin ella los pocos marcadores no
	-- se ven entre sí (paredes) y el grafo queda en islas. Solo puntos con hueco libre para el cuerpo y fuera de la zona segura.
	local markerCount = #points
	local floorY = math.huge
	for _, entry in patrolList do
		floorY = math.min(floorY, entry.pos.Y - centerY)
	end
	if floorY == math.huge then
		floorY = points[1].Y - centerY
	end
	local overlap = OverlapParams.new()
	overlap.FilterType = Enum.RaycastFilterType.Include
	overlap.FilterDescendantsInstances = params.FilterDescendantsInstances
	overlap.RespectCanCollide = true
	local lo = boundsCenter - (size / 2)
	local hi = boundsCenter + (size / 2)
	if boundsPart and boundsPart:IsA("BasePart") then
		lo = boundsPart.Position - boundsPart.Size / 2
		hi = boundsPart.Position + boundsPart.Size / 2
	end
	for x = lo.X + spacing / 2, hi.X, spacing do
		for z = lo.Z + spacing / 2, hi.Z, spacing do
			local hit = workspace:Raycast(Vector3.new(x, floorY + 2, z), Vector3.new(0, -4, 0), params)
			if hit and hit.Normal.Y > 0.7 then
				local p = hit.Position + Vector3.new(0, centerY, 0)
				local box = workspace:GetPartBoundsInBox(CFrame.new(p + Vector3.new(0, 0.5, 0)), Vector3.new(radius * 2, centerY * 2 - 1, radius * 2), overlap)
				if #box == 0 and not SafeZone.BarsMonster(p) and not isTooClose(points, p, spacing * 0.4) then
					table.insert(points, p)
				end
			end
		end
	end

	-- Aristas: entre marcadores, hasta 90 studs con vista despejada; con la malla, solo vecinos cercanos (barato y suficiente).
	local adj: { { Edge } } = {}
	for i = 1, #points do
		adj[i] = {}
	end
	local gridReach = spacing * 1.6
	for i = 1, #points do
		for j = i + 1, #points do
			local a, b = points[i], points[j]
			local delta = b - a
			local d = delta.Magnitude
			local maxD = if i <= markerCount and j <= markerCount then 90 else gridReach
			if d > 0.5 and d <= maxD and math.abs(delta.Y) <= 10 then
				if workspace:Spherecast(a, radius, delta, params) == nil then
					table.insert(adj[i], { to = j, d = d })
					table.insert(adj[j], { to = i, d = d })
				end
			end
		end
	end

	-- Punto de emboscada de cada escondite: el nodo libre más cercano (fuera del mueble), con vista despejada hasta el volumen.
	for _, hp in hideParts do
		local best: Vector3? = nil
		local bestD = 14
		for _, p in points do
			local d = (Vector3.new(p.X, 0, p.Z) - Vector3.new(hp.Position.X, 0, hp.Position.Z)).Magnitude
			if d < bestD and math.abs(p.Y - centerY - (hp.Position.Y - hp.Size.Y / 2)) < 3 then
				best, bestD = p, d
			end
		end
		if best then
			table.insert(ambushSpots, { pos = best, hideSpot = hp })
		end
	end

	local nav: NavGraph = {
		points = points,
		adj = adj,
		spawns = spawns,
		ambushSpots = ambushSpots,
		boundsCenter = boundsCenter,
		boundsHalf = boundsHalf,
	}

	LevelState.container = map
	LevelState.nav = nav
	LevelState.entry = dockPos or boundsCenter
	return nav
end

function MapNav.Clear()
	LevelState.container = nil
	LevelState.nav = nil
	LevelState.entry = nil
end

-- Calcula camino con PathfindingService respetando paredes y puertas cerradas.
-- Devuelve nil si PathfindingService falla (MonsterService usa entonces el grafo Dijkstra).
function MapNav.ComputeNavMeshPath(fromPos: Vector3, toPos: Vector3, agentRadius: number, centerY: number): { Vector3 }?
	local path = PathfindingService:CreatePath({
		AgentRadius = math.max(1.5, agentRadius),
		AgentHeight = 7.5,
		AgentCanJump = false,
		AgentCanClimb = false,
		WaypointSpacing = 8,
	})
	local ok = pcall(function()
		path:ComputeAsync(fromPos - Vector3.new(0, centerY - 1, 0), toPos - Vector3.new(0, centerY - 1, 0))
	end)
	if not ok or path.Status ~= Enum.PathStatus.Success then
		return nil
	end
	local raw = path:GetWaypoints()
	if #raw == 0 then
		return nil
	end
	local out: { Vector3 } = {}
	for i, wp in raw do
		if i > 1 then
			local p = wp.Position + Vector3.new(0, centerY, 0)
			if SafeZone.BarsMonster(p) then
				break
			end
			table.insert(out, p)
		end
	end
	if #out == 0 then
		return nil
	end
	return out
end

return MapNav
