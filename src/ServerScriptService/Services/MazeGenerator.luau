--!strict
-- Generador de laberinto por piezas (ver game_designs/Generacion_Cuevas.md §0).
-- Las piezas (pasillo lineal, codo, T, cruce y, más adelante, salas) son Models con un Folder "Conexiones" que tiene una marca por
-- cada extremo abierto: Cara_Este (+X), Cara_Oeste (-X), Cara_Sur (+Z), Cara_Norte (-Z), Cara_Techo (+Y), Cara_Piso (-Y), en el
-- plano del extremo y a media altura del hueco. El pivote del modelo es el origen local. Toda pieza se une a otra haciendo coincidir
-- dos puertos enfrentados (sin hueco), así que todas deben tener la misma sección (hoy 20 x 20 por fuera, 16 x 16 por dentro).
-- Plan(): puro (semilla -> piezas colocadas sin solapes). Validate(): comprueba el plan. Build(): clona, tapa los extremos libres,
-- pone el marco del pozo de la sala_0 y rellena de agua todo el volumen del laberinto.
local MazeGenerator = {}

export type PortDef = { name: string, dir: Vector3, pos: Vector3 }
export type PieceDef = {
	name: string, -- nombre de la plantilla
	kind: string, -- "linear" | "elbow" | "tee" | "cross" | "room"
	ports: { PortDef },
	boxCenter: Vector3, -- centro de la caja de la pieza (espacio del pivote)
	half: Vector3, -- mitad de esa caja
	weight: number?, -- peso al elegir (si falta, el de opts.weights[kind])
	upright: boolean, -- tiene guías `Orientacion` (salas): solo gira sobre el eje vertical, nunca queda de cabeza
	vertical: boolean, -- pozo vertical (kind "shaft*"): cuenta para el máximo de piezas verticales
	junction: Vector3, -- punto central de la pieza (espacio del pivote) para la red de navegación
}
export type Node = {
	id: number,
	def: PieceDef,
	cf: CFrame,
	center: Vector3,
	half: Vector3,
	used: { [number]: boolean },
	parent: number?,
	linearRun: number, -- tramos lineales seguidos que terminan en esta pieza
}
export type Edge = { a: number, b: number, pos: Vector3 }
export type Cap = { node: number, pos: Vector3, dir: Vector3 }
export type Plan = {
	nodes: { Node },
	edges: { Edge },
	caps: { Cap },
	seed: number,
	entry: { pos: Vector3, dir: Vector3 },
	boundsMin: Vector3,
	boundsMax: Vector3,
}
export type Options = {
	pieces: number?, -- piezas a colocar
	maxLinearRun: number?, -- máximo de pasillos lineales seguidos (2 = el lineal y uno más)
	weights: { [string]: number }?, -- peso de cada tipo ("linear", "elbow", "tee", "cross", "room")
	blockers: { { center: Vector3, half: Vector3 } }?, -- cajas que no se pueden ocupar (la sala_0)
	margin: number?,
	maxVertical: number?, -- máximo de pozos verticales (incluida la pieza bajo la sala_0)
	maxRooms: number?, -- máximo de salas (kind "room")
}

local FACE_DIR: { [string]: Vector3 } = {
	Cara_Este = Vector3.xAxis,
	Cara_Oeste = -Vector3.xAxis,
	Cara_Sur = Vector3.zAxis,
	Cara_Norte = -Vector3.zAxis,
	Cara_Techo = Vector3.yAxis,
	Cara_Piso = -Vector3.yAxis,
}

