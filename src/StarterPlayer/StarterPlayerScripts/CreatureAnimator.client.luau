--!strict
-- Animación procedural de las criaturas generadas con ForgeGUI (sin huesos ni animaciones publicadas: ForgeGUI no puede
-- subir animaciones a Roblox). El servidor mueve el modelo (MonsterService) y le pone la etiqueta "ProcCreature" y el atributo
-- ProcAnim = nombre de perfil de Config.CreatureAnim. Aquí se oculta la malla original y se dibuja cortada en trozos que se
-- mueven como una cadena (nado, latido, reptar). Si la malla no se puede cortar, se deja la original tal cual.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local CreatureSegments = require(script.Parent:WaitForChild("CreatureSegments"))

local TAG = "ProcCreature"
local MAX_DISTANCE = 400 -- más lejos no se anima (las piezas siguen al cuerpo en reposo)

type Profile = {
	Axis: string, -- eje largo de la malla ("X" | "Y" | "Z")
	HeadSign: number, -- -1 si la cabeza está en el lado negativo del eje
	Segments: number,
	Mode: string, -- "swim" | "jelly" | "crawl"
	Amplitude: number, -- fracción del largo
	Frequency: number, -- ciclos por segundo en reposo
	Wavelength: number, -- ondas a lo largo del cuerpo
	Power: number, -- cuánto se concentra el movimiento hacia la cola (0 = uniforme)
	Rigid: number?, -- fracción del cuerpo desde la cabeza que no se mueve (cabeza rígida)
}

type Live = {
	model: Model,
	body: MeshPart,
	profile: Profile,
	parts: { MeshPart },
	offsets: { Vector3 }, -- centro de cada pieza respecto al centro del cuerpo (espacio del cuerpo, ya escalado)
	us: { number },
	sizes: { Vector3 },
	length: number,
	phase: number,
	lastPos: Vector3,
	speed: number,
	folder: Folder,
	meshId: string,
	rigid: boolean, -- true: una sola copia de la malla movida en bloque (no se pudo cortar)
}

local live: { [Model]: Live } = {}
local pending: { [Model]: boolean } = {}

local folder = Instance.new("Folder")
folder.Name = "CreatureVisuals"
folder.Parent = workspace

local function findBody(model: Model): MeshPart?
	local named = model:FindFirstChild("Body", true)
	if named and named:IsA("MeshPart") then
		return named
	end
	return model:FindFirstChildWhichIsA("MeshPart", true)
end

local function setupRigid(model: Model, body: MeshPart, profile: Profile)
	local copy = body:Clone()
	for _, c in copy:GetChildren() do
		if not c:IsA("SurfaceAppearance") and not c:IsA("Attachment") then
			c:Destroy()
		end
	end
	copy.Anchored = true
	copy.CanCollide = false
	copy.CanQuery = false
	copy.CanTouch = false
	copy.LocalTransparencyModifier = 0
	local sub = Instance.new("Folder")
	sub.Name = model.Name
	copy.Parent = sub
	sub.Parent = folder
	body.LocalTransparencyModifier = 1
	local axisVec = if profile.Axis == "X" then Vector3.xAxis elseif profile.Axis == "Y" then Vector3.yAxis else Vector3.zAxis
	live[model] = {
		model = model,
		body = body,
		profile = profile,
		parts = { copy },
		offsets = { Vector3.zero },
		us = { 0.5 },
		sizes = { copy.Size },
		length = (body.Size * axisVec).Magnitude,
		phase = math.random() * 10,
		lastPos = body.Position,
		speed = 0,
		folder = sub,
		meshId = body.MeshId,
		rigid = true,
	}
end

