-- OBSOLETO (2026-11-18): la decoración de las salas la hace Codex (ver ESTADO.md §0.3); las salas viven ahora en
-- Workspace.Salas["Bioma(frabrica)"] y este script ya no las encuentra. Se conserva como referencia.
-- Decora las 10 salas de Workspace.Salas con el kit generado con ForgeGUI
-- (ServerStorage.AbismoAssets.Kit_Instalacion). Se ejecuta en Studio (modo Edit, execute_luau o barra de comandos).
-- Cada sala recibe un Model "Decoracion" (se borra y se regenera al volver a ejecutar). Determinista por sala (semilla).
--
-- v2 (2026-11-18): decoración COHERENTE y a mayor escala.
--  * Cada sala tiene un TEMA (dormitorio, laboratorio, máquinas, almacén, nido, ruinas) y sus props se colocan en GRUPOS con
--    sentido: hileras contra la pared que parten de una esquina (litera, litera, litera, armario...), una pieza central en un
--    cuadrante (mesas de laboratorio, pila de cajas, nido de huevos) y cables/lámpara sobre cada hilera.
--  * Nada de props sueltos al azar: algas en grupos (cortinas juntas, matas en esquinas y junto a la pared).
--  * Escala: BASE x factor de tamaño de la sala (antes los props salían ~2x más pequeños).
--  * Reglas que se mantienen: nada en los huecos de 16 × 16 del centro de cada cara (puertas) ni del suelo/techo.
local CollectionService = game:GetService("CollectionService")
local KIT = game.ServerStorage.AbismoAssets.Kit_Instalacion
local ROOT = workspace.Salas -- las 10 salas del kit viven aquí desde 2026-11-18
local DOOR_CLEAR = 13 -- distancia lateral libre a cada lado del centro de una pared (hueco de 16 + margen)
local CENTER_CLEAR = 16 -- radio libre alrededor del hueco del suelo/techo
local BASE = 2.0 -- factor global sobre los tamaños de abajo

local function template(name: string): Model?
	local m = KIT:FindFirstChild(name)
	return if m and m:IsA("Model") then m else nil
end

-- Coloca una copia escalada para que su dimensión `axis` mida `target`; `cf` es la base (centro inferior) con la orientación.
local function place(parent: Instance, name: string, axis: string, target: number, cf: CFrame, solid: boolean, hang: boolean?): Model?
	local t = template(name)
	if not t then
		return nil
	end
	local m = t:Clone()
	local _, size0 = m:GetBoundingBox()
	local ref = if axis == "X" then size0.X elseif axis == "Y" then size0.Y elseif axis == "Z" then size0.Z else math.max(size0.X, size0.Y, size0.Z)
	m:ScaleTo(m:GetScale() * target / ref)
	m:PivotTo(cf)
	local bcf, bsize = m:GetBoundingBox()
	-- apoya la base (o el techo, si cuelga) en el punto pedido
	local want = if hang then cf.Position.Y - bsize.Y / 2 else cf.Position.Y + bsize.Y / 2
	m:PivotTo(m:GetPivot() + Vector3.new(cf.Position.X - bcf.Position.X, want - bcf.Position.Y, cf.Position.Z - bcf.Position.Z))
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = solid
			d.CanQuery = solid
			d.CanTouch = false
			d.CastShadow = solid
		elseif d:IsA("PackageLink") then
			d:Destroy()
		end
	end
	m.Parent = parent
	return m
end

local function bounds(folder: Instance, pick: (BasePart) -> number, better: (number, number) -> boolean): number?
	local best: number? = nil
	for _, p in folder:GetChildren() do
		if p:IsA("BasePart") then
			local v = pick(p)
			if best == nil or better(v, best) then
				best = v
			end
		end
	end
	return best
end

-- Ítems de una hilera / grupo: n = plantilla, axis/size = medida (antes de escalar), solid, gap = hueco hasta el siguiente.
type Item = { n: string, axis: string, size: number, solid: boolean, gap: number? }
local function it(n: string, axis: string, size: number, solid: boolean, gap: number?): Item
	return { n = n, axis = axis, size = size, solid = solid, gap = gap }
end

