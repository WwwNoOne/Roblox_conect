--!strict
-- Generador de cuevas por salas (ver game_designs/Generacion_Cuevas.md).
-- Plan(): parte pura (semilla -> grafo de salas y pasillos sobre posiciones exactas, sin solapes).
-- Build(): clona salas y pasillos, tapa las puertas sin usar.
-- Convención de salas: Model con Folder "Conexiones" y 6 Parts invisibles Cara_Norte (-Z), Cara_Sur (+Z), Cara_Oeste (-X),
-- Cara_Este (+X), Cara_Piso (-Y), Cara_Techo (+Y) en el centro de cada puerta (a mitad del grosor de la pared).
-- El pasillo es un Model con pivote en el centro, eje Z a lo largo, y Parts Port_A (+Z) y Port_B (-Z) en los extremos.
local RoomGenerator = {}

export type PortMap = { [string]: Vector3 } -- "X+" .. "Z-" -> desplazamiento desde el centro de la sala al marcador
export type RoomDef = {
	name: string, -- nombre de la plantilla (clave de templates.rooms)
	kind: string,
	ports: PortMap,
	half: Vector3, -- mitad de la caja exterior (para detectar solapes)
	wall: number, -- grosor de pared
	centerInPivot: Vector3, -- centro de la sala en el espacio del pivote de la plantilla
}
export type Node = {
	id: number,
	kind: string,
	center: Vector3,
	yaw: number, -- cuartos de vuelta sobre el eje vertical
	ports: PortMap, -- ya rotados
	half: Vector3, -- ya rotada
	used: { [string]: boolean },
	def: RoomDef,
	parent: number?,
}
export type Edge = { a: number, b: number, dirName: string, dir: Vector3, posA: Vector3, posB: Vector3 }
export type Plan = { nodes: { Node }, edges: { Edge }, placedSmall: number, seed: number, scale: number }
export type Options = { smalls: number?, corridor: number?, bigDoors: number?, verticalMax: number?, margin: number?, scale: number? }

local DIRS: { [string]: Vector3 } = {
	["X+"] = Vector3.xAxis,
	["X-"] = -Vector3.xAxis,
	["Y+"] = Vector3.yAxis,
	["Y-"] = -Vector3.yAxis,
	["Z+"] = Vector3.zAxis,
	["Z-"] = -Vector3.zAxis,
}
local OPPOSITE: { [string]: string } = { ["X+"] = "X-", ["X-"] = "X+", ["Y+"] = "Y-", ["Y-"] = "Y+", ["Z+"] = "Z-", ["Z-"] = "Z+" }
local FACE_DIR: { [string]: string } = {
	Cara_Este = "X+",
	Cara_Oeste = "X-",
	Cara_Techo = "Y+",
	Cara_Piso = "Y-",
	Cara_Sur = "Z+",
	Cara_Norte = "Z-",
}

local function dirNameOf(v: Vector3): string
	local ax, ay, az = math.abs(v.X), math.abs(v.Y), math.abs(v.Z)
	if ax >= ay and ax >= az then
		return if v.X >= 0 then "X+" else "X-"
	elseif ay >= az then
		return if v.Y >= 0 then "Y+" else "Y-"
	end
	return if v.Z >= 0 then "Z+" else "Z-"
end

local function rotateYaw(v: Vector3, quarters: number): Vector3
	local r = CFrame.Angles(0, math.rad(90 * quarters), 0):VectorToWorldSpace(v)
	return Vector3.new(math.round(r.X * 100) / 100, math.round(r.Y * 100) / 100, math.round(r.Z * 100) / 100)
end

