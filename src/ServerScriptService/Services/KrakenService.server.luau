--!strict
-- Kraken abisal (Nivel 2): enemigo que ronda libre por el mapa. Aparece en `Spawn_leviatan` tras Config.Kraken.FirstDelay,
-- patrulla puntos al azar dentro de `Bounds` esquivando estructuras, persigue a los jugadores que vea fuera del submarino y los
-- agarra con un tentáculo (los sostiene Config.Kraken.GrabSeconds y los mata); después se aleja unos segundos. Más lento que el nado del jugador: se puede esquivar.
-- Parámetros: Config.Kraken. Plantilla: AbismoAssets.Creatures.Kraken_Abisal. La animación de huesos la hace KrakenClient.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Types = require(Shared:WaitForChild("Types"))
local Runs = require(script.Parent:WaitForChild("Runs"))
local Assets = require(script.Parent:WaitForChild("Assets"))

local K = Config.Kraken
local rng = Random.new()

type Kraken = {
	code: string,
	model: Model,
	map: Instance,
	bounds: BasePart?,
	state: string, -- Hidden | Roam | Chase | Grab | Recover
	pos: Vector3,
	dir: Vector3,
	avoid: Vector3?,
	avoidUntil: number,
	probeAt: number,
	target: Vector3?, -- punto de patrulla / de huida
	stuckAt: number,
	lastDist: number,
	timer: number,
	chasing: Player?,
	reachBones: { Bone }, -- huesos de la mitad final de los tentáculos: con ellos agarra
	held: Player?,
	holdBone: Bone?,
	axis: Vector3, -- eje del cuerpo en el mundo (manto hacia arriba)
	blockedSince: number, -- desde cuándo no puede avanzar (0 = avanza)
	heading: Vector3, -- rumbo horizontal (sigue al de avance; fija si sube/baja en vertical)
	tilt: number, -- inclinación actual del cuerpo en radianes: 0 erguido, pi/2 horizontal
	tiltTarget: number,
	poseUntil: number,
	horizontal: boolean, -- postura horizontal activa al patrullar
	armed: boolean, -- true cuando los jugadores ya están en el nivel (antes solo está precargado y oculto)
	hiddenPos: Vector3,
	spawnPos: Vector3,
	params: RaycastParams,
	overlap: OverlapParams,
}

local active: Kraken? = nil

local function dbg(msg: string)
	if K.Debug then
		print("[Kraken] " .. msg)
	end
end

local function findMarker(map: Instance, names: { string }): BasePart?
	for _, n in names do
		local p = map:FindFirstChild(n, true) or workspace:FindFirstChild(n, true)
		if p and p:IsA("BasePart") then
			return p
		end
	end
	return nil
end

-- Postura: el cuerpo (eje Y del modelo, manto arriba) nunca queda con los tentáculos hacia arriba. Erguido = tentáculos colgando
-- hacia abajo, con una inclinación hacia delante; horizontal = tentáculos por delante. Mira hacia su rumbo horizontal.
local function place(k: Kraken)
	local flat = Vector3.new(k.dir.X, 0, k.dir.Z)
	if flat.Magnitude > 0.2 then
		k.heading = flat.Unit
	end
	local h = k.heading
	local up = Vector3.yAxis * math.cos(k.tilt) - h * math.sin(k.tilt) -- eje del manto (siempre con Y >= 0)
	local side = h:Cross(Vector3.yAxis).Unit
	k.axis = up
	k.model:PivotTo(CFrame.fromMatrix(k.pos, side, up, side:Cross(up)))
end

local function releaseHeld(k: Kraken)
	local prey = k.held
	if prey then
		local humanoid = prey.Character and prey.Character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.PlatformStand = false
		end
	end
	k.held, k.holdBone = nil, nil
end

local function destroy()
	if active then
		releaseHeld(active)
		active.model:Destroy()
		active = nil
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