-- Temas: row() devuelve la hilera de pared (tema principal); center() las piezas del grupo central (puede ser vacío).
type Theme = { name: string, row: (Random, number) -> { Item }, center: (Random, number) -> { Item }, wallCount: number }
local THEMES: { Theme } = {
	{
		name = "Dormitorio",
		wallCount = 2,
		row = function(rng, H)
			local r = {}
			for _ = 1, rng:NextInteger(3, 4) do
				table.insert(r, it("Prop_Litera", "X", 7, true, 1))
			end
			table.insert(r, it("Prop_Armario_Electrico", "Y", 7, true, 2))
			table.insert(r, it("Prop_Escombros_Cajas", "X", 6, true, 1))
			return r
		end,
		center = function()
			return { it("Prop_Escombros_Cajas", "X", 7, true), it("Prop_Buzo_Muerto", "Max", 5.5, false) }
		end,
	},
	{
		name = "Laboratorio",
		wallCount = 2,
		row = function(rng, H)
			local r = { it("Prop_Consola_Rota", "X", 9, true, 1.5), it("Prop_Mesa_Laboratorio", "X", 8, true, 1.5), it("Prop_Mesa_Laboratorio", "X", 8, true, 1.5) }
			table.insert(r, it("Prop_Tanque_Presion", "Y", math.min(14, H * 0.2), true, 1.5))
			table.insert(r, it("Prop_Armario_Electrico", "Y", 7, true))
			return r
		end,
		center = function()
			return { it("Prop_Mesa_Laboratorio", "X", 8, true), it("Prop_Mesa_Laboratorio", "X", 8, true), it("Prop_Consola_Rota", "X", 9, true) }
		end,
	},
	{
		name = "Maquinas",
		wallCount = 3,
		row = function(rng, H)
			local r = { it("Prop_Generador", "X", 10, true, 1.5), it("Prop_Tuberias_Oxidadas", "Y", math.min(26, H * 0.4), true, 1.5) }
			table.insert(r, it("Prop_Generador", "X", 10, true, 1.5))
			table.insert(r, it("Prop_Tanque_Presion", "Y", math.min(14, H * 0.2), true, 1.5))
			table.insert(r, it("Prop_Armario_Electrico", "Y", 7, true))
			return r
		end,
		center = function(rng, H)
			return { it("Prop_Tanque_Presion", "Y", math.min(14, H * 0.2), true), it("Prop_Tanque_Presion", "Y", math.min(14, H * 0.2), true), it("Prop_Tuberias_Oxidadas", "Y", math.min(26, H * 0.4), true) }
		end,
	},
	{
		name = "Almacen",
		wallCount = 3,
		row = function(rng)
			local r = {}
			for _ = 1, rng:NextInteger(3, 5) do
				table.insert(r, it("Prop_Escombros_Cajas", "X", 12, true, 1))
			end
			table.insert(r, it("Prop_Armario_Electrico", "Y", 7, true))
			return r
		end,
		center = function()
			return { it("Prop_Escombros_Cajas", "X", 12, true), it("Prop_Escombros_Cajas", "X", 12, true), it("Prop_Escombros_Cajas", "X", 10, true), it("Prop_Escotilla", "Y", 8, true) }
		end,
	},
	{
		name = "Nido",
		wallCount = 2,
		row = function(rng)
			local r = {}
			for _ = 1, rng:NextInteger(3, 5) do
				table.insert(r, it("Prop_Huevos_Organicos", "X", 5, false, 0.5))
				if rng:NextNumber() < 0.5 then
					table.insert(r, it("Prop_Algas_Suelo", "X", 6, false, 0.5))
				end
			end
			table.insert(r, it("Prop_Buzo_Muerto", "Max", 5.5, false))
			return r
		end,
		center = function()
			return { it("Prop_Huevos_Organicos", "X", 6, false), it("Prop_Huevos_Organicos", "X", 5, false), it("Prop_Huevos_Organicos", "X", 5, false), it("Prop_Huevos_Organicos", "X", 4.5, false), it("Prop_Algas_Suelo", "X", 7, false) }
		end,
	},
	{
		name = "Ruinas",
		wallCount = 3,
		row = function(rng, H)
			local r = { it("Prop_Columna_Rota", "Y", math.min(14, H * 0.3), true, 1.5), it("Prop_Tabique_Ventanal", "X", 10, true, 1), it("Prop_Pasarela", "X", 12, true, 1) }
			table.insert(r, it("Prop_Escombros_Cajas", "X", 8, true))
			return r
		end,
		center = function(rng, H)
			return { it("Prop_Columna_Rota", "Y", math.min(14, H * 0.3), true), it("Prop_Escombros_Cajas", "X", 9, true), it("Prop_Buzo_Muerto", "Max", 5.5, false) }
		end,
	},
}