-- Lee una plantilla de sala (Model) y devuelve su definición.
-- scale: escala con la que se instanciará la plantilla (todo lo medido se multiplica por ella).
function RoomGenerator.ReadDef(model: Model, kind: string, wall: number, scale: number?): RoomDef
	local folder = model:FindFirstChild("Conexiones", true)
	assert(folder, "Falta Conexiones en " .. model.Name)
	local world: { [string]: Vector3 } = {}
	local sum = Vector3.zero
	local count = 0
	for _, p in folder:GetChildren() do
		local name = FACE_DIR[p.Name]
		if name and p:IsA("BasePart") then
			world[name] = p.Position
			sum += p.Position
			count += 1
		end
	end
	assert(count == 6, model.Name .. ": se esperaban 6 conexiones y hay " .. count)
	local k = scale or 1
	local center = sum / 6
	local ports: PortMap = {}
	for name, pos in world do
		ports[name] = (pos - center) * k
	end
	wall = wall * k
	local half = Vector3.new(
		(math.abs(ports["X+"].X) + math.abs(ports["X-"].X)) / 2 + wall / 2,
		(math.abs(ports["Y+"].Y) + math.abs(ports["Y-"].Y)) / 2 + wall / 2,
		(math.abs(ports["Z+"].Z) + math.abs(ports["Z-"].Z)) / 2 + wall / 2
	)
	local pivot = model:GetPivot()
	return {
		name = model.Name,
		kind = kind,
		ports = ports,
		half = half,
		wall = wall,
		centerInPivot = pivot:PointToObjectSpace(center) * k,
	}
end

local function aabbOverlap(c1: Vector3, h1: Vector3, c2: Vector3, h2: Vector3, margin: number): boolean
	return math.abs(c1.X - c2.X) < h1.X + h2.X - margin
		and math.abs(c1.Y - c2.Y) < h1.Y + h2.Y - margin
		and math.abs(c1.Z - c2.Z) < h1.Z + h2.Z - margin
end

local function corridorBox(posA: Vector3, posB: Vector3, dir: Vector3, scale: number): (Vector3, Vector3)
	local mid = (posA + posB) / 2
	local len = (posB - posA).Magnitude / 2
	local w = 37 * scale -- mitad del ancho exterior del pasillo (con paredes)
	local half = Vector3.new(w, w, w)
	local along = Vector3.new(math.abs(dir.X), math.abs(dir.Y), math.abs(dir.Z)) * math.max(0, len - w)
	return mid, half + along
end

