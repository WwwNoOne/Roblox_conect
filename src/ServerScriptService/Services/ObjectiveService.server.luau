--!strict
-- Objetivos del nivel (GDD §3): generadores que reparar y cajas fuertes que abrir. Servidor autoritativo; parámetros en
-- Config.Objectives. Al empezar un nivel (Runs.StateChanged "Level") coloca los modelos (Props) en los marcadores del mapa cargado:
--   * MachineSpawn -> generador. Se reparan Needed (según jugadores) de los que aparecen; hasta entonces Runs no deja bajar (POWER_OFF).
--   * PuzzleSpawn cuyo Part padre empieza por "Cofre" -> caja fuerte con combinación aleatoria y botín dentro (TreasureSpawner).
--   * PuzzleSpawn cuyo Part padre empieza por "Puerta" -> persiana en el vano, con panel de interruptores a cada lado (atajo).
-- El minijuego lo dibuja PuzzleClient; aquí se valida cada acción (PuzzleAction). Un objeto solo lo usa un jugador a la vez.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Types = require(Shared:WaitForChild("Types"))
local Runs = require(script.Parent:WaitForChild("Runs"))
local Props = require(script.Parent:WaitForChild("Props"))
local TreasureSpawner = require(script.Parent:WaitForChild("TreasureSpawner"))
local Noise = require(script.Parent:WaitForChild("Noise"))

local O = Config.Objectives
local G = O.Generator
local S = O.Safe
local D = O.Door

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local puzzleOpen = remotes:WaitForChild("PuzzleOpen") :: RemoteEvent
local puzzleClose = remotes:WaitForChild("PuzzleClose") :: RemoteEvent
local puzzleAction = remotes:WaitForChild("PuzzleAction") :: RemoteFunction

local folder = Instance.new("Folder")
folder.Name = "RunObjectives"
folder.Parent = workspace

local RED = Color3.fromRGB(220, 50, 40)
local AMBER = Color3.fromRGB(230, 170, 50)
local GREEN = Color3.fromRGB(90, 220, 110)

type Generator = {
	kind: "Generator",
	id: string,
	label: string,
	model: Model,
	prompt: ProximityPrompt,
	done: number, -- pasos de calibración conseguidos
	repaired: boolean,
	operator: Player?,
	challenge: Types.GeneratorChallenge?,
	lastHit: number,
}

type Safe = {
	kind: "Safe",
	id: string,
	label: string,
	model: Model,
	prompt: ProximityPrompt,
	combo: { number },
	step: number, -- número de la combinación que toca (1..Steps)
	opened: boolean,
	operator: Player?,
	lockedUntil: number, -- hora de servidor
	probes: { [Player]: { t: number, n: number } },
}

type Door = {
	kind: "Door",
	id: string,
	label: string,
	model: Model,
	prompt: ProximityPrompt,
	prompts: { ProximityPrompt },
	height: number,
	lights: { boolean },
	presses: number,
	opened: boolean,
	operator: Player?,
	lockedUntil: number,
	lastPress: number,
}

type Objective = Generator | Safe | Door

local objectives: { [string]: Objective } = {}
local activeRun: string? = nil -- código de la partida dueña del nivel cargado
local rng = Random.new()

local function now(): number
	return workspace:GetServerTimeNow()
end

local function notice(player: Player, text: string)
	player:SetAttribute("HudNotice", text .. "|" .. tostring(os.clock()))
end

local function noticeRun(text: string)
	local run = activeRun and Runs.Get(activeRun)
	if not run then
		return
	end
	for _, userId in run.members do
		local p = Players:GetPlayerByUserId(userId)
		if p then
			notice(p, text)
		end
	end
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if humanoid and humanoid.Health > 0 and root and root:IsA("BasePart") then
		return root
	end
	return nil
end

