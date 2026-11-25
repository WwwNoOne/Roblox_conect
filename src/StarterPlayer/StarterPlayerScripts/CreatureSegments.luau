--!strict
--!native
-- Corta la malla de una criatura (un solo MeshPart generado con ForgeGUI) en N trozos rígidos a lo largo de un eje, una vez por
-- malla y en el cliente (EditableMesh). Cada trozo se convierte en un MeshPart propio que CreatureAnimator mueve como una
-- cadena: ondas de nado, latido de medusa, ondulación al reptar. Mover N piezas por fotograma es casi gratis; deformar los
-- ~25 000 vértices de la malla cada fotograma costaba ~15 ms.
local AssetService = game:GetService("AssetService")

local CreatureSegments = {}

export type Segment = {
	mesh: EditableMesh,
	center: Vector3, -- centro de la caja del trozo, en el espacio de la malla
	size: Vector3, -- tamaño de la caja del trozo, en el espacio de la malla
	u: number, -- posición normalizada del centro a lo largo del eje (0 = cabeza, 1 = cola)
}

export type Cut = {
	segments: { Segment },
	meshSize: Vector3, -- caja de la malla completa (espacio de la malla)
	meshCenter: Vector3,
}

local cache: { [string]: Cut | false } = {}
local users: { [string]: number } = {}
local busy = false -- se corta una malla cada vez (el presupuesto de memoria de EditableMesh del cliente es pequeño)

local AXES = { X = Vector3.xAxis, Y = Vector3.yAxis, Z = Vector3.zAxis }

-- Depuración: workspace:SetAttribute("DebugNoEditableMesh", true) simula que el cliente se quedó sin memoria de
-- EditableMesh para comprobar el fallback de cuerpo entero (CreatureAnimator.setupRigid).
local function forcedFallback(): boolean
	return workspace:GetAttribute("DebugNoEditableMesh") == true
end

-- axis: "X" | "Y" | "Z"; headSign: -1 si la cabeza está en el lado negativo del eje (Z de las criaturas: cabeza en -Z).
local function build(meshId: string, count: number, axis: string, headSign: number): Cut?
	if forcedFallback() then
		warn("[CreatureSegments] fallback forzado (DebugNoEditableMesh); se usa la malla original")
		return nil
	end
	local okSrc, src = pcall(function()
		return AssetService:CreateEditableMeshAsync(Content.fromUri(meshId), { FixedSize = true })
	end)
	if not okSrc or not src then
		warn("[CreatureSegments] no se pudo abrir la malla " .. meshId .. ": " .. tostring(src))
		return nil
	end
	local a = AXES[axis] or Vector3.zAxis

	-- 1) Copia la malla original a tablas y la libera antes de crear los trozos (menos memoria de pico).
	local pos: { [number]: Vector3 } = {}
	local vmin, vmax = Vector3.one * math.huge, -Vector3.one * math.huge
	for i, id in src:GetVertices() do
		local p = src:GetPosition(id)
		pos[id] = p
		vmin, vmax = vmin:Min(p), vmax:Max(p)
		if i % 4000 == 0 then
			task.wait()
		end
	end
	local uvs: { [number]: Vector2 } = {}
	local normals: { [number]: Vector3 } = {}
	local faceV: { { number } } = {}
	local faceUV: { { number } } = {}
	local faceN: { { number } } = {}
	for i, f in src:GetFaces() do
		faceV[i] = src:GetFaceVertices(f)
		local fu = src:GetFaceUVs(f)
		faceUV[i] = fu
		for _, id in fu do
			if not uvs[id] then
				uvs[id] = src:GetUV(id) :: Vector2
			end
		end
		local fn = src:GetFaceNormals(f)
		faceN[i] = fn
		for _, id in fn do
			if not normals[id] then
				normals[id] = src:GetNormal(id) :: Vector3
			end
		end
		if i % 3000 == 0 then
			task.wait()
		end
	end
	src:Destroy()

	local lo, hi = vmin:Dot(a), vmax:Dot(a)
	local span = math.max(hi - lo, 1e-4)
	-- u = 0 en la cabeza, 1 en la cola
	local function uOf(p: Vector3): number
		local t = (p:Dot(a) - lo) / span
		return if headSign < 0 then t else 1 - t
	end

	-- 2) Trozos.
	local meshes: { EditableMesh } = {}
	local function cleanup()
		for _, m in meshes do
			m:Destroy()
		end
	end
	-- El cliente admite pocos EditableMesh a la vez (8 medidos, compartidos entre todas las criaturas): si falta memoria para el
	-- trozo k se corta en k-1 (mínimo 2); por debajo de eso, fallback de cuerpo entero.
	for k = 1, count do
		local okM, m = pcall(AssetService.CreateEditableMesh, AssetService, { FixedSize = false })
		if not okM or not m then
			if k - 1 < 2 then
				warn("[CreatureSegments] sin memoria para EditableMesh; se usa la malla original")
				cleanup()
				return nil
			end
			warn(string.format("[CreatureSegments] memoria justa: se corta en %d trozos en vez de %d", k - 1, count))
			count = k - 1
			break
		end
		meshes[k] = m
	end
	local vmap: { { [number]: number } } = {}
	local uvmap: { { [number]: number } } = {}
	local nmap: { { [number]: number } } = {}
	local bmin: { Vector3 } = {}
	local bmax: { Vector3 } = {}
	for k = 1, count do
		vmap[k], uvmap[k], nmap[k] = {}, {}, {}
		bmin[k], bmax[k] = Vector3.one * math.huge, -Vector3.one * math.huge
	end
	for i, fv in faceV do
		local p1, p2, p3 = pos[fv[1]], pos[fv[2]], pos[fv[3]]
		local k = math.clamp(math.floor(uOf((p1 + p2 + p3) / 3) * count) + 1, 1, count)
		local dst = meshes[k]
		local vm = vmap[k]
		local ids = table.create(3)
		for j = 1, 3 do
			local sid = fv[j]
			local nid = vm[sid]
			if not nid then
				local p = pos[sid]
				nid = dst:AddVertex(p)
				vm[sid] = nid
				bmin[k], bmax[k] = bmin[k]:Min(p), bmax[k]:Max(p)
			end
			ids[j] = nid
		end
		local nf = dst:AddTriangle(ids[1], ids[2], ids[3])
		local fuv = faceUV[i]
		if #fuv == 3 then
			local um = uvmap[k]
			local out = table.create(3)
			for j = 1, 3 do
				local id = um[fuv[j]]
				if not id then
					id = dst:AddUV(uvs[fuv[j]])
					um[fuv[j]] = id
				end
				out[j] = id
			end
			dst:SetFaceUVs(nf, out)
		end
		local fn = faceN[i]
		if #fn == 3 then
			local nm = nmap[k]
			local out = table.create(3)
			for j = 1, 3 do
				local id = nm[fn[j]]
				if not id then
					id = dst:AddNormal(normals[fn[j]])
					nm[fn[j]] = id
				end
				out[j] = id
			end
			dst:SetFaceNormals(nf, out)
		end
		if i % 3000 == 0 then
			task.wait()
		end
	end

	local segments: { Segment } = {}
	for k = 1, count do
		if bmin[k].X < math.huge then
			local c = (bmin[k] + bmax[k]) / 2
			-- Centra el trozo en su origen: CreateMeshPartAsync no recentra la malla, así el centro del MeshPart es el del trozo.
			local dst = meshes[k]
			for _, vid in dst:GetVertices() do
				dst:SetPosition(vid, dst:GetPosition(vid) - c)
			end
			task.wait()
			table.insert(segments, { mesh = meshes[k], center = c, size = bmax[k] - bmin[k], u = uOf(c) })
		else
			meshes[k]:Destroy()
		end
	end
	return { segments = segments, meshSize = vmax - vmin, meshCenter = (vmin + vmax) / 2 }