-- Planifica el nivel. defs.sala0: puerto "Y-" (el pozo); defs.big: sala grande; defs.smalls: variantes de sala pequeña (se elige
-- una al azar para cada sala, evitando repetir la del padre si hay más de una).
function RoomGenerator.Plan(seed: number, defs: { sala0: RoomDef, big: RoomDef, smalls: { RoomDef } }, origin: Vector3, options: Options?): Plan
	local opts = options or {}
	local smalls = opts.smalls or 10
	local corridor = opts.corridor or 140
	local bigDoors = opts.bigDoors or 3
	local verticalMax = opts.verticalMax or 2
	local margin = opts.margin or 2
	local scale = opts.scale or 1
	local rng = Random.new(seed)

	local nodes: { Node } = {}
	local edges: { Edge } = {}
	local boxes: { { c: Vector3, h: Vector3, a: number?, b: number? } } = {} -- salas (a = id) y pasillos (a,b = ids)

	local function addNode(kind: string, def: RoomDef, center: Vector3, quarters: number, parent: number?): Node
		local ports: PortMap = {}
		for _, name in { "X+", "X-", "Y+", "Y-", "Z+", "Z-" } do
			local off = def.ports[name]
			if off then
				-- el nombre del puerto sale de la dirección de la cara, no del desplazamiento (que puede no estar alineado con el eje)
				ports[dirNameOf(rotateYaw(DIRS[name], quarters))] = rotateYaw(off, quarters)
			end
		end
		local rh = rotateYaw(def.half, quarters)
		local node: Node = {
			id = #nodes + 1,
			kind = kind,
			center = center,
			yaw = quarters,
			ports = ports,
			half = Vector3.new(math.abs(rh.X), math.abs(rh.Y), math.abs(rh.Z)),
			used = {},
			def = def,
			parent = parent,
		}
		table.insert(nodes, node)
		table.insert(boxes, { c = center, h = node.half, a = node.id })
		return node
	end

	-- Calcula dónde quedaría un hijo unido por la puerta `dirName` del nodo `p`. Devuelve nil si choca.
	local function tryAttach(p: Node, dirName: string, kind: string, def: RoomDef, quarters: number): (Node?, Edge?)
		local off = p.ports[dirName]
		if not off or p.used[dirName] then
			return nil, nil
		end
		local dir = DIRS[dirName]
		local childPortName = OPPOSITE[dirName]
		-- puertos del hijo ya rotados
		local childPorts: PortMap = {}
		for _, name in { "X+", "X-", "Y+", "Y-", "Z+", "Z-" } do
			local off2 = def.ports[name]
			if off2 then
				childPorts[dirNameOf(rotateYaw(DIRS[name], quarters))] = rotateYaw(off2, quarters)
			end
		end
		local childOff = childPorts[childPortName]
		if not childOff then
			return nil, nil
		end
		local posA = p.center + off
		local posB = posA + dir * corridor
		local center = posB - childOff
		local rh = rotateYaw(def.half, quarters)
		local half = Vector3.new(math.abs(rh.X), math.abs(rh.Y), math.abs(rh.Z))
		local cc, ch = corridorBox(posA, posB, dir, scale)
		for _, b in boxes do
			local isParent = (b.a == p.id and b.b == nil)
			if not isParent and aabbOverlap(center, half, b.c, b.h, margin) then
				return nil, nil
			end
			if not isParent and aabbOverlap(cc, ch, b.c, b.h, margin) then
				-- el pasillo solo puede tocar a su padre
				return nil, nil
			end
		end
		local node = addNode(kind, def, center, quarters, p.id)
		p.used[dirName] = true
		node.used[childPortName] = true
		table.insert(boxes, { c = cc, h = ch, a = p.id, b = node.id })
		local edge: Edge = { a = p.id, b = node.id, dirName = dirName, dir = dir, posA = posA, posB = posB }
		table.insert(edges, edge)
		return node, edge
	end

	-- 1) sala_0 (fija): solo existe su puerta de abajo (el pozo)
	local sala0 = addNode("sala0", defs.sala0, origin, 0, nil)
	-- 2) sala grande debajo, unida por el pozo
	local big = tryAttach(sala0, "Y-", "big", defs.big, 0)
	assert(big, "la sala grande no cabe bajo la sala_0")

	-- 3) salas pequeñas
	local verticals = 0
	local placed = 0
	for i = 1, smalls do
		local ok = false
		for _ = 1, 120 do
			local parent: Node
			if i <= bigDoors then
				parent = big
			else
				local pool: { Node } = {}
				for _, n in nodes do
					if n.kind ~= "sala0" then
						table.insert(pool, n)
					end
				end
				parent = pool[rng:NextInteger(1, #pool)]
			end
			local free: { string } = {}
			for name in parent.ports do
				if not parent.used[name] and name ~= "Y+" then -- nada por encima de la sala_0
					if name ~= "Y-" or verticals < verticalMax then
						table.insert(free, name)
					end
				end
			end
			if #free > 0 then
				local dirName = free[rng:NextInteger(1, #free)]
				local variants = defs.smalls
				local def = variants[rng:NextInteger(1, #variants)]
				if #variants > 1 and def.name == parent.def.name then
					def = variants[rng:NextInteger(1, #variants)]
				end
				local node = tryAttach(parent, dirName, "small", def, rng:NextInteger(0, 3))
				if node then
					if dirName == "Y-" then
						verticals += 1
					end
					placed += 1
					ok = true
					break
				end
			end
		end
		if not ok then
			break
		end
	end
	return { nodes = nodes, edges = edges, placedSmall = placed, seed = seed, scale = scale }
end

-- Comprueba el plan: sin solapes entre salas, y todas alcanzables desde la sala_0. Devuelve una lista de problemas.
function RoomGenerator.Validate(plan: Plan, margin: number?): { string }
	local problems: { string } = {}
	local m = margin or 2
	for i = 1, #plan.nodes do
		for j = i + 1, #plan.nodes do
			local a, b = plan.nodes[i], plan.nodes[j]
			if aabbOverlap(a.center, a.half, b.center, b.half, m) then
				table.insert(problems, string.format("solape entre sala %d (%s) y %d (%s)", a.id, a.kind, b.id, b.kind))
			end
		end
	end
	local reached: { [number]: boolean } = { [1] = true }
	local changed = true
	while changed do
		changed = false
		for _, e in plan.edges do
			if reached[e.a] and not reached[e.b] then
				reached[e.b] = true
				changed = true
			end
		end
	end
	for _, n in plan.nodes do
		if not reached[n.id] then
			table.insert(problems, "sala " .. n.id .. " inalcanzable")
		end
	end
	return problems
end

local function cframeFor(dir: Vector3, pos: Vector3): CFrame
	local up = if math.abs(dir.Y) > 0.9 then Vector3.xAxis else Vector3.yAxis
	return CFrame.lookAt(pos, pos + dir, up)
end

-- Construye el nivel dentro de `container`. templates: big, small, corridor (Models). La sala_0 no se clona (ya está en el mundo).
function RoomGenerator.Build(plan: Plan, templates: { rooms: { [string]: Model }, corridor: Model }, container: Instance): { rooms: number, corridors: number, plugs: number }
	local counts = { rooms = 0, corridors = 0, plugs = 0 }
	for _, n in plan.nodes do
		if n.kind ~= "sala0" then
			local template = templates.rooms[n.def.name]
			assert(template, "falta la plantilla " .. n.def.name)
			local clone = template:Clone()
			clone:ScaleTo(clone:GetScale() * plan.scale)
			clone.Name = string.format("%s_%d", n.kind, n.id)
			clone:PivotTo(CFrame.new(n.center) * CFrame.Angles(0, math.rad(90 * n.yaw), 0) * CFrame.new(-n.def.centerInPivot))
			-- Bounds: volumen interior libre (límite de las criaturas)
			local bounds = Instance.new("Part")
			bounds.Name = "Bounds"
			bounds.Size = (n.half * 2 - Vector3.new(n.def.wall, n.def.wall, n.def.wall) * 2)
			bounds.CFrame = CFrame.new(n.center)
			bounds.Anchored = true
			bounds.CanCollide = false
			bounds.CanQuery = false
			bounds.CanTouch = false
			bounds.Transparency = 1
			bounds.Parent = clone
			clone.Parent = container
			counts.rooms += 1
		end
		-- tapones en las puertas sin usar (la sala_0 no se tapa: su única puerta es el pozo)
		if n.kind ~= "sala0" then
			for name, off in n.ports do
				if not n.used[name] then
					local plug = Instance.new("Part")
					plug.Name = "Tapon"
					plug.Size = Vector3.new(70 * plan.scale, 70 * plan.scale, n.def.wall + 2)
					plug.CFrame = cframeFor(DIRS[name], n.center + off)
					plug.Anchored = true
					plug.Material = Enum.Material.Slate
					plug.Color = Color3.fromRGB(55, 62, 68)
					plug.Parent = container
					counts.plugs += 1
				end
			end
		end
	end
	for _, e in plan.edges do
		local mid = (e.posA + e.posB) / 2
		local cf = cframeFor(e.dir, mid)
		local clone = templates.corridor:Clone()
		clone:ScaleTo(clone:GetScale() * plan.scale)
		clone.Name = string.format("pasillo_%d_%d", e.a, e.b)
		clone:PivotTo(cf)
		clone.Parent = container
		counts.corridors += 1
	end
	return counts
end

return RoomGenerator