-- Jugador de esta partida, vivo y fuera del submarino (dentro está a salvo).
local function eligibleRoot(player: Player, k: Kraken): BasePart?
	local run = Runs.GetByUser(player.UserId)
	if not run or run.code ~= k.code or run.state ~= "Level" then
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

local function inBounds(k: Kraken, p: Vector3, margin: number): boolean
	local b = k.bounds
	if not b then
		return true
	end
	local rel = b.CFrame:PointToObjectSpace(p)
	local half = b.Size / 2 - Vector3.new(margin, margin, margin)
	return math.abs(rel.X) <= half.X and math.abs(rel.Y) <= half.Y and math.abs(rel.Z) <= half.Z
end

-- Punto de patrulla al azar dentro de Bounds, sin estructuras en su radio. Sin Bounds: alrededor del punto de aparición.
local function pickRoamPoint(k: Kraken): Vector3
	local b = k.bounds
	for _ = 1, 25 do
		local p: Vector3
		if b then
			local half = b.Size / 2 - Vector3.new(K.RoamMargin, K.RoamMargin, K.RoamMargin)
			p = b.CFrame:PointToWorldSpace(Vector3.new(rng:NextNumber(-half.X, half.X), rng:NextNumber(-half.Y, half.Y), rng:NextNumber(-half.Z, half.Z)))
		else
			p = k.spawnPos + Vector3.new(rng:NextNumber(-200, 200), rng:NextNumber(-100, 100), rng:NextNumber(-200, 200))
		end
		if (p - k.pos).Magnitude > 120 and #workspace:GetPartBoundsInRadius(p, K.ProbeRadius, k.overlap) == 0 then
			return p
		end
	end
	return if b then b.Position else k.spawnPos
end

local function prepare(code: string, map: Instance)
	destroy()
	local template = Assets.Find("Kraken_Abisal") or workspace:FindFirstChild("Kraken_Abisal")
	if not template or not template:IsA("Model") then
		warn("[Kraken] Falta el modelo Kraken_Abisal (AbismoAssets.Creatures)")
		return
	end
	local spawnPart = findMarker(map, { "Spawn_leviatan", "Spawn_leviathan", "Spawn_kraken" })
	local boundsPart = map:FindFirstChild("Bounds")
	local model = template:Clone()
	local root = model.PrimaryPart or model:FindFirstChild("Root")
	if not root or not root:IsA("BasePart") then
		model:Destroy()
		return
	end
	model.PrimaryPart = root :: BasePart
	local extents = model:GetExtentsSize()
	local longest = math.max(extents.X, extents.Y, extents.Z)
	if K.Length > 0 and longest > 0 then
		model:ScaleTo(model:GetScale() * K.Length / longest)
	end
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
		end
	end
	local reachBones: { Bone } = {}
	for _, d in model:GetDescendants() do
		if d:IsA("Bone") then
			local idx = string.match(d.Name, "^Tentaculo_%d+_(%d+)$")
			if idx and (tonumber(idx) or 0) >= 4 then
				table.insert(reachBones, d)
			end
		end
	end
	model.Name = "KrakenAbisal"
	local spawnPos = if spawnPart then spawnPart.Position elseif boundsPart and boundsPart:IsA("BasePart") then boundsPart.Position else Vector3.zero
	local hiddenPos = spawnPos - Vector3.new(0, 900, 0)
	model:PivotTo(CFrame.new(hiddenPos))
	-- Persistent: se replica completo a todos los clientes desde que se crea (en el viaje), no por streaming al acercarse.
	model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	model.Parent = workspace

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { model }
	params.IgnoreWater = true
	params.RespectCanCollide = true
	local overlap = OverlapParams.new()
	overlap.FilterType = Enum.RaycastFilterType.Exclude
	overlap.FilterDescendantsInstances = { model }
	overlap.RespectCanCollide = true

	active = {
		code = code,
		model = model,
		map = map,
		bounds = if boundsPart and boundsPart:IsA("BasePart") then boundsPart else nil,
		state = "Hidden",
		pos = spawnPos,
		dir = Vector3.new(0, -0.3, -1).Unit,
		avoid = nil,
		avoidUntil = 0,
		probeAt = 0,
		target = nil,
		stuckAt = 0,
		lastDist = math.huge,
		timer = K.FirstDelay,
		chasing = nil,
		reachBones = reachBones,
		held = nil,
		holdBone = nil,
		axis = Vector3.yAxis,
		blockedSince = 0,
		heading = Vector3.zAxis,
		tilt = math.rad(K.UprightLeanDeg),
		tiltTarget = math.rad(K.UprightLeanDeg),
		poseUntil = 0,
		horizontal = false,
		armed = false,
		hiddenPos = hiddenPos,
		spawnPos = spawnPos,
		params = params,
		overlap = overlap,
	}
	dbg(string.format("precargado para %s: spawn=%s bounds=%s", code, tostring(spawnPos), tostring(boundsPart ~= nil)))
