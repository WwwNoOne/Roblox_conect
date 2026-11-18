-- Decora las 10 salas de Workspace.Salas con el kit generado con ForgeGUI
-- (ServerStorage.AbismoAssets.Kit_Instalacion). Se ejecuta en Studio (modo Edit, execute_luau o barra de comandos).
-- Cada sala recibe un Model "Decoracion" (se borra y se regenera al volver a ejecutar). Determinista por sala (semilla).
-- Reglas: nada en los huecos de 16 × 16 del centro de cada cara (puertas), objetos grandes contra las paredes,
-- algas colgando del techo y por el suelo, una lámpara de jaula por pared con luz tenue.
local CollectionService = game:GetService("CollectionService")
local KIT = game.ServerStorage.AbismoAssets.Kit_Instalacion
local ROOT = workspace.Salas -- las 10 salas del kit viven aquí desde 2026-11-18
local DOOR_CLEAR = 13 -- distancia lateral libre a cada lado del centro de una pared (hueco de 16 + margen)
local CENTER_CLEAR = 14 -- radio libre alrededor del hueco del suelo/techo

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

local function decorate(room: Model, seed: number)
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

	-- paredes: punto medio de la cara interior, normal hacia dentro, eje lateral y largo
	local walls = {
		{ mid = Vector3.new(cx, 0, zMin), n = Vector3.zAxis, t = Vector3.xAxis, len = W },
		{ mid = Vector3.new(cx, 0, zMax), n = -Vector3.zAxis, t = Vector3.xAxis, len = W },
		{ mid = Vector3.new(xMin, 0, cz), n = Vector3.xAxis, t = Vector3.zAxis, len = D },
		{ mid = Vector3.new(xMax, 0, cz), n = -Vector3.xAxis, t = Vector3.zAxis, len = D },
	}

	-- Objetos de suelo contra la pared: nombre, eje de medida, tamaño, profundidad aprox. (para separarlo de la pared), sólido, peso
	local big = {
		{ "Prop_Tanque_Presion", "Y", math.min(14, H * 0.4), 7, true, 3 },
		{ "Prop_Tuberias_Oxidadas", "Y", math.min(26, H * 0.55), 5, true, 3 },
		{ "Prop_Consola_Rota", "X", 9, 4.5, true, 2 },
		{ "Prop_Escombros_Cajas", "X", 12, 7, true, 2 },
		{ "Prop_Buzo_Muerto", "Max", 5.5, 4, false, 1 },
		{ "Prop_Algas_Suelo", "X", 7, 6, false, 2 },
		-- kit v2 (2026-11-18)
		{ "Prop_Litera", "X", 7, 4, true, 2 },
		{ "Prop_Mesa_Laboratorio", "X", 8, 5, true, 2 },
		{ "Prop_Generador", "X", 10, 4, true, 1 },
		{ "Prop_Armario_Electrico", "Y", 7, 3.5, true, 2 },
		{ "Prop_Escotilla", "Y", 8, 2, true, 1 },
		{ "Prop_Huevos_Organicos", "X", 5, 4, false, 2 },
		-- estructuras (kit v3)
		{ "Prop_Pasarela", "X", 12, 3, true, 2 },
		{ "Prop_Columna_Rota", "Y", math.min(14, H * 0.5), 5, true, 2 },
		{ "Prop_Tabique_Ventanal", "X", 10, 2, true, 2 },
	}
	local total = 0
	for _, b in big do
		if template(b[1]) then
			total += b[6]
		end
	end
	local function pickBig()
		local r = rng:NextNumber() * total
		for _, b in big do
			if template(b[1]) then
				r -= b[6]
				if r <= 0 then
					return b
				end
			end
		end
		return big[1]
	end

	for wi, w in walls do
		local half = w.len / 2 - 6
		local tpos = -half
		while tpos <= half do
			if math.abs(tpos) >= DOOR_CLEAR and rng:NextNumber() < 0.75 then
				local b = pickBig()
				local base = w.mid + w.t * tpos + w.n * (b[4] / 2 + 0.6) + Vector3.new(0, floorY, 0)
				local cf = CFrame.lookAt(base, base + w.n) -- -Z del modelo hacia el centro; eje fino (Z) perpendicular a la pared
				place(deco, b[1], b[2], b[3] * rng:NextNumber(0.85, 1.15), cf, b[5])
			end
			tpos += rng:NextNumber(16, 22)
		end
		-- lámpara de jaula a media altura, en un cuarto de la pared (lejos del hueco)
		local side = if rng:NextNumber() < 0.5 then -1 else 1
		local lt = side * math.max(DOOR_CLEAR + 2, w.len / 4)
		if math.abs(lt) < w.len / 2 - 3 then
			local base = w.mid + w.t * lt + w.n * 0.8 + Vector3.new(0, floorY + math.min(H * 0.45, 18), 0)
			local lamp = place(deco, "Prop_Lampara_Jaula", "Y", 2.6, CFrame.lookAt(base, base + w.n), false)
			if lamp then
				local mp = lamp:FindFirstChildWhichIsA("BasePart", true) :: BasePart
				local att = Instance.new("Attachment")
				att.Name = "Luz"
				att.WorldPosition = mp.Position + w.n * 1.2
				att.Parent = mp
				local light = Instance.new("PointLight")
				light.Color = if rng:NextNumber() < 0.7 then Color3.fromRGB(255, 165, 95) else Color3.fromRGB(110, 220, 210)
				light.Range = 26
				light.Brightness = 1.4
				light.Shadows = false
				light.Parent = att
				lamp:SetAttribute("Parpadeo", rng:NextNumber() < 0.5)
				CollectionService:AddTag(lamp, "LamparaInstalacion")
			end
		end
		-- cables arrancados de un registro eléctrico, colgando en una pared de cada dos
		if wi % 2 == 1 and template("Prop_Cables_Pared") then
			local ct = -side * math.max(DOOR_CLEAR + 4, w.len / 3)
			if math.abs(ct) < w.len / 2 - 4 then
				local base = w.mid + w.t * ct + w.n * 1.5 + Vector3.new(0, floorY + math.min(H * 0.3, 14), 0)
				place(deco, "Prop_Cables_Pared", "Y", 10, CFrame.lookAt(base, base + w.n), false)
			end
		end
	end

	-- cortinas de algas colgando del techo (vegetación invasiva)
	local area = W * D
	local curtains = math.clamp(math.floor(area / 1100), 3, 12)
	for _ = 1, curtains do
		for _try = 1, 8 do
			local x = rng:NextNumber(xMin + 5, xMax - 5)
			local z = rng:NextNumber(zMin + 5, zMax - 5)
			if math.max(math.abs(x - cx), math.abs(z - cz)) >= CENTER_CLEAR then
				local cf = CFrame.new(x, ceilY, z) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
				place(deco, "Prop_Cortina_Algas", "Y", math.min(H * 0.4, 30) * rng:NextNumber(0.7, 1.1), cf, false, true)
				break
			end
		end
	end
	-- matas de algas por el suelo
	local clumps = math.clamp(math.floor(area / 800), 3, 14)
	for _ = 1, clumps do
		for _try = 1, 8 do
			local x = rng:NextNumber(xMin + 7, xMax - 7)
			local z = rng:NextNumber(zMin + 7, zMax - 7)
			if math.max(math.abs(x - cx), math.abs(z - cz)) >= CENTER_CLEAR then
				local cf = CFrame.new(x, floorY, z) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
				place(deco, "Prop_Algas_Suelo", "X", rng:NextNumber(4.5, 8), cf, false)
				break
			end
		end
	end
	local n = 0
	for _, d in deco:GetDescendants() do
		if d:IsA("BasePart") then
			n += 1
		end
	end
	return string.format("%s: %d piezas (%.0f×%.0f×%.0f)", room.Name, n, W, H, D)
end

local out = {}
for i, room in ROOT:GetChildren() do
	if room:IsA("Model") and room:FindFirstChild("Piso") then
		table.insert(out, decorate(room, 7000 + (tonumber(string.match(room.Name, "Sala_(%d+)")) or i)))
		task.wait()
	end
end
return table.concat(out, "\n")