-- Una puerta tiene un panel (y un PromptAttachment) a cada lado: vale cualquiera.
local function inReach(player: Player, o: Objective, extra: number): boolean
	local root = rootOf(player)
	if not root then
		return false
	end
	local any = false
	for _, d in o.model:GetDescendants() do
		if d:IsA("Attachment") and d.Name == "PromptAttachment" then
			any = true
			if (root.Position - d.WorldPosition).Magnitude <= O.UseDistance + extra then
				return true
			end
		end
	end
	return not any and (root.Position - o.model:GetPivot().Position).Magnitude <= O.UseDistance + extra
end

local function setLight(model: Model, color: Color3)
	local light = model:FindFirstChild("StatusLight", true)
	if light and light:IsA("BasePart") then
		light.Color = color
		local pl = light:FindFirstChildOfClass("PointLight")
		if pl then
			pl.Color = color
		end
	end
end

local function playSound(model: Model, name: string)
	local s = model:FindFirstChild(name, true)
	if s and s:IsA("Sound") then
		s:Play()
	end
end

local function release(o: Objective, reason: string?)
	local p = o.operator
	o.operator = nil
	o.model:SetAttribute("Operator", nil)
	if p and reason then
		puzzleClose:FireClient(p, o.id, reason)
	end
end

-- ===== Generadores =====
local function setScreen(g: Generator, text: string, color: Color3)
	local screen = g.model:FindFirstChild("Screen", true)
	local label = screen and screen:FindFirstChild("Label", true)
	if label and label:IsA("TextLabel") then
		label.Text = text
		label.TextColor3 = color
	end
end