end

local function keyOf(meshId: string, count: number, axis: string, headSign: number): string
	return string.format("%s|%d|%s|%d", meshId, count, axis, headSign)
end

-- Devuelve el corte (cacheado por malla y parámetros) y suma un usuario; liberar con Release. Cede mientras corta.
function CreatureSegments.Get(meshId: string, count: number, axis: string, headSign: number): Cut?
	local key = keyOf(meshId, count, axis, headSign)
	while busy do
		task.wait()
	end
	local c = cache[key]
	if c == nil then
		busy = true
		local ok, result = pcall(build, meshId, count, axis, headSign)
		busy = false
		if not ok then
			warn("[CreatureSegments] " .. tostring(result))
		end
		c = if ok and result then result else false
		-- un fallo por memoria no se cachea para siempre: se reintenta en la próxima criatura
		cache[key] = if c then c else nil
	end
	if c then
		users[key] = (users[key] or 0) + 1
		return c
	end
	return nil
end

-- Resta un usuario; sin usuarios, destruye los EditableMesh del corte para devolver memoria.
function CreatureSegments.Release(meshId: string, count: number, axis: string, headSign: number)
	local key = keyOf(meshId, count, axis, headSign)
	local n = (users[key] or 0) - 1
	if n > 0 then
		users[key] = n
		return
	end
	users[key] = nil
	local c = cache[key]
	cache[key] = nil
	if c then
		for _, seg in c.segments do
			seg.mesh:Destroy()
		end
	end
end

-- Crea los MeshPart de un corte para un MeshPart original (copia su SurfaceAppearance y escala).
-- Devuelve una lista paralela a cut.segments; las piezas quedan sin padre.
function CreatureSegments.MakeParts(cut: Cut, original: MeshPart): { MeshPart }
	local scale = original.Size / cut.meshSize
	local surface = original:FindFirstChildOfClass("SurfaceAppearance")
	local parts: { MeshPart } = {}
	for i, seg in cut.segments do
		local ok, part = pcall(function()
			return AssetService:CreateMeshPartAsync(Content.fromObject(seg.mesh), {
				CollisionFidelity = Enum.CollisionFidelity.Box,
				RenderFidelity = Enum.RenderFidelity.Precise,
			})
		end)
		if ok and part then
			part.Size = seg.size * scale
			part.Anchored = true
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
			part.CastShadow = original.CastShadow
			part.Material = original.Material
			part.Color = original.Color
			if surface then
				surface:Clone().Parent = part
			else
				part.TextureID = original.TextureID
			end
			part.Name = "Seg" .. i
			parts[i] = part
		else
			warn("[CreatureSegments] CreateMeshPartAsync: " .. tostring(part))
			for _, p in parts do
				p:Destroy()
			end
			return {}
		end
	end
	return parts
end

return CreatureSegments