end

-- Centros de las esferas de colisión del cuerpo (manto, centro y tentáculos) para una posición dada.
local function bodySpheres(k: Kraken, pos: Vector3): { Vector3 }
	local spread = (if K.Length > 0 then K.Length else 100) * K.ProbeSpread
	return { pos, pos + k.axis * spread, pos - k.axis * spread }
end

-- ¿Algo sólido toca el cuerpo en `pos`? (solo partes con colisión: OverlapParams.RespectCanCollide)
local function blockedAt(k: Kraken, pos: Vector3): boolean
	for _, c in bodySpheres(k, pos) do
		if #workspace:GetPartBoundsInRadius(c, K.ProbeRadius * 0.85, k.overlap) > 0 then
			return true
		end
	end
	return false
end

-- Dirección con esquiva: sondea con tres esferas (todo el largo del cuerpo) por delante y se desliza por la superficie más cercana.
local function steer(k: Kraken, desired: Vector3, speed: number, now: number, dt: number): Vector3
	if now >= k.probeAt then
		k.probeAt = now + 0.1
		local look = k.dir * (K.ProbeDistance + speed * 2)
		local best: RaycastResult? = nil
		for _, c in bodySpheres(k, k.pos) do
			local hit = workspace:Spherecast(c, K.ProbeRadius, look, k.params)
			if hit and (not best or hit.Distance < best.Distance) then
				best = hit
			end
		end
		if best then
			local n = best.Normal
			local slide = desired - n * desired:Dot(n)
			local away = slide + n * 0.9
			k.avoid = if away.Magnitude > 0.01 then away.Unit else n
			k.avoidUntil = now + 1.0
		elseif now > k.avoidUntil then
			k.avoid = nil
		end
	end
	local want = if k.avoid and now < k.avoidUntil then k.avoid else desired
	local blend = 1 - math.exp(-dt * K.TurnRate * (if k.avoid then 3 else 1)) -- al esquivar gira más rápido
	local d = k.dir:Lerp(want, blend)
	return if d.Magnitude > 0.01 then d.Unit else want
end

local function setState(k: Kraken, state: string)
	if k.state ~= state then
		dbg(k.state .. " -> " .. state)
		k.state = state
	end
end

-- Mejor presa a la vista: la más cercana dentro de DetectRange (la lámpara encendida la hace más visible).
local function findPrey(k: Kraken): (Player?, BasePart?)
	local best: Player? = nil
	local bestRoot: BasePart? = nil
	local bestDist = math.huge
	for _, player in Players:GetPlayers() do
		local root = eligibleRoot(player, k)
		if root then
			local range = K.DetectRange * (if player:GetAttribute("LampOn") then K.LampDetectMultiplier else 1)
			local d = (root.Position - k.pos).Magnitude
			if d <= range and d < bestDist then
				best, bestRoot, bestDist = player, root, d
			end
		end
	end
	return best, bestRoot
end