local function newChallenge(g: Generator): Types.GeneratorChallenge
	local i = math.clamp(g.done + 1, 1, G.Steps)
	local width = G.ZoneWidth[math.min(i, #G.ZoneWidth)]
	local c: Types.GeneratorChallenge = {
		t0 = now(),
		period = G.Period[math.min(i, #G.Period)],
		center = rng:NextNumber(width / 2 + 0.08, 1 - width / 2 - 0.08),
		width = width,
	}
	g.challenge = c
	return c
end

-- Posición de la aguja (0..1, ida y vuelta) en la hora de servidor t.
local function needleAt(c: Types.GeneratorChallenge, t: number): number
	local x = math.max(0, t - c.t0) / c.period
	local m = x % 2
	return if m <= 1 then m else 2 - m
end

local function refreshGenerator(g: Generator)
	g.model:SetAttribute("Progress", g.done / G.Steps)
	g.model:SetAttribute("State", if g.repaired then "Repaired" else "Broken")
	if g.repaired then
		setLight(g.model, GREEN)
		setScreen(g, "EN LÍNEA", GREEN)
	elseif g.done > 0 then
		setLight(g.model, AMBER)
		setScreen(g, string.format("FASE %d/%d", g.done, G.Steps), AMBER)
	else
		setLight(g.model, RED)
		setScreen(g, "SIN ENERGÍA", RED)
	end
end

local function powerCount(): (number, number)
	local run = activeRun and Runs.Get(activeRun)
	if not run then
		return 0, 0
	end
	return run.powerDone, run.powerNeeded
end

local function completeGenerator(g: Generator, by: Player)
	g.repaired = true
	g.prompt.Enabled = false
	refreshGenerator(g)
	local hum = g.model:FindFirstChild("Hum", true)
	if hum and hum:IsA("Sound") then
		hum:Play()
	end
	local runSmoke = g.model:FindFirstChild("ExhaustSmoke", true)
	local brokenSmoke = g.model:FindFirstChild("BrokenSmoke", true)
	if runSmoke and runSmoke:IsA("ParticleEmitter") then
		runSmoke.Enabled = true
	end
	if brokenSmoke and brokenSmoke:IsA("ParticleEmitter") then
		brokenSmoke.Enabled = false
	end
	local glow = g.model:FindFirstChild("PowerGlow", true)
	if glow and glow:IsA("PointLight") then
		glow.Enabled = true
	end
	Noise.Emit(g.model:GetPivot().Position, G.RepairedNoiseRadius, "Generator")
	local run = activeRun and Runs.Get(activeRun)
	if run then
		run.powerDone += 1
		local done, needed = run.powerDone, run.powerNeeded
		if done == needed then
			noticeRun("Energía restablecida: el ascensor ya puede bajar")
			workspace:SetAttribute("PowerRestored", true)
		elseif done < needed then
			noticeRun(string.format("%s reparó %s (%d/%d)", by.DisplayName, g.label, done, needed))
		else
			notice(by, g.label .. " en línea (energía extra)")
		end
	end
end

local function openGenerator(g: Generator, player: Player)
	local data: Types.GeneratorOpen = {
		label = g.label,
		steps = G.Steps,
		done = g.done,
		challenge = newChallenge(g),
	}
	puzzleOpen:FireClient(player, "Generator", g.id, data)
end

local function generatorHit(g: Generator, player: Player, t: unknown): { [string]: any }
	local c = g.challenge
	if g.repaired or not c then
		return { ok = false, err = "DONE" }
	end
	local serverNow = now()
	if serverNow - g.lastHit < G.HitCooldown then
		return { ok = false, err = "TOO_FAST" }
	end
	g.lastHit = serverNow
	-- La marca del cliente solo se acepta dentro de un margen; si no, se usa la del servidor.
	local at = if type(t) == "number" and t == t then math.clamp(t, serverNow - G.MaxClockSkew, serverNow + 0.05) else serverNow
	local needle = needleAt(c, at)
	local hit = math.abs(needle - c.center) <= c.width / 2 + G.Tolerance
	if hit then
		g.done += 1
	else
		g.done = math.max(0, g.done - G.MissPenalty)
		g.model:SetAttribute("SparkAt", serverNow) -- ObjectiveFx: chispas y sacudida
		playSound(g.model, "Spark")
		Noise.Emit(g.model:GetPivot().Position, G.NoiseRadius, "Generator")
	end
	if g.done >= G.Steps then
		completeGenerator(g, player)
		release(g, "Done")
		return { ok = true, hit = true, done = g.done, finished = true }
	end
	refreshGenerator(g)
	return { ok = true, hit = hit, done = g.done, finished = false, needle = needle, challenge = newChallenge(g) }
end

-- ===== Cajas fuertes =====
local function makeCombo(): { number }
	local combo: { number } = {}
	for i = 1, S.Steps do
		local n: number
		repeat
			n = rng:NextInteger(0, S.Numbers - 1)
			local prev = combo[i - 1]
			local gap = if prev then math.min(math.abs(n - prev), S.Numbers - math.abs(n - prev)) else S.Numbers
		until gap >= S.MinGap
		combo[i] = n
	end
	return combo
end

local function openSafeDoor(s: Safe)
	local door = s.model:FindFirstChild("Door")
	local hinge = door and door:FindFirstChild("Hinge", true)
	if not door or not door:IsA("Model") or not hinge or not hinge:IsA("Attachment") then
		return
	end
	local closed = door:GetPivot()
	local hingeCf = hinge.WorldCFrame
	local rel = hingeCf:Inverse() * closed
	local alpha = Instance.new("NumberValue")
	local conn = alpha.Changed:Connect(function(a: number)
		door:PivotTo(hingeCf * CFrame.Angles(0, math.rad(105) * a, 0) * rel)
	end)
	local tween = TweenService:Create(alpha, TweenInfo.new(S.OpenSeconds, Enum.EasingStyle.Back, Enum.EasingDirection.Out, 0, false, 0.35), { Value = 1 })
	tween.Completed:Once(function()
		conn:Disconnect()
		alpha:Destroy()
	end)
	tween:Play()
	-- Ya abierta, la puerta no estorba al recoger el botín.
	for _, d in door:GetDescendants() do
		if d:IsA("BasePart") then
			d.CanCollide = false
		end
	end
end

local function completeSafe(s: Safe, by: Player)
	s.opened = true
	s.prompt.Enabled = false
	s.model:SetAttribute("State", "Open")
	setLight(s.model, GREEN)
	playSound(s.model, "Open")
	local inner = s.model:FindFirstChild("InteriorLight", true)
	if inner and inner:IsA("PointLight") then
		inner.Enabled = true
	end
	task.delay(0.35, function()
		openSafeDoor(s)
	end)
	-- Botín dentro: un tesoro por punto (LootPoint, LootPoint2...), a escala del hueco.
	local points: { Attachment } = {}
	for _, d in s.model:GetDescendants() do
		if d:IsA("Attachment") and string.sub(d.Name, 1, 9) == "LootPoint" then
			table.insert(points, d)
		end
	end
	table.sort(points, function(a, b)
		return a.Name < b.Name
	end)
	local yaw = select(2, s.model:GetPivot():ToEulerAnglesYXZ())
	for i, tier in S.Loot do
		local p = points[i]
		if p then
			TreasureSpawner.Spawn(p.WorldPosition, tier, { maxSize = Vector3.new(2.6, 1.6, 2.2), yaw = yaw })
		end
	end
	notice(by, s.label .. " abierta")
end

local function openSafe(s: Safe, player: Player)
	local data: Types.SafeOpen = {
		label = s.label,
		numbers = S.Numbers,
		steps = S.Steps,
		step = s.step,
		lockedUntil = s.lockedUntil,
	}
	puzzleOpen:FireClient(player, "Safe", s.id, data)
end

local function safeProbe(s: Safe, player: Player, value: unknown): { [string]: any }
	if s.opened or type(value) ~= "number" then
		return { ok = false }
	end
	-- Límite de consultas por segundo (evita barrer el dial por fuerza bruta).
	local t = os.clock()
	local rec = s.probes[player]
	if not rec or t - rec.t >= 1 then
		rec = { t = t, n = 0 }
		s.probes[player] = rec
	end
	rec.n += 1
	if rec.n > S.ProbesPerSecond then
		return { ok = false, err = "TOO_FAST" }
	end
	local v = math.floor(value) % S.Numbers
	local click = v == s.combo[s.step]
	if click then
		playSound(s.model, "Click") -- también lo oyen los demás (sonido 3D)
	end
	return { ok = true, click = click }
end

local function safeLock(s: Safe, player: Player, value: unknown): { [string]: any }
	if s.opened or type(value) ~= "number" then
		return { ok = false }
	end
	if now() < s.lockedUntil then
		return { ok = false, err = "LOCKED", lockedUntil = s.lockedUntil }
	end
	local v = math.floor(value) % S.Numbers
	if v == s.combo[s.step] then
		s.step += 1
		s.model:SetAttribute("Step", s.step - 1)
		setLight(s.model, AMBER)
		if s.step > S.Steps then
			completeSafe(s, player)
			release(s, "Done")
			return { ok = true, correct = true, step = s.step, opened = true }
		end
		return { ok = true, correct = true, step = s.step }
	end
	s.step = 1
	s.lockedUntil = now() + S.LockoutSeconds
	s.model:SetAttribute("Step", 0)
	s.model:SetAttribute("FailAt", now())
	setLight(s.model, RED)
	playSound(s.model, "Wrong")
	Noise.Emit(s.model:GetPivot().Position, S.NoiseRadius, "Safe")
	return { ok = true, correct = false, step = 1, lockedUntil = s.lockedUntil }
end

-- ===== Puertas con panel de interruptores =====
local function allOn(lights: { boolean }): boolean
	for _, on in lights do
		if not on then
			return false
		end
	end
	return true
end

local function toggle(lights: { boolean }, i: number)
	for j = i - 1, i + 1 do
		if lights[j] ~= nil then
			lights[j] = not lights[j]
		end
	end
end

-- Mínimo de pulsaciones para encenderlas todas (fuerza bruta: 2^Levers combinaciones; pulsar dos veces la misma no sirve).
local function minPresses(lights: { boolean }): number
	local n = #lights
	local best = math.huge
	for mask = 0, 2 ^ n - 1 do
		local test = table.clone(lights)
		local count = 0
		for i = 1, n do
			if bit32.extract(mask, i - 1) == 1 then
				toggle(test, i)
				count += 1
			end
		end
		if count < best and allOn(test) then
			best = count
		end
	end
	return best
end

-- Se parte de la solución y se aplican pulsaciones al azar: siempre tiene solución. Nunca se resuelve con menos de MinPresses.
local function scramble(): { boolean }
	local lights: { boolean }
	repeat
		lights = table.create(D.Levers, true)
		local order = {}
		for i = 1, D.Levers do
			order[i] = i
		end
		for i = #order, 2, -1 do
			local j = rng:NextInteger(1, i)
			order[i], order[j] = order[j], order[i]
		end
		for k = 1, math.min(D.Scramble, D.Levers) do
			toggle(lights, order[k])
		end
	until minPresses(lights) >= D.MinPresses
	return lights
end

local function setDoorLight(d: Door, color: Color3)
	for _, name in { "StatusLightA", "StatusLightB" } do
		local light = d.model:FindFirstChild(name)
		if light and light:IsA("BasePart") then
			light.Color = color
			local pl = light:FindFirstChildOfClass("PointLight")
			if pl then
				pl.Color = color
			end
		end
	end
end

local function refreshDoor(d: Door)
	for i, on in d.lights do
		Props.SetDoorLever(d.model, i, on)
	end
	local lit = 0
	for _, on in d.lights do
		if on then
			lit += 1
		end
	end
	d.model:SetAttribute("Lit", lit)
	d.model:SetAttribute("State", if d.opened then "Open" else "Locked")
end

local function playAll(model: Model, name: string)
	for _, s in model:GetDescendants() do
		if s:IsA("Sound") and s.Name == name then
			s:Play()
		end
	end
end

local function completeDoor(d: Door, by: Player)
	d.opened = true
	for _, p in d.prompts do
		p.Enabled = false
	end
	refreshDoor(d)
	setDoorLight(d, GREEN)
	playSound(d.model, "Shutter")
	local alpha = Instance.new("NumberValue")
	local conn = alpha.Changed:Connect(function(a: number)
		Props.SetDoorOpen(d.model, d.height, a)
	end)
	local tween = TweenService:Create(alpha, TweenInfo.new(D.OpenSeconds, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut, 0, false, 0.3), { Value = 1 })
	tween.Completed:Once(function()
		Props.SetDoorOpen(d.model, d.height, 1)
		conn:Disconnect()
		alpha:Destroy()
	end)
	tween:Play()
	Noise.Emit(d.model:GetPivot().Position, D.ShortNoiseRadius, "Door")
	notice(by, d.label .. " abierta")
end

local function openDoor(d: Door, player: Player)
	local data: Types.DoorOpen = {
		label = d.label,
		lights = table.clone(d.lights),
		presses = d.presses,
		budget = D.Budget,
		lockedUntil = d.lockedUntil,
	}
	puzzleOpen:FireClient(player, "Door", d.id, data)
end

local function doorPress(d: Door, player: Player, value: unknown): { [string]: any }
	if d.opened or type(value) ~= "number" or value ~= value then
		return { ok = false }
	end
	local i = math.floor(value)
	if i < 1 or i > D.Levers then
		return { ok = false }
	end
	local t = now()
	if t < d.lockedUntil then
		return { ok = false, err = "LOCKED", lockedUntil = d.lockedUntil }
	end
	if t - d.lastPress < D.PressCooldown then
		return { ok = false, err = "TOO_FAST" }
	end
	d.lastPress = t
	toggle(d.lights, i)
	d.presses += 1
	playAll(d.model, "Lever")
	Noise.Emit(d.model:GetPivot().Position, D.PressNoiseRadius, "Door")
	if allOn(d.lights) then
		completeDoor(d, player)
		release(d, "Done")
		return { ok = true, lights = table.clone(d.lights), presses = d.presses, solved = true }
	end
	if d.presses >= D.Budget then
		-- Cortocircuito: chispas, mucho ruido, se mezcla de nuevo y se bloquea el panel.
		d.presses = 0
		d.lights = scramble()
		d.lockedUntil = t + D.LockoutSeconds
		d.model:SetAttribute("SparkAt", t)
		playAll(d.model, "Spark")
		setDoorLight(d, AMBER)
		task.delay(D.LockoutSeconds, function()
			if not d.opened then
				setDoorLight(d, RED)
			end
		end)
		Noise.Emit(d.model:GetPivot().Position, D.ShortNoiseRadius, "Door")
		refreshDoor(d)
		return { ok = true, lights = table.clone(d.lights), presses = 0, short = true, lockedUntil = d.lockedUntil }
	end
	refreshDoor(d)
	return { ok = true, lights = table.clone(d.lights), presses = d.presses }
end

-- Mide el vano del marcador con rayos: jambas a ambos lados (en X o en Z) y dintel. Devuelve el marco del vano (origen en el centro
-- del suelo, X a lo largo de la pared, Z normal), ancho, alto y grosor de la pared.
local function measureOpening(marker: Attachment, ignore: { Instance }): (CFrame, number, number, number)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	local p = marker.WorldPosition
	local down = workspace:Raycast(p + Vector3.new(0, 2, 0), Vector3.new(0, -8, 0), params)
	local floorY = if down then down.Position.Y else p.Y
	local mid = Vector3.new(p.X, floorY + 3, p.Z)
	local best: { axis: Vector3, a: RaycastResult, b: RaycastResult }? = nil
	for _, axis in { Vector3.xAxis, Vector3.zAxis } do
		local a = workspace:Raycast(mid, axis * D.MaxJamb, params)
		local b = workspace:Raycast(mid, -axis * D.MaxJamb, params)
		if a and b and (not best or a.Distance + b.Distance < best.a.Distance + best.b.Distance) then
			best = { axis = axis, a = a, b = b }
		end
	end
	local owner = marker.Parent
	local attrW = owner and owner:GetAttribute("Width")
	local attrH = owner and owner:GetAttribute("Height")
	local axis = if best then best.axis else Vector3.xAxis
	local normal = axis:Cross(Vector3.yAxis)
	local center = Vector3.new(p.X, floorY, p.Z)
	local width = D.DefaultWidth
	local thickness = 1
	if best then
		width = best.a.Distance + best.b.Distance
		center += axis * (best.a.Distance - best.b.Distance) / 2
		-- Grosor y plano medio de la pared, a partir de la jamba (caja alineada a los ejes).
		local jamb = best.a.Instance
		if jamb:IsA("BasePart") then
			local cf, h = jamb.CFrame, jamb.Size / 2
			local ext = math.abs(cf.RightVector:Dot(normal)) * h.X + math.abs(cf.UpVector:Dot(normal)) * h.Y + math.abs(cf.LookVector:Dot(normal)) * h.Z
			thickness = ext * 2
			center += normal * (jamb.Position - center):Dot(normal)
		end
	end
	local up = workspace:Raycast(center + Vector3.new(0, 0.5, 0), Vector3.new(0, 30, 0), params)
	local height = if up then up.Position.Y - floorY else D.DefaultHeight
	if type(attrW) == "number" then
		width = attrW
	end
	if type(attrH) == "number" then
		height = attrH
	end
	return CFrame.fromMatrix(center, axis, Vector3.yAxis, normal), width, height, thickness
end

-- ===== Colocación por nivel =====
local function clearAll()
	for _, o in objectives do
		release(o, "LevelEnded")
	end
	table.clear(objectives)
	folder:ClearAllChildren()
	workspace:SetAttribute("PowerRestored", nil)
end

local function makePrompt(o: Objective, action: string, hold: number, at: Instance?): ProximityPrompt
	local att = at or o.model:FindFirstChild("PromptAttachment", true)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = action
	prompt.ObjectText = o.label
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = hold
	prompt.MaxActivationDistance = 8
	prompt.RequiresLineOfSight = false
	prompt.Parent = att or o.model.PrimaryPart
	return prompt
end

local function tryUse(o: Objective, player: Player)
	local run = Runs.GetByUser(player.UserId)
	if not run or run.code ~= activeRun or run.state ~= "Level" or run.ended then
		return
	end
	if not inReach(player, o, 0) then
		return
	end
	if o.operator and o.operator ~= player then
		notice(player, o.operator.DisplayName .. " ya está trabajando aquí")
		return
	end
	-- Un jugador solo maneja un objetivo a la vez.
	for _, other in objectives do
		if other ~= o and other.operator == player then
			release(other, "Switched")
		end
	end
	o.operator = player
	o.model:SetAttribute("Operator", player.UserId)
	if o.kind == "Generator" then
		openGenerator(o :: Generator, player)
	elseif o.kind == "Safe" then
		openSafe(o :: Safe, player)
	else
		openDoor(o :: Door, player)
	end
end

local function markerParts(): { { att: Attachment, owner: Instance? } }
	local list = {}
	local maps = workspace:FindFirstChild("Maps")
	if maps then
		for _, d in maps:GetDescendants() do
			if d:IsA("Attachment") and (d.Name == "MachineSpawn" or d.Name == "PuzzleSpawn") then
				table.insert(list, { att = d, owner = d.Parent })
			end
		end
	end
	return list
end

-- Devuelve (lo que ignoran los rayos de pared/suelo, piezas visibles del mapa con las que no solaparse).
local function placementLists(): ({ Instance }, { BasePart })
	local rays: { Instance } = { folder, TreasureSpawner.Folder }
	local solids: { BasePart } = {}
	for _, p in Players:GetPlayers() do
		if p.Character then
			table.insert(rays, p.Character)
		end
	end
	local maps = workspace:FindFirstChild("Maps")
	if maps then
		for _, d in maps:GetDescendants() do
			if d:IsA("BasePart") then
				-- Marcadores invisibles y volúmenes sin colisión no cuentan como pared; la decoración visible sí cuenta como mueble.
				local invisible = d.Transparency >= 0.95
				if invisible or not d.CanCollide then
					table.insert(rays, d)
				end
				if not invisible then
					table.insert(solids, d)
				end
			end
		end
	end
	return rays, solids
end

local function shuffle<T>(t: { T })
	for i = #t, 2, -1 do
		local j = rng:NextInteger(1, i)
		t[i], t[j] = t[j], t[i]
	end
end

local function spawnObjectives(run: Runs.Run)
	clearAll()
	activeRun = run.code
	local ignore, solids = placementLists()
	local machines: { Attachment } = {}
	local safes: { Attachment } = {}
	local doors: { Attachment } = {}
	for _, m in markerParts() do
		if m.att.Name == "MachineSpawn" then
			table.insert(machines, m.att)
		elseif m.owner and string.sub(m.owner.Name, 1, #S.SpawnPrefix) == S.SpawnPrefix then
			table.insert(safes, m.att)
		elseif m.owner and string.sub(m.owner.Name, 1, #D.SpawnPrefix) == D.SpawnPrefix then
			table.insert(doors, m.att)
		end
	end
	shuffle(machines)

	local players = #run.members
	local needed = math.min(#machines, G.Base + math.floor(math.max(0, players - 1) / G.PerExtraPlayers))
	local count = math.min(#machines, needed + G.Spare)
	for i = 1, count do
		local model = Props.Make("Generator")
		model.Name = "Generator_" .. i
		Props.Place(model, machines[i].WorldPosition, ignore, solids)
		model.Parent = folder
		local g: Generator = {
			kind = "Generator",
			id = model.Name,
			label = string.format("Generador G-%02d", i),
			model = model,
			prompt = nil :: any,
			done = 0,
			repaired = false,
			operator = nil,
			challenge = nil,
			lastHit = 0,
		}
		g.prompt = makePrompt(g, "Reparar", G.HoldSeconds)
		g.prompt.Triggered:Connect(function(player)
			tryUse(g, player)
		end)
		refreshGenerator(g)
		objectives[g.id] = g
	end
	run.powerNeeded = needed
	run.powerDone = 0

	for i, att in safes do
		local model = Props.Make("Safe")
		model.Name = "Safe_" .. i
		Props.Place(model, att.WorldPosition, ignore, solids)
		model.Parent = folder
		local s: Safe = {
			kind = "Safe",
			id = model.Name,
			label = string.format("Caja fuerte Nº %02d", rng:NextInteger(1, 99)),
			model = model,
			prompt = nil :: any,
			combo = makeCombo(),
			step = 1,
			opened = false,
			operator = nil,
			lockedUntil = 0,
			probes = {},
		}
		s.prompt = makePrompt(s, "Abrir combinación", S.HoldSeconds)
		s.prompt.Triggered:Connect(function(player)
			tryUse(s, player)
		end)
		model:SetAttribute("State", "Locked")
		model:SetAttribute("Step", 0)
		objectives[s.id] = s
	end
	for i, att in doors do
		local frame, width, height, thickness = measureOpening(att, ignore)
		local model = Props.BuildDoor(width, height, thickness, D.Levers)
		model.Name = "Door_" .. i
		model:PivotTo(frame)
		model.Parent = folder
		local d: Door = {
			kind = "Door",
			id = model.Name,
			label = string.format("Persiana de seguridad %s-%d", string.char(64 + i), rng:NextInteger(10, 99)),
			model = model,
			prompt = nil :: any,
			prompts = {},
			height = height,
			lights = scramble(),
			presses = 0,
			opened = false,
			operator = nil,
			lockedUntil = 0,
			lastPress = 0,
		}
		for _, a in model:GetDescendants() do
			if a:IsA("Attachment") and a.Name == "PromptAttachment" then
				local prompt = makePrompt(d, "Usar panel", D.HoldSeconds, a)
				prompt.Triggered:Connect(function(player)
					tryUse(d, player)
				end)
				table.insert(d.prompts, prompt)
			end
		end
		d.prompt = d.prompts[1]
		setDoorLight(d, RED)
		refreshDoor(d)
		objectives[d.id] = d
	end
	print(string.format("[Objectives] %d generadores (%d necesarios), %d cajas fuertes, %d puertas", count, needed, #safes, #doors))
end

Runs.StateChanged:Connect(function(code: string, state)
	local run = Runs.Get(code)
	if state == "Level" and run then
		spawnObjectives(run)
	elseif code == activeRun and (state == "Descending" or state == "Won" or state == "Lost" or state == "Stopover") then
		clearAll()
		activeRun = nil
	end
end)

-- ===== Remoto =====
puzzleAction.OnServerInvoke = function(player: Player, id: unknown, action: unknown, arg: unknown)
	if type(id) ~= "string" or type(action) ~= "string" then
		return { ok = false }
	end
	local o = objectives[id]
	if not o or o.operator ~= player then
		return { ok = false, err = "NOT_OPERATOR" }
	end
	if action == "Close" then
		release(o, nil)
		return { ok = true }
	end
	if not inReach(player, o, 4) then
		release(o, "TooFar")
		return { ok = false, err = "TOO_FAR" }
	end
	if o.kind == "Generator" and action == "Hit" then
		return generatorHit(o :: Generator, player, arg)
	elseif o.kind == "Safe" and action == "Probe" then
		return safeProbe(o :: Safe, player, arg)
	elseif o.kind == "Safe" and action == "Lock" then
		return safeLock(o :: Safe, player, arg)
	elseif o.kind == "Door" and action == "Press" then
		return doorPress(o :: Door, player, arg)
	end
	return { ok = false }
end

-- Vigila a los operadores: si se alejan, mueren o salen, se cierra su minijuego.
local acc = 0
RunService.Heartbeat:Connect(function(dt)
	acc += dt
	if acc < 0.25 then
		return
	end
	acc = 0
	for _, o in objectives do
		local p = o.operator
		if p then
			if not p.Parent then
				release(o, nil)
			elseif not rootOf(p) then
				release(o, "Dead")
			elseif not inReach(p, o, 4) then
				release(o, "TooFar")
			end
		end
	end
end)

Players.PlayerRemoving:Connect(function(player)
	for _, o in objectives do
		if o.operator == player then
			release(o, nil)
		end
		if o.kind == "Safe" then
			(o :: Safe).probes[player] = nil
		end
	end
end)