local function setup(model: Model)
	if live[model] or pending[model] then
		return
	end
	local profileName = model:GetAttribute("ProcAnim")
	local profiles = (Config :: any).CreatureAnim
	local profile = if type(profileName) == "string" and profiles then profiles[profileName] else nil
	if not profile then
		return
	end
	pending[model] = true
	local body = findBody(model)
	local t0 = os.clock()
	while not body and os.clock() - t0 < 10 and model.Parent do
		task.wait(0.2)
		body = findBody(model)
	end
	if not body or not model.Parent then
		pending[model] = nil
		return
	end
	local cut = CreatureSegments.Get(body.MeshId, profile.Segments, profile.Axis, profile.HeadSign)
	if not model.Parent then
		if cut then
			CreatureSegments.Release(body.MeshId, profile.Segments, profile.Axis, profile.HeadSign)
		end
		pending[model] = nil
		return
	end
	local parts: { MeshPart } = {}
	if cut then
		parts = CreatureSegments.MakeParts(cut, body)
		if #parts == 0 then
			CreatureSegments.Release(body.MeshId, profile.Segments, profile.Axis, profile.HeadSign)
			cut = nil
		end
	end
	if not cut then
		-- Sin memoria para cortar la malla: copia entera que se mueve en bloque (vaivén, latido o balanceo).
		setupRigid(model, body, profile)
		pending[model] = nil
		return
	end
	local scale = body.Size / (cut :: any).meshSize
	local sub = Instance.new("Folder")
	sub.Name = model.Name
	local offsets, us, sizes = {}, {}, {}
	for i, seg in (cut :: any).segments do
		offsets[i] = (seg.center - cut.meshCenter) * scale
		us[i] = seg.u
		sizes[i] = parts[i].Size
		parts[i].CFrame = body.CFrame * CFrame.new(offsets[i])
		parts[i].Parent = sub
	end
	sub.Parent = folder
	body.LocalTransparencyModifier = 1
	local axisVec = if profile.Axis == "X" then Vector3.xAxis elseif profile.Axis == "Y" then Vector3.yAxis else Vector3.zAxis
	live[model] = {
		model = model,
		body = body,
		profile = profile,
		parts = parts,
		offsets = offsets,
		us = us,
		sizes = sizes,
		length = (body.Size * axisVec).Magnitude,
		phase = math.random() * 10,
		lastPos = body.Position,
		speed = 0,
		folder = sub,
		meshId = body.MeshId,
		rigid = false,
	}
	pending[model] = nil
end

local function teardown(model: Model)
	local l = live[model]
	if l then
		l.folder:Destroy()
		if l.body.Parent then
			l.body.LocalTransparencyModifier = 0
		end
		live[model] = nil
		if not l.rigid then
			local p = l.profile
			CreatureSegments.Release(l.meshId, p.Segments, p.Axis, p.HeadSign)
		end
	end
end

-- Ejes laterales de la onda según el eje largo.
local function lateralAxes(axis: string): (Vector3, Vector3)
	if axis == "X" then
		return Vector3.zAxis, Vector3.yAxis
	elseif axis == "Y" then
		return Vector3.xAxis, Vector3.zAxis
	end
	return Vector3.xAxis, Vector3.yAxis -- eje Z: lado = X, arriba = Y
end