-- Lee una plantilla de pieza. Usa `Estructura` (si existe) para la caja.
function MazeGenerator.ReadPiece(model: Model, kind: string): PieceDef
	local con = model:FindFirstChild("Conexiones")
	assert(con, "Falta Conexiones en " .. model.Name)
	local pivot = model:GetPivot()
	-- Guías `Orientacion` (una Part por cara con EjeLocal/NormalLocal, en el espacio del pivote): fijan el arriba y el abajo de la sala.
	-- Con guías, la sala solo se rota sobre el eje vertical y se comprueba que Techo apunta a +Y y Piso a -Y (si no, está guardada de cabeza).
	local guides = model:FindFirstChild("Orientacion")
	local guideDir: { [string]: Vector3 } = {}
	if guides then
		for _, g in guides:GetChildren() do
			local n = g:GetAttribute("NormalLocal")
			if typeof(n) == "Vector3" then
				guideDir["Cara_" .. g.Name] = n
			end
		end
		local up, down = guideDir.Cara_Techo, guideDir.Cara_Piso
		assert(up and down and (up - Vector3.yAxis).Magnitude < 0.01 and (down + Vector3.yAxis).Magnitude < 0.01, model.Name .. ": la guia Orientacion no tiene Techo en +Y y Piso en -Y (sala de cabeza)")
	end
	local ports: { PortDef } = {}
	for _, p in con:GetChildren() do
		local dir = guideDir[p.Name] or FACE_DIR[p.Name]
		if dir and p:IsA("BasePart") then
			table.insert(ports, { name = p.Name, dir = dir, pos = pivot:PointToObjectSpace(p.Position) })
		end
	end
	assert(#ports >= 1, model.Name .. " no tiene conexiones validas")
	local source: Instance = model:FindFirstChild("Estructura") or model:FindFirstChild("Casco") or model
	local mn, mx = Vector3.new(1e9, 1e9, 1e9), Vector3.new(-1e9, -1e9, -1e9)
	for _, d in source:GetDescendants() do
		if d:IsA("BasePart") then
			local c = pivot:ToObjectSpace(d.CFrame)
			for _, sx in { -1, 1 } do
				for _, sy in { -1, 1 } do
					for _, sz in { -1, 1 } do
						local w = c:PointToWorldSpace(Vector3.new(sx * d.Size.X / 2, sy * d.Size.Y / 2, sz * d.Size.Z / 2))
						mn = Vector3.new(math.min(mn.X, w.X), math.min(mn.Y, w.Y), math.min(mn.Z, w.Z))
						mx = Vector3.new(math.max(mx.X, w.X), math.max(mx.Y, w.Y), math.max(mx.Z, w.Z))
					end
				end
			end
		end
	end
	-- punto central: en el eje del pivote, a la altura de los puertos horizontales (si hay) o en el propio pivote
	local jy = 0
	for _, port in ports do
		if math.abs(port.dir.Y) < 0.5 then
			jy = port.pos.Y
			break
		end
	end
	return {
		name = model.Name,
		kind = kind,
		ports = ports,
		boxCenter = (mn + mx) / 2,
		half = (mx - mn) / 2,
		weight = nil,
		upright = guides ~= nil,
		vertical = string.sub(kind, 1, 5) == "shaft",
		junction = Vector3.new(0, jy, 0),
	}
end

-- Las 24 rotaciones alineadas a los ejes, y las 4 de giro sobre el eje vertical.
local function rotationKey(cf: CFrame): string
	local _, _, _, a, b, c, d, e, f, g, h, i = cf:GetComponents()
	return string.format("%d,%d,%d,%d,%d,%d,%d,%d,%d", math.round(a), math.round(b), math.round(c), math.round(d), math.round(e), math.round(f), math.round(g), math.round(h), math.round(i))
end

local ALL_ROTATIONS: { CFrame } = {}
do
	local seen: { [string]: boolean } = {}
	for i = 0, 3 do
		for j = 0, 3 do
			for k = 0, 3 do
				local cf = CFrame.Angles(i * math.pi / 2, j * math.pi / 2, k * math.pi / 2)
				local key = rotationKey(cf)
				if not seen[key] then
					seen[key] = true
					table.insert(ALL_ROTATIONS, cf)
				end
			end
		end
	end
end
local YAW_ROTATIONS: { CFrame } = {}
for k = 0, 3 do
	table.insert(YAW_ROTATIONS, CFrame.Angles(0, k * math.pi / 2, 0))
end

local function worldBox(cf: CFrame, def: PieceDef): (Vector3, Vector3)
	local center = cf:PointToWorldSpace(def.boxCenter)
	local r, u, l = cf.RightVector, cf.UpVector, cf.LookVector
	local h = def.half
	local half = Vector3.new(
		math.abs(r.X) * h.X + math.abs(u.X) * h.Y + math.abs(l.X) * h.Z,
		math.abs(r.Y) * h.X + math.abs(u.Y) * h.Y + math.abs(l.Y) * h.Z,
		math.abs(r.Z) * h.X + math.abs(u.Z) * h.Y + math.abs(l.Z) * h.Z
	)
	return center, half
end

local function overlap(c1: Vector3, h1: Vector3, c2: Vector3, h2: Vector3, margin: number): boolean
	return math.abs(c1.X - c2.X) < h1.X + h2.X - margin
		and math.abs(c1.Y - c2.Y) < h1.Y + h2.Y - margin
		and math.abs(c1.Z - c2.Z) < h1.Z + h2.Z - margin
end

type FreePort = { node: number, port: number, pos: Vector3, dir: Vector3 }

-- Un intento de planificación con la semilla dada.
local function planOnce(seed: number, defs: { PieceDef }, entryPos: Vector3, options: Options?): Plan
	local opts = options or {}
	local target = opts.pieces or 24
	local maxRun = opts.maxLinearRun or 2
	local margin = opts.margin or 0.5
	local weights = opts.weights or { linear = 3, elbow = 3, tee = 2, cross = 1 }
	local blockers = opts.blockers or {}
	local rng = Random.new(seed)
	local entryDir = -Vector3.yAxis

	-- tabla ponderada de definiciones
	local pool: { PieceDef } = {}
	for _, def in defs do
		for _ = 1, def.weight or weights[def.kind] or 1 do
			table.insert(pool, def)
		end
	end
	local maxVertical = opts.maxVertical or 6
	local maxRooms = opts.maxRooms or 3
	local verticals, rooms = 0, 0
	local function hasPort(def: PieceDef, dir: Vector3): boolean
		for _, port in def.ports do
			if (port.dir - dir).Magnitude < 0.01 then
				return true
			end
		end
		return false
	end

	local entryNeedsTecho = false
	for _, def in defs do
		if hasPort(def, Vector3.yAxis) then
			entryNeedsTecho = true
		end
	end

	local nodes: { Node } = {}
	local edges: { Edge } = {}
	local free: { FreePort } = { { node = 0, port = 0, pos = entryPos, dir = entryDir } }

	local function worldPort(node: Node, port: PortDef): (Vector3, Vector3)
		return node.cf:PointToWorldSpace(port.pos), node.cf:VectorToWorldSpace(port.dir)
	end

	local function fits(center: Vector3, half: Vector3): boolean
		for _, n in nodes do
			if overlap(center, half, n.center, n.half, margin) then
				return false
			end
		end
		for _, b in blockers do
			if overlap(center, half, b.center, b.half, margin) then
				return false
			end
		end
		return true
	end

	local attempts = 0
	while #nodes < target and #free > 0 and attempts < 6000 do
		attempts += 1
		-- puerto libre: con sesgo a los recientes para que haya recorridos largos
		local idx = if rng:NextNumber() < 0.6 then math.max(1, #free - rng:NextInteger(0, math.min(5, #free - 1))) else rng:NextInteger(1, #free)
		local fp = free[idx]
		local parent = if fp.node > 0 then nodes[fp.node] else nil
		local parentRun = if parent then parent.linearRun else 0
		local def = pool[rng:NextInteger(1, #pool)]
		-- tramo recto (pasillo lineal o pozo recto): como mucho `maxRun` seguidos
		local straight = def.kind == "linear" or def.kind == "shaft"
		local parentStraight = parent ~= nil and (parent.def.kind == "linear" or parent.def.kind == "shaft")
		local run = if straight then (if parentStraight then parentRun + 1 else 1) else 0
		local allowed = run <= maxRun
			and not (def.vertical and verticals >= maxVertical)
			and not (def.kind == "room" and rooms >= maxRooms)
			-- la sala_0 siempre se conecta primero a un pasillo: bajo su agujero solo va un tramo vertical (nunca una sala) y no
			-- un pasillo lineal horizontal (quedaría vertical y sin salida)
			and not (fp.node == 0 and (def.kind == "linear" or def.kind == "room"))
			and not (fp.node == 0 and entryNeedsTecho and not hasPort(def, Vector3.yAxis))
		if allowed then
			-- bajo el pozo: si la pieza ya tiene puerto hacia arriba (pozos, salas) solo gira sobre el eje vertical
			local rotations = if not def.upright and fp.node == 0 and not hasPort(def, Vector3.yAxis) then ALL_ROTATIONS else YAW_ROTATIONS
			local candidates: { { cf: CFrame, port: number } } = {}
			for pi, port in def.ports do
				for _, rot in rotations do
					if (rot:VectorToWorldSpace(port.dir) + fp.dir).Magnitude < 0.01 then
						local origin = fp.pos - rot:VectorToWorldSpace(port.pos)
						table.insert(candidates, { cf = CFrame.new(origin) * rot, port = pi })
					end
				end
			end
			if #candidates > 0 then
				local pick = candidates[rng:NextInteger(1, #candidates)]
				local center, half = worldBox(pick.cf, def)
				if fits(center, half) then
					local node: Node = {
						id = #nodes + 1,
						def = def,
						cf = pick.cf,
						center = center,
						half = half,
						used = { [pick.port] = true },
						parent = if fp.node > 0 then fp.node else nil,
						linearRun = run,
					}
					table.insert(nodes, node)
					if def.vertical then
						verticals += 1
					end
					if def.kind == "room" then
						rooms += 1
					end
					table.insert(edges, { a = fp.node, b = node.id, pos = fp.pos })
					table.remove(free, idx)
					-- sus otros puertos: si coinciden con uno libre enfrentado se cierra un bucle; si no, quedan libres
					for pj, port in def.ports do
						if pj ~= pick.port then
							local wp, wd = worldPort(node, port)
							local joined = false
							for k = #free, 1, -1 do
								local other = free[k]
								if other.node > 0 and (other.pos - wp).Magnitude < 0.6 and (other.dir + wd).Magnitude < 0.01 then
									node.used[pj] = true
									nodes[other.node].used[other.port] = true
									table.insert(edges, { a = other.node, b = node.id, pos = wp })
									table.remove(free, k)
									joined = true
									break
								end
							end
							if not joined then
								table.insert(free, { node = node.id, port = pj, pos = wp, dir = wd })
							end
						end
					end
				end
			end
		end
	end

	local caps: { Cap } = {}
	for _, f in free do
		if f.node > 0 then
			table.insert(caps, { node = f.node, pos = f.pos, dir = f.dir })
		end
	end
	local mn, mx = Vector3.new(1e9, 1e9, 1e9), Vector3.new(-1e9, -1e9, -1e9)
	for _, n in nodes do
		mn = Vector3.new(math.min(mn.X, n.center.X - n.half.X), math.min(mn.Y, n.center.Y - n.half.Y), math.min(mn.Z, n.center.Z - n.half.Z))
		mx = Vector3.new(math.max(mx.X, n.center.X + n.half.X), math.max(mx.Y, n.center.Y + n.half.Y), math.max(mx.Z, n.center.Z + n.half.Z))
	end
	return { nodes = nodes, edges = edges, caps = caps, seed = seed, entry = { pos = entryPos, dir = entryDir }, boundsMin = mn, boundsMax = mx }
end

-- Planifica el laberinto a partir del puerto de la sala_0 (`entry`, dirección hacia abajo). Determinista por semilla: si un intento
-- se queda corto (se bloquea antes de llegar a `pieces`), reintenta con semillas derivadas y se queda con el mejor.
function MazeGenerator.Plan(seed: number, defs: { PieceDef }, entryPos: Vector3, options: Options?): Plan
	local target = (options and options.pieces) or 24
	local best = planOnce(seed, defs, entryPos, options)
	local tries = 1
	while #best.nodes < target and tries < 12 do
		local candidate = planOnce(seed + tries * 7919, defs, entryPos, options)
		if #candidate.nodes > #best.nodes then
			best = candidate
		end
		tries += 1
	end
	return best
end

-- Comprueba el plan: solapes, alcanzabilidad desde la sala_0 y racha máxima de pasillos lineales. Devuelve los problemas.
function MazeGenerator.Validate(plan: Plan, maxLinearRun: number?, margin: number?): { string }
	local problems: { string } = {}
	local m = margin or 0.5
	local maxRun = maxLinearRun or 2
	for i = 1, #plan.nodes do
		for j = i + 1, #plan.nodes do
			local a, b = plan.nodes[i], plan.nodes[j]
			if overlap(a.center, a.half, b.center, b.half, m) then
				table.insert(problems, string.format("solape entre pieza %d (%s) y %d (%s)", a.id, a.def.name, b.id, b.def.name))
			end
		end
	end
	local reached: { [number]: boolean } = { [0] = true }
	local changed = true
	while changed do
		changed = false
		for _, e in plan.edges do
			if reached[e.a] and not reached[e.b] then
				reached[e.b] = true
				changed = true
			elseif reached[e.b] and not reached[e.a] then
				reached[e.a] = true
				changed = true
			end
		end
	end
	for _, n in plan.nodes do
		if not reached[n.id] then
			table.insert(problems, "pieza " .. n.id .. " inalcanzable")
		end
		if n.linearRun > maxRun then
			table.insert(problems, string.format("pieza %d: %d pasillos lineales seguidos (máx. %d)", n.id, n.linearRun, maxRun))
		end
	end
	return problems
end

-- Red de navegación del enemigo: vértices en el centro de cada pieza y en cada puerto (compartido entre piezas vecinas);
-- aristas entre el centro y cada puerto de su pieza. Devuelve puntos, aristas con distancia y el vértice de cada pieza.
export type Nav = { points: { Vector3 }, adj: { { { to: number, d: number } } }, nodeVertex: { [number]: number } }

function MazeGenerator.NavGraph(plan: Plan): Nav
	local points: { Vector3 } = {}
	local adj: { { { to: number, d: number } } } = {}
	local byKey: { [string]: number } = {}
	local nodeVertex: { [number]: number } = {}
	local function vertex(p: Vector3): number
		local key = string.format("%d,%d,%d", math.round(p.X * 2), math.round(p.Y * 2), math.round(p.Z * 2))
		local id = byKey[key]
		if not id then
			id = #points + 1
			byKey[key] = id
			points[id] = p
			adj[id] = {}
		end
		return id
	end
	local function link(a: number, b: number)
		if a == b then
			return
		end
		local d = (points[a] - points[b]).Magnitude
		table.insert(adj[a], { to = b, d = d })
		table.insert(adj[b], { to = a, d = d })
	end
	for _, n in plan.nodes do
		local j = vertex(n.cf:PointToWorldSpace(n.def.junction))
		nodeVertex[n.id] = j
		for _, port in n.def.ports do
			link(j, vertex(n.cf:PointToWorldSpace(port.pos)))
		end
	end
	return { points = points, adj = adj, nodeVertex = nodeVertex }
end

local function part(name: string, size: Vector3, cf: CFrame, color: Color3, parent: Instance): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Anchored = true
	p.Material = Enum.Material.Slate
	p.Color = color
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

-- Construye el laberinto en `container`. templates: nombre de plantilla -> Model.
-- opts.water: rellena de agua todo el volumen del laberinto hasta la altura del pozo (y = entry.y); opts.inner/outer: sección del
-- pasillo (16 y 20). opts.pit (opcional): lado de un pozo más ancho que el pasillo; si se da, se pone un marco que lo une con la
-- primera pieza. Con el agujero de 16 × 16 de la sala_0 (2026-11-18) no hace falta marco.
function MazeGenerator.Build(plan: Plan, templates: { [string]: Model }, container: Instance, opts: { water: boolean, inner: number, outer: number, pit: number? })
	local counts = { pieces = 0, caps = 0 }
	for _, n in plan.nodes do
		local template = templates[n.def.name]
		assert(template, "falta la plantilla " .. n.def.name)
		local clone = template:Clone()
		clone.Name = string.format("%s_%d", n.def.name, n.id)
		clone:PivotTo(n.cf)
		clone.Parent = container
		counts.pieces += 1
	end
	local dark = Color3.fromRGB(55, 62, 68)
	for _, c in plan.caps do
		local size = Vector3.new(opts.outer, opts.outer, 2)
		local up = if math.abs(c.dir.Y) > 0.9 then Vector3.xAxis else Vector3.yAxis
		part("Tapon", size, CFrame.lookAt(c.pos + c.dir * 1, c.pos + c.dir * 2, up), dark, container)
		counts.caps += 1
	end
	-- marco horizontal entre un pozo más ancho (opts.pit) y la primera pieza (hueco opts.inner), alineado con el suelo de la sala_0
	local pit = opts.pit
	if pit and pit > opts.inner then
		local e = plan.entry.pos
		local bar = (pit + 6 - opts.inner) / 2
		local whole = pit + 6
		local frame = Instance.new("Folder")
		frame.Name = "MarcoDelPozo"
		frame.Parent = container
		for _, sgn in { -1, 1 } do
			part("Barra", Vector3.new(bar, 1, whole), CFrame.new(e + Vector3.new(sgn * (opts.inner / 2 + bar / 2), 0.5, 0)), dark, frame)
			part("Barra", Vector3.new(opts.inner, 1, bar), CFrame.new(e + Vector3.new(0, 0.5, sgn * (opts.inner / 2 + bar / 2))), dark, frame)
		end
	end
	-- Bounds del laberinto (para criaturas y comprobaciones)
	local bounds = Instance.new("Part")
	bounds.Name = "Bounds"
	bounds.Anchored = true
	bounds.CanCollide = false
	bounds.CanQuery = false
	bounds.CanTouch = false
	bounds.Transparency = 1
	bounds.Size = plan.boundsMax - plan.boundsMin
	bounds.CFrame = CFrame.new((plan.boundsMax + plan.boundsMin) / 2)
	bounds.Parent = container
	if opts.water then
		-- todo el volumen del laberinto bajo el nivel del pozo es agua: no hace falta contener el agua dentro de paredes finas
		local pad = 24
		local top = e.Y
		local bottom = plan.boundsMin.Y - pad
		local size = Vector3.new(plan.boundsMax.X - plan.boundsMin.X + pad * 2, top - bottom, plan.boundsMax.Z - plan.boundsMin.Z + pad * 2)
		local center = Vector3.new((plan.boundsMax.X + plan.boundsMin.X) / 2, (top + bottom) / 2, (plan.boundsMax.Z + plan.boundsMin.Z) / 2)
		workspace.Terrain:FillBlock(CFrame.new(center), size, Enum.Material.Water)
	end
	return counts
end

return MazeGenerator