local function decorate(room: Model, seed: number, roomIndex: number)
	local old = room:FindFirstChild("Decoracion")
	if old then
		old:Destroy()
	end
	-- quita restos sueltos de pruebas anteriores
	local loose = room:FindFirstChild("Prop_Tuberias_Oxidadas")
	if loose then
		loose:Destroy()
	end
	local deco = Instance.new("Model")
	deco.Name = "Decoracion"
	deco.Parent = room
	local rng = Random.new(seed)

	local floorY = bounds(room.Piso, function(p) return p.Position.Y + p.Size.Y / 2 end, function(a, b) return a > b end) :: number
	local ceilY = bounds(room.Techo, function(p) return p.Position.Y - p.Size.Y / 2 end, function(a, b) return a < b end) :: number
	local zMin = bounds(room.Norte, function(p) return p.Position.Z + p.Size.Z / 2 end, function(a, b) return a > b end) :: number
	local zMax = bounds(room.Sur, function(p) return p.Position.Z - p.Size.Z / 2 end, function(a, b) return a < b end) :: number
	local xMin = bounds(room.Oeste, function(p) return p.Position.X + p.Size.X / 2 end, function(a, b) return a > b end) :: number
	local xMax = bounds(room.Este, function(p) return p.Position.X - p.Size.X / 2 end, function(a, b) return a < b end) :: number
	local cx, cz = (xMin + xMax) / 2, (zMin + zMax) / 2
	local W, D, H = xMax - xMin, zMax - zMin, ceilY - floorY
	-- factor de escala: salas pequeñas (70) ~1,4, medianas ~2, grandes (200) ~2,8
	local S = BASE * math.clamp(math.min(W, D) / 100, 0.7, 1.4)
	local theme = THEMES[(roomIndex - 1) % #THEMES + 1]

	-- paredes: punto medio de la cara interior, normal hacia dentro, eje lateral y largo
	local walls = {
		{ mid = Vector3.new(cx, 0, zMin), n = Vector3.zAxis, t = Vector3.xAxis, len = W },
		{ mid = Vector3.new(cx, 0, zMax), n = -Vector3.zAxis, t = Vector3.xAxis, len = W },
		{ mid = Vector3.new(xMin, 0, cz), n = Vector3.xAxis, t = Vector3.zAxis, len = D },
		{ mid = Vector3.new(xMax, 0, cz), n = -Vector3.xAxis, t = Vector3.zAxis, len = D },
	}

	local function ext(m: Model, w: { n: Vector3, t: Vector3 }): (CFrame, number, number)
		local bcf, bsz = m:GetBoundingBox()
		local along = if math.abs(w.t.X) > 0.5 then bsz.X else bsz.Z
		local deep = if math.abs(w.n.X) > 0.5 then bsz.X else bsz.Z
		return bcf, along, deep
	end

	-- Hilera contra una pared: parte de `startT` y avanza hacia `dir` (±1) sin cruzar el hueco de la puerta; cada ítem queda con su
	-- espalda pegada a la pared. Devuelve el centro (en t) de lo colocado, para poner cables/lámpara encima.
	local function wallRow(w, startT: number, dir: number, items: { Item }): number?
		local cursor = startT
		local first, last = nil, nil
		for _, item in items do
			if not template(item.n) then
				continue
			end
			local base = w.mid + w.t * cursor + Vector3.new(0, floorY, 0)
			local m = place(deco, item.n, item.axis, item.size * S * rng:NextNumber(0.92, 1.08), CFrame.lookAt(base, base + w.n), item.solid)
			if not m then
				continue
			end
			local bcf, along, deep = ext(m, w)
			local far = cursor + dir * along
			local lo, hi = math.min(cursor, far), math.max(cursor, far)
			if math.abs(far) > w.len / 2 - 4 or (lo < DOOR_CLEAR and hi > -DOOR_CLEAR) then
				m:Destroy()
				break
			end
			local want = w.mid + w.t * (cursor + dir * along / 2) + w.n * (0.4 + deep / 2)
			m:PivotTo(m:GetPivot() + Vector3.new(want.X - bcf.Position.X, 0, want.Z - bcf.Position.Z))
			if first == nil then
				first = cursor
			end
			last = far
			cursor = far + dir * (item.gap or 1) * S * 0.5
		end
		if first and last then
			return (first + last) / 2
		end
		return nil
	end

	-- lámpara de jaula en la pared y, si hay hilera, cables arrancados encima
	local function lampAt(w, tpos: number)
		local base = w.mid + w.t * tpos + w.n * 0.8 + Vector3.new(0, floorY + math.min(H * 0.5, 24), 0)
		local lamp = place(deco, "Prop_Lampara_Jaula", "Y", 2.6 * S, CFrame.lookAt(base, base + w.n), false)
		if lamp then
			local mp = lamp:FindFirstChildWhichIsA("BasePart", true) :: BasePart
			local att = Instance.new("Attachment")
			att.Name = "Luz"
			att.WorldPosition = mp.Position + w.n * 1.2
			att.Parent = mp
			local light = Instance.new("PointLight")
			light.Color = if rng:NextNumber() < 0.7 then Color3.fromRGB(255, 165, 95) else Color3.fromRGB(110, 220, 210)
			light.Range = 26 + S * 6
			light.Brightness = 1.4
			light.Shadows = false
			light.Parent = att
			lamp:SetAttribute("Parpadeo", rng:NextNumber() < 0.5)
			CollectionService:AddTag(lamp, "LamparaInstalacion")
		end
	end
	local function cablesAt(w, tpos: number)
		if not template("Prop_Cables_Pared") then
			return
		end
		local base = w.mid + w.t * tpos + w.n * 1.5 + Vector3.new(0, floorY + math.min(H * 0.35, 18), 0)
		place(deco, "Prop_Cables_Pared", "Y", 10 * S * 0.8, CFrame.lookAt(base, base + w.n), false)
	end

	-- 1) hileras temáticas: `wallCount` paredes, cada una desde una esquina libre hacia la puerta
	local order = { 1, 2, 3, 4 }
	for i = #order, 2, -1 do
		local j = rng:NextInteger(1, i)
		order[i], order[j] = order[j], order[i]
	end
	local usedCorners: { [string]: boolean } = {}
	local function cornerKey(w, side: number): string
		local p = w.mid + w.t * (side * w.len / 2)
		return string.format("%d_%d", math.floor(p.X / 5 + 0.5), math.floor(p.Z / 5 + 0.5))
	end
	local inset = 5 + 4 * S
	local rowWalls: { number } = {}
	local count = math.clamp(theme.wallCount + (if math.min(W, D) < 90 then -1 else 0), 1, 4)
	for _, wi in order do
		if #rowWalls >= count then
			break
		end
		local w = walls[wi]
		local side = if rng:NextNumber() < 0.5 then -1 else 1
		for _try = 1, 2 do
			local key = cornerKey(w, side)
			if not usedCorners[key] then
				usedCorners[key] = true
				local mid = wallRow(w, side * (w.len / 2 - inset), -side, theme.row(rng, H))
				if mid then
					table.insert(rowWalls, wi)
					lampAt(w, mid) -- lámpara sobre la hilera
					cablesAt(w, math.clamp(mid + side * 6 * S, -w.len / 2 + 4, w.len / 2 - 4)) -- y cables arrancados hacia la esquina
				end
				break
			end
			side = -side
		end
	end
	-- el resto de paredes: solo la lámpara (en un cuarto de la pared, lejos de la puerta)
	for wi, w in walls do
		if not table.find(rowWalls, wi) then
			local side = if rng:NextNumber() < 0.5 then -1 else 1
			local lt = side * math.max(DOOR_CLEAR + 2, w.len / 4)
			if math.abs(lt) < w.len / 2 - 3 then
				lampAt(w, lt)
			end
		end
	end

	-- 2) pieza central: grupo compacto en un cuadrante (fuera del hueco central del suelo)
	local centerItems = theme.center(rng, H)
	if #centerItems > 0 then
		local qx = if rng:NextNumber() < 0.5 then -1 else 1
		local qz = if rng:NextNumber() < 0.5 then -1 else 1
		local anchor = Vector3.new(cx + qx * W * 0.27, floorY, cz + qz * D * 0.27)
		local placed: { { pos: Vector3, rad: number } } = {}
		for _, item in centerItems do
			for _try = 1, 8 do
				local spread = 6 * S
				local pos = anchor + Vector3.new(rng:NextNumber(-spread, spread), 0, rng:NextNumber(-spread, spread))
				local cf = CFrame.new(pos) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
				local m = place(deco, item.n, item.axis, item.size * S * rng:NextNumber(0.92, 1.08), cf, item.solid)
				if not m then
					break
				end
				local _, sz = m:GetBoundingBox()
				local rad = math.max(sz.X, sz.Z) / 2
				local ok = math.max(math.abs(pos.X - cx), math.abs(pos.Z - cz)) >= CENTER_CLEAR + rad
				for _, p in placed do
					if (Vector3.new(pos.X, 0, pos.Z) - Vector3.new(p.pos.X, 0, p.pos.Z)).Magnitude < (p.rad + rad) * 0.85 then
						ok = false
						break
					end
				end
				if ok then
					table.insert(placed, { pos = pos, rad = rad })
					break
				end
				m:Destroy()
			end
		end
	end

	-- 3) algas en grupos: cortinas juntas en 2-3 puntos del techo y matas en esquinas libres
	local function farFromCenter(x: number, z: number, pad: number): boolean
		return math.max(math.abs(x - cx), math.abs(z - cz)) >= CENTER_CLEAR + pad
	end
	local groups = math.clamp(math.floor(W * D / 5000) + 1, 2, 4)
	for _ = 1, groups do
		local ax = rng:NextNumber(xMin + 12, xMax - 12)
		local az = rng:NextNumber(zMin + 12, zMax - 12)
		for _ = 1, rng:NextInteger(3, 5) do
			for _try = 1, 6 do
				local x = ax + rng:NextNumber(-7, 7) * S * 0.6
				local z = az + rng:NextNumber(-7, 7) * S * 0.6
				if farFromCenter(x, z, 2) and x > xMin + 4 and x < xMax - 4 and z > zMin + 4 and z < zMax - 4 then
					local cf = CFrame.new(x, ceilY, z) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
					place(deco, "Prop_Cortina_Algas", "Y", math.min(H * 0.4, 30) * rng:NextNumber(0.8, 1.15), cf, false, true)
					break
				end
			end
		end
	end
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			if rng:NextNumber() < 0.6 then
				for _ = 1, rng:NextInteger(2, 3) do
					local x = cx + sx * (W / 2 - rng:NextNumber(5, 9) * S * 0.7)
					local z = cz + sz * (D / 2 - rng:NextNumber(5, 9) * S * 0.7)
					local cf = CFrame.new(x, floorY, z) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
					place(deco, "Prop_Algas_Suelo", "X", rng:NextNumber(5, 8) * S * 0.6, cf, false)
				end
			end
		end
	end

	local n = 0
	for _, d in deco:GetDescendants() do
		if d:IsA("BasePart") then
			n += 1
		end
	end
	room:SetAttribute("TemaDecoracion", theme.name)
	return string.format("%s [%s]: %d piezas (%.0f×%.0f×%.0f, escala %.2f)", room.Name, theme.name, n, W, H, D, S)
end

local out = {}
local rooms = {}
for _, room in ROOT:GetChildren() do
	if room:IsA("Model") and room:FindFirstChild("Piso") then
		table.insert(rooms, room)
	end
end
table.sort(rooms, function(a, b) return a.Name < b.Name end)
for i, room in rooms do
	table.insert(out, decorate(room, 7000 + (tonumber(string.match(room.Name, "Sala_(%d+)")) or i), i))
	task.wait()
end
return table.concat(out, "\n")