-- Hueso de tentáculo al alcance de un jugador elegible: lo agarra, lo sostiene y lo mata pasado GrabSeconds.
local function tryGrab(k: Kraken, now: number)
	for _, player in Players:GetPlayers() do
		local root = eligibleRoot(player, k)
		if root then
			for _, bone in k.reachBones do
				if (bone.WorldCFrame.Position - root.Position).Magnitude <= K.GrabReach then
					k.held, k.holdBone = player, bone
					k.chasing = nil
					k.timer = K.GrabSeconds
					local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
					if humanoid then
						humanoid.PlatformStand = true
					end
					pcall(function()
						root:SetNetworkOwner(nil)
					end)
					root.AssemblyLinearVelocity = Vector3.zero
					setState(k, "Grab")
					return
				end
			end
		end
	end
end

-- Elige la postura: al perseguir se inclina hacia la presa; al patrullar alterna erguido (casi siempre) y horizontal (de vez en cuando).
local function updatePose(k: Kraken, now: number, dt: number)
	if k.state == "Chase" then
		k.tiltTarget = math.rad(K.ChaseLeanDeg)
		k.poseUntil = 0
	elseif now >= k.poseUntil then
		k.horizontal = rng:NextNumber() < K.HorizontalChance
		k.tiltTarget = math.rad(if k.horizontal then K.HorizontalDeg else K.UprightLeanDeg)
		k.poseUntil = now + rng:NextNumber(K.PoseMin, K.PoseMax)
	end
	k.tilt += (k.tiltTarget - k.tilt) * (1 - math.exp(-K.TiltSmoothing * dt))
end

