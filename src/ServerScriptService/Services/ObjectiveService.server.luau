--!strict
-- Objetivos del nivel (GDD §3): generadores que reparar y cajas fuertes que abrir. Servidor autoritativo; parámetros en
-- Config.Objectives. Al empezar un nivel (Runs.StateChanged "Level") coloca los modelos (Props) en los marcadores del mapa cargado:
--   * MachineSpawn -> generador. Se reparan Needed (según jugadores) de los que aparecen; hasta entonces Runs no deja bajar (POWER_OFF).
--   * PuzzleSpawn cuyo Part padre empieza por "Cofre" -> caja fuerte con combinación aleatoria y botín dentro (TreasureSpawner).
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

type Objective = Generator | Safe

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

local function promptPoint(o: Objective): Vector3
	local att = o.model:FindFirstChild("PromptAttachment", true)
	return if att and att:IsA("Attachment") then att.WorldPosition else o.model:GetPivot().Position
end

local function inReach(player: Player, o: Objective, extra: number): boolean
	local root = rootOf(player)
	return root ~= nil and (root.Position - promptPoint(o)).Magnitude <= O.UseDistance + extra
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

-- ===== Colocación por nivel =====
local function clearAll()
	for _, o in objectives do
		release(o, "LevelEnded")
	end
	table.clear(objectives)
	folder:ClearAllChildren()
	workspace:SetAttribute("PowerRestored", nil)
end

local function makePrompt(o: Objective, action: string, hold: number): ProximityPrompt
	local att = o.model:FindFirstChild("PromptAttachment", true)
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
	else
		openSafe(o :: Safe, player)
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
	for _, m in markerParts() do
		if m.att.Name == "MachineSpawn" then
			table.insert(machines, m.att)
		elseif m.owner and string.sub(m.owner.Name, 1, #S.SpawnPrefix) == S.SpawnPrefix then
			table.insert(safes, m.att)
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
	print(string.format("[Objectives] %d generadores (%d necesarios), %d cajas fuertes", count, needed, #safes))
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