local function animate(l: Live, dt: number, camPos: Vector3)
	local body = l.body
	local base = body.CFrame
	local pos = base.Position
	local v = (pos - l.lastPos).Magnitude / math.max(dt, 1e-3)
	l.lastPos = pos
	l.speed += (v - l.speed) * math.min(1, dt * 4)
	local p = l.profile
	local far = (pos - camPos).Magnitude > MAX_DISTANCE
	-- más rápido al correr: la frecuencia sube con la velocidad
	local freq = p.Frequency * (1 + math.clamp(l.speed / 20, 0, 1.6))
	l.phase += dt * freq * math.pi * 2
	local side, up = lateralAxes(p.Axis)
	local amp = p.Amplitude * l.length
	local rigid = p.Rigid or 0
	local cfs = table.create(#l.parts)
	for i, part in l.parts do
		local u = l.us[i]
		local off = l.offsets[i]
		local cf: CFrame
		if l.rigid then
			-- en bloque: vaivén lateral del cuerpo, latido (medusa) o balanceo al reptar
			local a = l.phase
			if far then
				cf = base
			elseif p.Mode == "jelly" then
				local pulse = 1 + 0.08 * math.sin(a)
				part.Size = l.sizes[i] * Vector3.new(pulse, 1 / pulse, pulse)
				cf = base * CFrame.new(Vector3.yAxis * math.sin(a) * amp * 0.15) * CFrame.fromAxisAngle(side, math.sin(a * 0.5) * 0.06)
			elseif p.Mode == "crawl" then
				cf = base * CFrame.new(up * math.abs(math.sin(a)) * amp) * CFrame.fromAxisAngle(side, math.sin(a) * 0.03)
			else
				cf = base * CFrame.fromAxisAngle(up, math.sin(a) * 0.12) * CFrame.fromAxisAngle(if p.Axis == "X" then Vector3.xAxis elseif p.Axis == "Y" then Vector3.yAxis else Vector3.zAxis, math.sin(a + 1) * 0.05)
			end
		elseif far then
			cf = base * CFrame.new(off)
		elseif p.Mode == "jelly" then
			-- campana (u pequeño) late; tentáculos se mecen en dos ejes con retraso
			local w = math.max(0, u - rigid) / math.max(1 - rigid, 1e-3)
			local k = w ^ math.max(p.Power, 0.01)
			local a = l.phase - p.Wavelength * u * math.pi * 2
			local sway = side * math.sin(a) * amp * k + up * math.cos(a * 0.8) * amp * k
			local lift = math.sin(l.phase) * amp * 0.15 -- el cuerpo sube un poco en cada latido
			cf = base * CFrame.new(off + sway + Vector3.yAxis * lift) * CFrame.fromAxisAngle(side, math.cos(a) * 0.25 * k)
			if u < rigid + 0.15 then
				local pulse = 1 + 0.12 * math.sin(l.phase)
				part.Size = l.sizes[i] * Vector3.new(pulse, 1 / pulse, pulse)
			end
		elseif p.Mode == "crawl" then
			-- ondulación vertical a lo largo del cuerpo (patas/caparazón) y un ligero vaivén
			local a = l.phase - p.Wavelength * u * math.pi * 2
			local k = 0.4 + 0.6 * u ^ math.max(p.Power, 0.01)
			cf = base * CFrame.new(off + up * math.sin(a) * amp * k) * CFrame.fromAxisAngle(side, math.cos(a) * 0.06)
		else
			-- nado: onda lateral que crece hacia la cola; cada trozo gira según la pendiente de la onda
			local w = math.max(0, u - rigid) / math.max(1 - rigid, 1e-3)
			local k = w ^ math.max(p.Power, 0.01)
			local a = l.phase - p.Wavelength * u * math.pi * 2
			local lateral = math.sin(a) * amp * k
			local slope = math.cos(a) * amp * k * p.Wavelength * math.pi * 2 / math.max(l.length, 1e-3)
			cf = base * CFrame.new(off + side * lateral) * CFrame.fromAxisAngle(up, -math.atan(slope) * p.HeadSign)
		end
		cfs[i] = cf
	end
	workspace:BulkMoveTo(l.parts, cfs, Enum.BulkMoveMode.FireCFrameChanged)
end

RunService.RenderStepped:Connect(function(dt)
	local cam = workspace.CurrentCamera
	local camPos = if cam then cam.CFrame.Position else Vector3.zero
	for model, l in live do
		if not model.Parent or not l.body.Parent then
			teardown(model)
		else
			animate(l, dt, camPos)
		end
	end
end)

for _, inst in CollectionService:GetTagged(TAG) do
	if inst:IsA("Model") then
		task.spawn(setup, inst)
	end
end
CollectionService:GetInstanceAddedSignal(TAG):Connect(function(inst)
	if inst:IsA("Model") then
		task.spawn(setup, inst)
	end
end)
CollectionService:GetInstanceRemovedSignal(TAG):Connect(function(inst)
	if inst:IsA("Model") then
		teardown(inst)
	end
end)