local function step(k: Kraken, dt: number)
	local now = os.clock()
	if k.state == "Hidden" then
		if not k.armed then
			return
		end
		k.timer -= dt
		if k.timer <= 0 then
			k.pos = k.spawnPos
			k.target = pickRoamPoint(k)
			k.dir = ((k.target :: Vector3) - k.pos).Unit
			k.stuckAt = now + K.StuckSeconds
			k.lastDist = math.huge
			place(k)
			setState(k, "Roam")
		end
		return
	end

	if k.state == "Grab" then
		local prey, bone = k.held, k.holdBone
		local root = prey and playerRoot(prey)
		if not prey or not bone or not root then
			releaseHeld(k) -- se fue o murió por otra causa
			k.target = pickRoamPoint(k)
			k.timer = K.RecoverSeconds
			setState(k, "Recover")
			return
		end
		root.CFrame = CFrame.new(bone.WorldCFrame.Position)
		root.AssemblyLinearVelocity = Vector3.zero
		k.timer -= dt
		if k.timer <= 0 then
			local humanoid = prey.Character and prey.Character:FindFirstChildOfClass("Humanoid")
			releaseHeld(k)
			if humanoid then
				humanoid.Health = 0
			end
			k.target = pickRoamPoint(k)
			k.timer = K.RecoverSeconds
			k.lastDist = math.huge
			k.stuckAt = now + K.StuckSeconds
			setState(k, "Recover")
		end
		updatePose(k, now, dt)
		place(k)
		k.model:SetAttribute("KrakenSpeed", 2)
		return
	end

	-- Objetivo y velocidad según el estado.
	local goal: Vector3
	local speed: number
	if k.state == "Chase" then
		local prey = k.chasing
		local root = prey and eligibleRoot(prey, k)
		if not root or (root.Position - k.pos).Magnitude > K.DetectRange * K.LampDetectMultiplier * K.LoseRangeMultiplier then
			k.chasing = nil
			k.target = pickRoamPoint(k)
			setState(k, "Roam")
			return
		end
		goal, speed = root.Position, K.ChaseSpeed
	else
		if k.state == "Recover" then
			k.timer -= dt
			speed = K.RecoverSpeed
			if k.timer <= 0 then
				k.target = pickRoamPoint(k)
				setState(k, "Roam")
				return
			end
		else
			speed = K.RoamSpeed
			local prey = findPrey(k)
			if prey then
				k.chasing = prey
				setState(k, "Chase")
				return
			end
		end
		local target = k.target
		if not target then
			k.target = pickRoamPoint(k)
			return
		end
		local dist = (target - k.pos).Magnitude
		if dist < K.ReachDistance then
			k.target = pickRoamPoint(k)
			k.stuckAt = now + K.StuckSeconds
			k.lastDist = math.huge
			return
		end
		if dist < k.lastDist - 2 then
			k.lastDist = dist
			k.stuckAt = now + K.StuckSeconds
		elseif now > k.stuckAt then
			k.target = pickRoamPoint(k) -- atascado
			k.stuckAt = now + K.StuckSeconds
			k.lastDist = math.huge
			return
		end
		goal = target
	end

	local to = goal - k.pos
	if to.Magnitude > 0.01 then
		k.dir = steer(k, to.Unit, speed, now, dt)
	end
	local nextPos = k.pos + k.dir * speed * dt
	-- No se sale de Bounds: si el siguiente paso queda fuera, elige otro punto de patrulla.
	if k.bounds and not inBounds(k, nextPos, 20) then
		k.target = pickRoamPoint(k)
		if k.state == "Chase" then
			k.chasing = nil
			setState(k, "Roam")
		end
		return
	end
	-- Colisión dura: si el cuerpo tocaría algo sólido, no avanza; prueba a deslizarse por la esquiva y, si sigue bloqueado
	-- más de un segundo, elige otro punto de patrulla (o suelta la persecución).
	if blockedAt(k, nextPos) and not blockedAt(k, k.pos) then -- si ya está dentro de algo, se le deja salir
		local slideDir = k.avoid
		local alt = if slideDir then k.pos + slideDir * speed * dt else nil
		if alt and not blockedAt(k, alt) and inBounds(k, alt, 20) then
			nextPos = alt
			k.blockedSince = 0
		else
			nextPos = k.pos
			if k.blockedSince == 0 then
				k.blockedSince = now
			elseif now - k.blockedSince > 1 then
				k.blockedSince = 0
				k.target = pickRoamPoint(k)
				k.avoid = nil
				if k.state == "Chase" then
					k.chasing = nil
					setState(k, "Roam")
				end
				return
			end
		end
	else
		k.blockedSince = 0
	end
	k.pos = nextPos
	updatePose(k, now, dt)
	place(k)
	if k.state ~= "Recover" then
		tryGrab(k, now)
	end
	k.model:SetAttribute("KrakenSpeed", speed) -- KrakenClient lo usa para la frecuencia de la ondulación
	if K.Debug then
		k.model:SetAttribute("KrakenState", k.state)
	end
end

RunService.Heartbeat:Connect(function(dt)
	local k = active
	if k then
		local run = Runs.Get(k.code)
		if not run or run.ended then
			destroy()
			return
		end
		step(k, dt)
	end
end)

-- La sala grande generada (Workspace.NivelGenerado.big_<n>); el kraken ronda solo dentro de su Bounds.
local function bigRoom(): Instance?
	local level = workspace:FindFirstChild("NivelGenerado")
	if level then
		for _, c in level:GetChildren() do
			if string.sub(c.Name, 1, 4) == "big_" then
				return c
			end
		end
	end
	return nil
end

-- Aparece al entrar al nivel (Level): se precarga oculto y se arma con su cuenta atrás. Ya no depende de las etapas fijas.
Runs.StateChanged:Connect(function(code: string, state: Types.RunState)
	local run = Runs.Get(code)
	if not run then
		return
	end
	if state == "Level" then
		local room = bigRoom()
		if room then
			if not active or active.code ~= code then
				prepare(code, room)
			end
			if active then
				active.armed = true
				active.timer = K.FirstDelay
			end
		else
			destroy()
		end
	elseif state == "Descending" or state == "Stopover" or state == "Won" or state == "Lost" then
		destroy()
	end
end)
