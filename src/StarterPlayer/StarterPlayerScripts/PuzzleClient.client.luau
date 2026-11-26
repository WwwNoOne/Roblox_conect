--!strict
-- Minijuegos de los objetivos (los abre el servidor con PuzzleOpen; cada acción la valida ObjectiveService):
--   * Generador: una aguja recorre el medidor; [Espacio]/[E]/clic la fija. Dentro de la franja = fase estable; fuera = chispazo y se
--     pierde una fase. Config.Objectives.Generator.Steps fases lo reparan.
--   * Caja fuerte: dial de 0 a Numbers-1. [A]/[D], flechas o rueda giran; al pasar por el número correcto suena un clic y se enciende
--     el piloto. [Espacio]/[E] fija el número. Un número incorrecto reinicia la combinación y bloquea el dial unos segundos.
--   * Puerta: panel de interruptores. Cada palanca invierte su luz y las de al lado; hay que encenderlas todas antes de gastar las
--     pulsaciones (si no, cortocircuito: se mezcla y se bloquea). [1]-[5] o clic accionan; [A]/[D] eligen y [Espacio] acciona.
-- [Q] o [Retroceso] salen. Mientras está abierto el ratón queda libre y el personaje no se mueve. Estética de SurvivalHud.
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Types = require(Shared:WaitForChild("Types"))
local O = Config.Objectives

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local puzzleOpen = remotes:WaitForChild("PuzzleOpen") :: RemoteEvent
local puzzleClose = remotes:WaitForChild("PuzzleClose") :: RemoteEvent
local puzzleAction = remotes:WaitForChild("PuzzleAction") :: RemoteFunction

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- ===== Paleta (la de SurvivalHud) =====
local INK = Color3.fromRGB(12, 11, 9)
local PAPER = Color3.fromRGB(231, 225, 203)
local DIM = Color3.fromRGB(150, 144, 124)
local AMBER = Color3.fromRGB(226, 184, 86)
local RED = Color3.fromRGB(214, 70, 56)
local GREEN = Color3.fromRGB(150, 205, 120)
local MONO = Font.new("rbxasset://fonts/families/RobotoMono.json", Enum.FontWeight.Medium)
local MONO_BOLD = Font.new("rbxasset://fonts/families/RobotoMono.json", Enum.FontWeight.Bold)

local function new(class: string, props: { [string]: any }, parent: Instance?): any
	local inst = Instance.new(class)
	for k, v in props do
		(inst :: any)[k] = v
	end
	inst.Parent = parent
	return inst
end

local function panel(props: { [string]: any }, parent: Instance): Frame
	local f = new("Frame", props, parent)
	f.BackgroundColor3 = INK
	f.BackgroundTransparency = 0.12
	f.BorderSizePixel = 0
	new("UICorner", { CornerRadius = UDim.new(0, 4) }, f)
	new("UIStroke", { Color = PAPER, Transparency = 0.8, Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, f)
	return f
end

local function text(props: { [string]: any }, parent: Instance): TextLabel
	local t = new("TextLabel", props, parent)
	t.BackgroundTransparency = 1
	if not props.FontFace then
		t.FontFace = MONO
	end
	if not props.TextColor3 then
		t.TextColor3 = PAPER
	end
	return t
end

local function button(label: string, props: { [string]: any }, parent: Instance): TextButton
	local b = new("TextButton", props, parent)
	b.Text = label
	b.FontFace = MONO_BOLD
	b.TextSize = 15
	b.TextColor3 = PAPER
	b.AutoButtonColor = true
	b.BackgroundColor3 = Color3.fromRGB(40, 38, 32)
	b.BorderSizePixel = 0
	new("UICorner", { CornerRadius = UDim.new(0, 3) }, b)
	new("UIStroke", { Color = PAPER, Transparency = 0.75, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, b)
	return b
end

-- ===== Sonidos locales =====
local sounds: { [string]: Sound } = {}
for name, def in O.Sounds do
	sounds[name] = new("Sound", { Name = "Puzzle_" .. name, SoundId = def.Id, Volume = def.Volume }, SoundService)
end
local function play(name: string, pitch: number?)
	local s = sounds[name]
	if s then
		s.PlaybackSpeed = pitch or 1
		SoundService:PlayLocalSound(s)
	end
end

-- ===== Pantalla común =====
local gui = new("ScreenGui", { Name = "PuzzleGui", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 20, Enabled = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling }, playerGui)
new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.45, BorderSizePixel = 0 }, gui)
-- Un botón modal libera el ratón en primera persona mientras el minijuego está abierto.
new("TextButton", { Size = UDim2.fromOffset(0, 0), BackgroundTransparency = 1, Text = "", Modal = true }, gui)
local scale = new("UIScale", {}, gui)
local function rescale()
	local cam = workspace.CurrentCamera
	scale.Scale = if cam then math.clamp(cam.ViewportSize.Y / 900, 0.8, 1.5) else 1
end
rescale()
workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(rescale)
if workspace.CurrentCamera then
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)
end

type Session = {
	kind: "Generator" | "Safe" | "Door",
	id: string,
	root: Frame,
	onKey: (key: Enum.KeyCode, down: boolean) -> (),
	onStep: (dt: number) -> (),
	cleanup: () -> (),
	closing: boolean,
}
local session: Session? = nil

local function shake(frame: GuiObject, amount: number)
	local base = frame.Position
	task.spawn(function()
		for i = 1, 8 do
			local k = (1 - i / 8) * amount
			frame.Position = base + UDim2.fromOffset(math.random(-10, 10) / 10 * k, math.random(-10, 10) / 10 * k)
			task.wait(0.03)
		end
		frame.Position = base
	end)
end

local function setOwnPrompt(id: string, enabled: boolean)
	local folder = workspace:FindFirstChild("RunObjectives")
	local model = folder and folder:FindFirstChild(id)
	if not model or model:GetAttribute("State") == "Repaired" or model:GetAttribute("State") == "Open" then
		return
	end
	for _, prompt in model:GetDescendants() do
		if prompt:IsA("ProximityPrompt") then
			prompt.Enabled = enabled
		end
	end
end

local ACTION = "PuzzleInput"
local KEYS = {
	Enum.KeyCode.W, Enum.KeyCode.A, Enum.KeyCode.S, Enum.KeyCode.D,
	Enum.KeyCode.Up, Enum.KeyCode.Down, Enum.KeyCode.Left, Enum.KeyCode.Right,
	Enum.KeyCode.Space, Enum.KeyCode.E, Enum.KeyCode.Q, Enum.KeyCode.Backspace, Enum.KeyCode.Return,
	Enum.KeyCode.LeftShift, Enum.KeyCode.C, Enum.KeyCode.LeftControl,
	Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three, Enum.KeyCode.Four, Enum.KeyCode.Five,
	Enum.KeyCode.Six, Enum.KeyCode.Seven, Enum.KeyCode.Eight, Enum.KeyCode.Nine,
	Enum.KeyCode.ButtonA, Enum.KeyCode.ButtonB, Enum.KeyCode.DPadLeft, Enum.KeyCode.DPadRight, Enum.KeyCode.Thumbstick1,
}

local function close(notify: boolean)
	local s = session
	if not s or s.closing then
		return
	end
	s.closing = true
	session = nil
	ContextActionService:UnbindAction(ACTION)
	s.cleanup()
	setOwnPrompt(s.id, true)
	local root = s.root
	TweenService:Create(root, TweenInfo.new(0.15), { Position = root.Position + UDim2.fromOffset(0, 20) }):Play()
	task.delay(0.15, function()
		root:Destroy()
		if not session then
			gui.Enabled = false
		end
	end)
	if notify then
		task.spawn(function()
			pcall(function()
				puzzleAction:InvokeServer(s.id, "Close")
			end)
		end)
	end
end

local function begin(s: Session)
	if session then
		close(true)
	end
	session = s
	gui.Enabled = true
	setOwnPrompt(s.id, false)
	s.root.Position = UDim2.new(0.5, 0, 0.5, 24)
	TweenService:Create(s.root, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = UDim2.fromScale(0.5, 0.5) }):Play()
	ContextActionService:BindActionAtPriority(ACTION, function(_, state, input)
		local cur = session
		if not cur then
			return Enum.ContextActionResult.Pass
		end
		if state == Enum.UserInputState.Begin or state == Enum.UserInputState.End then
			local key = input.KeyCode
			if (key == Enum.KeyCode.Q or key == Enum.KeyCode.Backspace or key == Enum.KeyCode.ButtonB) and state == Enum.UserInputState.Begin then
				close(true)
			else
				cur.onKey(key, state == Enum.UserInputState.Begin)
			end
		end
		return Enum.ContextActionResult.Sink -- el personaje no se mueve ni salta con el minijuego abierto
	end, false, Enum.ContextActionPriority.High.Value + 10, table.unpack(KEYS))
end

RunService.RenderStepped:Connect(function(dt)
	local s = session
	if s then
		s.onStep(dt)
	end
end)

-- ===== Generador =====
local function openGenerator(id: string, data: Types.GeneratorOpen)
	local root = panel({ Name = "Generator", AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(640, 300) }, gui)
	text({ Text = string.upper(data.label) .. " · CALIBRACIÓN DE FASE", TextSize = 18, FontFace = MONO_BOLD, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(24, 18), Size = UDim2.fromOffset(500, 22) }, root)
	text({ Text = "Fija la aguja dentro de la franja.", TextSize = 13, TextColor3 = DIM, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(24, 44), Size = UDim2.fromOffset(500, 18) }, root)
	local closeBtn = button("SALIR [Q]", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -18, 0, 16), Size = UDim2.fromOffset(110, 30) }, root)

	-- Fases
	local stepRow = new("Frame", { Position = UDim2.fromOffset(24, 78), Size = UDim2.fromOffset(300, 22), BackgroundTransparency = 1 }, root)
	new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8) }, stepRow)
	local stepBoxes: { Frame } = {}
	for i = 1, data.steps do
		local b = new("Frame", { Size = UDim2.fromOffset(64, 14), BackgroundColor3 = PAPER, BackgroundTransparency = 0.85, BorderSizePixel = 0, LayoutOrder = i }, stepRow)
		new("UICorner", { CornerRadius = UDim.new(0, 2) }, b)
		stepBoxes[i] = b
	end
	local stepLabel = text({ Text = "", TextSize = 13, TextColor3 = DIM, TextXAlignment = Enum.TextXAlignment.Right, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -24, 0, 78), Size = UDim2.fromOffset(200, 16) }, root)

	-- Medidor
	local track = new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 124), Size = UDim2.fromOffset(592, 56), BackgroundColor3 = Color3.fromRGB(26, 25, 21), BorderSizePixel = 0, ClipsDescendants = true }, root)
	new("UIStroke", { Color = PAPER, Transparency = 0.7 }, track)
	for i = 0, 20 do
		local major = i % 5 == 0
		new("Frame", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(i / 20, 0, 1, 0), Size = UDim2.fromOffset(2, if major then 18 else 9), BackgroundColor3 = PAPER, BackgroundTransparency = if major then 0.5 else 0.75, BorderSizePixel = 0 }, track)
	end
	local zone = new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Size = UDim2.fromScale(0.2, 1), BackgroundColor3 = AMBER, BackgroundTransparency = 0.55, BorderSizePixel = 0 }, track)
	new("UIStroke", { Color = AMBER, Transparency = 0.1, Thickness = 2 }, zone)
	local needle = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0, 0.5), Size = UDim2.new(0, 5, 1, 10), BackgroundColor3 = PAPER, BorderSizePixel = 0, ZIndex = 3 }, track)
	new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(0, 15, 1, 0), BackgroundColor3 = PAPER, BackgroundTransparency = 0.8, BorderSizePixel = 0, ZIndex = 2 }, needle)

	local status = text({ Text = "", TextSize = 16, FontFace = MONO_BOLD, Position = UDim2.fromOffset(24, 196), Size = UDim2.new(1, -48, 0, 24) }, root)
	local hitBtn = button("FIJAR [ESPACIO]", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 234), Size = UDim2.fromOffset(240, 42), TextSize = 17 }, root)
	hitBtn.BackgroundColor3 = Color3.fromRGB(64, 54, 26)

	local challenge = data.challenge
	local done = data.done
	local busy = false
	local frozenAt: number? = nil -- congela la aguja mientras se espera la respuesta

	local function refreshSteps()
		for i, b in stepBoxes do
			b.BackgroundColor3 = if i <= done then GREEN else PAPER
			b.BackgroundTransparency = if i <= done then 0.1 else 0.85
		end
		stepLabel.Text = string.format("FASE %d/%d", math.min(done + 1, data.steps), data.steps)
	end
	local function placeZone()
		zone.Position = UDim2.fromScale(challenge.center, 0)
		zone.Size = UDim2.fromScale(challenge.width, 1)
	end
	refreshSteps()
	placeZone()
	status.Text = "ESPERANDO SEÑAL"
	status.TextColor3 = DIM

	local function needleAt(t: number): number
		local x = math.max(0, t - challenge.t0) / challenge.period
		local m = x % 2
		return if m <= 1 then m else 2 - m
	end

	local function hit()
		if busy then
			return
		end
		busy = true
		local t = workspace:GetServerTimeNow()
		frozenAt = t
		local ok, result = pcall(function()
			return puzzleAction:InvokeServer(id, "Hit", t)
		end)
		frozenAt = nil
		if not session or session.id ~= id then
			return
		end
		if not ok or type(result) ~= "table" or not result.ok then
			busy = false
			return
		end
		done = result.done or done
		refreshSteps()
		if result.finished then
			status.Text = "GENERADOR EN LÍNEA"
			status.TextColor3 = GREEN
			play("Lock", 0.9)
			zone.BackgroundColor3 = GREEN
			task.delay(0.9, function()
				if session and session.id == id then
					close(false)
				end
			end)
			return
		end
		if result.hit then
			status.Text = "FASE ESTABLE"
			status.TextColor3 = GREEN
			play("Lock", 1.1)
		else
			status.Text = "¡SOBRECARGA! FASE PERDIDA"
			status.TextColor3 = RED
			play("Spark")
			shake(root, 14)
			track.BackgroundColor3 = Color3.fromRGB(70, 20, 14)
			TweenService:Create(track, TweenInfo.new(0.5), { BackgroundColor3 = Color3.fromRGB(26, 25, 21) }):Play()
		end
		if result.challenge then
			challenge = result.challenge
			placeZone()
		end
		task.wait(0.2)
		busy = false
	end

	local conns: { RBXScriptConnection } = {}
	table.insert(conns, closeBtn.Activated:Connect(function()
		close(true)
	end))
	table.insert(conns, hitBtn.Activated:Connect(function()
		task.spawn(hit)
	end))

	begin({
		kind = "Generator",
		id = id,
		root = root,
		closing = false,
		onKey = function(key, down)
			if down and (key == Enum.KeyCode.Space or key == Enum.KeyCode.E or key == Enum.KeyCode.Return or key == Enum.KeyCode.ButtonA) then
				task.spawn(hit)
			end
		end,
		onStep = function(_dt)
			local t = frozenAt or workspace:GetServerTimeNow()
			local n = needleAt(t)
			needle.Position = UDim2.fromScale(n, 0.5)
			local inside = math.abs(n - challenge.center) <= challenge.width / 2
			needle.BackgroundColor3 = if inside then GREEN else PAPER
		end,
		cleanup = function()
			for _, c in conns do
				c:Disconnect()
			end
		end,
	})
end

-- ===== Caja fuerte =====
local function openSafe(id: string, data: Types.SafeOpen)
	local N = data.numbers
	local root = panel({ Name = "Safe", AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(700, 420) }, gui)
	text({ Text = string.upper(data.label), TextSize = 18, FontFace = MONO_BOLD, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(24, 18), Size = UDim2.fromOffset(420, 22) }, root)
	text({ Text = "Gira despacio y escucha: un clic marca el número.", TextSize = 13, TextColor3 = DIM, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(24, 44), Size = UDim2.fromOffset(460, 18) }, root)
	local closeBtn = button("SALIR [Q]", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -18, 0, 16), Size = UDim2.fromOffset(110, 30) }, root)

	-- Dial
	local dialHolder = new("Frame", { Position = UDim2.fromOffset(34, 84), Size = UDim2.fromOffset(300, 300), BackgroundTransparency = 1 }, root)
	local rim = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(38, 40, 38), BorderSizePixel = 0 }, dialHolder)
	new("UICorner", { CornerRadius = UDim.new(1, 0) }, rim)
	new("UIStroke", { Color = Color3.fromRGB(110, 112, 104), Thickness = 3 }, rim)
	local face = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(272, 272), BackgroundColor3 = Color3.fromRGB(196, 190, 170), BorderSizePixel = 0 }, dialHolder)
	new("UICorner", { CornerRadius = UDim.new(1, 0) }, face)
	local R = 136
	for i = 0, N - 1 do
		local a = math.rad(i * 360 / N)
		local major = i % 5 == 0
		local len = if major then 20 else 11
		local r = R - 4 - len / 2
		new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, math.sin(a) * r, 0.5, -math.cos(a) * r),
			Size = UDim2.fromOffset(if major then 3 else 2, len),
			Rotation = i * 360 / N,
			BackgroundColor3 = INK,
			BorderSizePixel = 0,
		}, face)
		if major then
			local rr = R - 40
			text({
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.new(0.5, math.sin(a) * rr, 0.5, -math.cos(a) * rr),
				Size = UDim2.fromOffset(36, 22),
				Rotation = i * 360 / N,
				Text = tostring(i),
				TextSize = 17,
				FontFace = MONO_BOLD,
				TextColor3 = INK,
			}, face)
		end
	end
	local knob = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(110, 110), BackgroundColor3 = Color3.fromRGB(44, 44, 42), BorderSizePixel = 0 }, face)
	new("UICorner", { CornerRadius = UDim.new(1, 0) }, knob)
	new("UIStroke", { Color = Color3.fromRGB(90, 90, 86), Thickness = 2 }, knob)
	new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 6), Size = UDim2.fromOffset(6, 34), BackgroundColor3 = Color3.fromRGB(150, 150, 140), BorderSizePixel = 0 }, knob)
	-- Índice fijo arriba
	new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, -6), Size = UDim2.fromOffset(16, 16), Rotation = 45, BackgroundColor3 = RED, BorderSizePixel = 0, ZIndex = 3 }, dialHolder)
	local readout = text({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(80, 40), Text = "00", TextSize = 28, FontFace = MONO_BOLD, TextColor3 = AMBER, ZIndex = 4 }, dialHolder)

	-- Panel derecho: combinación, piloto y controles
	local right = new("Frame", { Position = UDim2.fromOffset(370, 84), Size = UDim2.fromOffset(306, 310), BackgroundTransparency = 1 }, root)
	text({ Text = "COMBINACIÓN", TextSize = 12, TextColor3 = DIM, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.fromOffset(200, 14) }, right)
	local slotRow = new("Frame", { Position = UDim2.fromOffset(0, 20), Size = UDim2.fromOffset(306, 64), BackgroundTransparency = 1 }, right)
	new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 10) }, slotRow)
	local slots: { TextLabel } = {}
	for i = 1, data.steps do
		local f = panel({ Size = UDim2.fromOffset(88, 64), LayoutOrder = i }, slotRow)
		slots[i] = text({ Size = UDim2.fromScale(1, 1), Text = "--", TextSize = 28, FontFace = MONO_BOLD, TextColor3 = DIM }, f)
	end
	local led = new("Frame", { Position = UDim2.fromOffset(0, 104), Size = UDim2.fromOffset(18, 18), BackgroundColor3 = Color3.fromRGB(60, 50, 30), BorderSizePixel = 0 }, right)
	new("UICorner", { CornerRadius = UDim.new(1, 0) }, led)
	text({ Text = "CLIC", TextSize = 13, TextColor3 = DIM, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(28, 104), Size = UDim2.fromOffset(100, 18) }, right)
	local status = text({ Text = "", TextSize = 15, FontFace = MONO_BOLD, TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = true, Position = UDim2.fromOffset(0, 136), Size = UDim2.fromOffset(306, 44) }, right)
	local leftBtn = button("◀ [A]", { Position = UDim2.fromOffset(0, 192), Size = UDim2.fromOffset(96, 40) }, right)
	local rightBtn = button("[D] ▶", { Position = UDim2.fromOffset(106, 192), Size = UDim2.fromOffset(96, 40) }, right)
	local lockBtn = button("FIJAR [ESPACIO]", { Position = UDim2.fromOffset(0, 244), Size = UDim2.fromOffset(306, 44), TextSize = 17 }, right)
	lockBtn.BackgroundColor3 = Color3.fromRGB(64, 54, 26)
	text({ Text = "Rueda del ratón también gira", TextSize = 11, TextColor3 = DIM, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(212, 196), Size = UDim2.fromOffset(94, 34), TextWrapped = true }, right)

	local step = data.step
	local locked: { number } = {}
	local pos = 0 -- posición continua (sin módulo) para girar siempre por el camino corto
	local shownAngle = 0
	local lockedUntil = data.lockedUntil
	local holdDir = 0
	local holdNext = 0
	local probeInFlight = false
	local lastProbeAt = 0
	local probedValue: number? = nil
	local clickValue: number? = nil
	local busy = false

	local function value(): number
		return pos % N
	end

	local function setStatus(t: string, color: Color3)
		status.Text = t
		status.TextColor3 = color
	end
	local function refreshSlots()
		for i, s in slots do
			if locked[i] then
				s.Text = string.format("%02d", locked[i])
				s.TextColor3 = GREEN
			elseif i == step then
				s.Text = "··"
				s.TextColor3 = AMBER
			else
				s.Text = "--"
				s.TextColor3 = DIM
			end
		end
	end
	refreshSlots()
	setStatus(string.format("Busca el número %d de %d", step, data.steps), PAPER)

	local function turn(dir: number)
		if workspace:GetServerTimeNow() < lockedUntil then
			return
		end
		pos += dir
		clickValue = nil
		play("DialTick", 0.9 + math.random() * 0.2)
	end

	local function lockIn()
		if busy then
			return
		end
		local t = workspace:GetServerTimeNow()
		if t < lockedUntil then
			return
		end
		busy = true
		local v = value()
		local ok, result = pcall(function()
			return puzzleAction:InvokeServer(id, "Lock", v)
		end)
		busy = false
		if not session or session.id ~= id or not ok or type(result) ~= "table" then
			return
		end
		if result.err == "LOCKED" then
			lockedUntil = result.lockedUntil or lockedUntil
			return
		end
		if not result.ok then
			return
		end
		if result.correct then
			locked[step] = v
			step = result.step or (step + 1)
			refreshSlots()
			play("Lock")
			if result.opened then
				setStatus("¡ABIERTA!", GREEN)
				face.BackgroundColor3 = Color3.fromRGB(190, 220, 170)
				task.delay(1.0, function()
					if session and session.id == id then
						close(false)
					end
				end)
			else
				setStatus(string.format("Bien. Busca el número %d de %d", step, data.steps), GREEN)
			end
		else
			table.clear(locked)
			step = 1
			lockedUntil = result.lockedUntil or (t + O.Safe.LockoutSeconds)
			refreshSlots()
			play("Wrong")
			shake(root, 12)
			for _, s in slots do
				s.TextColor3 = RED
			end
		end
	end

	local conns: { RBXScriptConnection } = {}
	table.insert(conns, closeBtn.Activated:Connect(function()
		close(true)
	end))
	table.insert(conns, lockBtn.Activated:Connect(function()
		task.spawn(lockIn)
	end))
	table.insert(conns, leftBtn.Activated:Connect(function()
		turn(-1)
	end))
	table.insert(conns, rightBtn.Activated:Connect(function()
		turn(1)
	end))
	table.insert(conns, UserInputService.InputChanged:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseWheel then
			turn(if input.Position.Z > 0 then 1 else -1)
		end
	end))

	local function probe(v: number)
		probeInFlight = true
		lastProbeAt = os.clock()
		probedValue = v
		task.spawn(function()
			local ok, result = pcall(function()
				return puzzleAction:InvokeServer(id, "Probe", v)
			end)
			probeInFlight = false
			if ok and type(result) == "table" and result.click and session and session.id == id and value() == v then
				clickValue = v
				play("DialClick")
				led.BackgroundColor3 = AMBER
				TweenService:Create(led, TweenInfo.new(0.6), { BackgroundColor3 = Color3.fromRGB(60, 50, 30) }):Play()
				shake(dialHolder, 4)
			end
		end)
	end

	begin({
		kind = "Safe",
		id = id,
		root = root,
		closing = false,
		onKey = function(key, down)
			local dir = 0
			if key == Enum.KeyCode.A or key == Enum.KeyCode.Left or key == Enum.KeyCode.DPadLeft then
				dir = -1
			elseif key == Enum.KeyCode.D or key == Enum.KeyCode.Right or key == Enum.KeyCode.DPadRight then
				dir = 1
			end
			if dir ~= 0 then
				if down then
					holdDir = dir
					holdNext = os.clock() + 0.3
					turn(dir)
				elseif holdDir == dir then
					holdDir = 0
				end
			elseif down and (key == Enum.KeyCode.Space or key == Enum.KeyCode.E or key == Enum.KeyCode.Return or key == Enum.KeyCode.ButtonA) then
				task.spawn(lockIn)
			end
		end,
		onStep = function(dt)
			local t = os.clock()
			if holdDir ~= 0 and t >= holdNext then
				holdNext = t + 1 / 9
				turn(holdDir)
			end
			-- Consulta al servidor el número bajo el índice (como máximo ~12 por segundo).
			local v = value()
			if v ~= probedValue and not probeInFlight and t - lastProbeAt >= 1 / 12 then
				probe(v)
			end
			local target = -pos * 360 / N
			shownAngle += (target - shownAngle) * (1 - math.exp(-18 * dt))
			face.Rotation = shownAngle
			readout.Text = string.format("%02d", v)
			readout.TextColor3 = if clickValue == v then AMBER else PAPER
			local wait = lockedUntil - workspace:GetServerTimeNow()
			if wait > 0 then
				setStatus(string.format("Combinación incorrecta. Dial bloqueado %.1f s", wait), RED)
			elseif status.TextColor3 == RED then
				setStatus(string.format("Busca el número %d de %d", step, data.steps), PAPER)
				refreshSlots()
			end
		end,
		cleanup = function()
			for _, c in conns do
				c:Disconnect()
			end
		end,
	})
end

-- ===== Puerta: panel de interruptores =====
local DIGITS = {
	[Enum.KeyCode.One] = 1, [Enum.KeyCode.Two] = 2, [Enum.KeyCode.Three] = 3, [Enum.KeyCode.Four] = 4, [Enum.KeyCode.Five] = 5,
	[Enum.KeyCode.Six] = 6, [Enum.KeyCode.Seven] = 7, [Enum.KeyCode.Eight] = 8, [Enum.KeyCode.Nine] = 9,
}

local function openDoor(id: string, data: Types.DoorOpen)
	local n = #data.lights
	local colW = 96
	local width = math.max(560, n * colW + 80)
	local root = panel({ Name = "Door", AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(width, 380) }, gui)
	text({ Text = string.upper(data.label) .. " · PANEL DE CONTROL", TextSize = 18, FontFace = MONO_BOLD, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(24, 18), Size = UDim2.fromOffset(width - 170, 22) }, root)
	text({ Text = "Cada palanca cambia su luz y las de al lado. Enciéndelas todas.", TextSize = 13, TextColor3 = DIM, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(24, 44), Size = UDim2.fromOffset(width - 48, 18) }, root)
	local closeBtn = button("SALIR [Q]", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -18, 0, 16), Size = UDim2.fromOffset(110, 30) }, root)

	local row = new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 80), Size = UDim2.fromOffset(n * colW, 190), BackgroundTransparency = 1 }, root)
	local lamps: { Frame } = {}
	local levers: { TextButton } = {}
	local handles: { Frame } = {}
	local cols: { Frame } = {}
	for i = 1, n do
		local col = new("Frame", { Position = UDim2.fromOffset((i - 1) * colW + 8, 0), Size = UDim2.fromOffset(colW - 16, 190), BackgroundColor3 = Color3.fromRGB(30, 29, 25), BorderSizePixel = 0 }, row)
		new("UICorner", { CornerRadius = UDim.new(0, 3) }, col)
		new("UIStroke", { Name = "Sel", Color = AMBER, Transparency = 1, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, col)
		cols[i] = col
		local lamp = new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 12), Size = UDim2.fromOffset(34, 34), BackgroundColor3 = Color3.fromRGB(70, 26, 20), BorderSizePixel = 0 }, col)
		new("UICorner", { CornerRadius = UDim.new(1, 0) }, lamp)
		new("UIStroke", { Color = INK, Thickness = 3 }, lamp)
		lamps[i] = lamp
		-- Ranura y palanca: arriba = apagada, abajo = encendida.
		local lever = new("TextButton", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 58), Size = UDim2.fromOffset(46, 96), BackgroundColor3 = Color3.fromRGB(18, 18, 16), BorderSizePixel = 0, Text = "", AutoButtonColor = false }, col)
		new("UICorner", { CornerRadius = UDim.new(0, 6) }, lever)
		new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(0, 8, 1, -16), BackgroundColor3 = Color3.fromRGB(8, 8, 8), BorderSizePixel = 0 }, lever)
		local handle = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.25), Size = UDim2.fromOffset(38, 22), BackgroundColor3 = RED, BorderSizePixel = 0 }, lever)
		new("UICorner", { CornerRadius = UDim.new(0, 4) }, handle)
		levers[i] = lever
		handles[i] = handle
		text({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 160), Size = UDim2.fromOffset(60, 20), Text = string.format("[%d]", i), TextSize = 14, FontFace = MONO_BOLD, TextColor3 = DIM }, col)
	end

	local budgetLabel = text({ Text = "", TextSize = 13, TextColor3 = DIM, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(24, 286), Size = UDim2.fromOffset(260, 16) }, root)
	local barBack = new("Frame", { Position = UDim2.fromOffset(24, 306), Size = UDim2.new(1, -48, 0, 8), BackgroundColor3 = PAPER, BackgroundTransparency = 0.85, BorderSizePixel = 0 }, root)
	local bar = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = AMBER, BorderSizePixel = 0 }, barBack)
	local status = text({ Text = "", TextSize = 15, FontFace = MONO_BOLD, Position = UDim2.fromOffset(24, 326), Size = UDim2.new(1, -48, 0, 34) }, root)

	local lights = table.clone(data.lights)
	local presses = data.presses
	local lockedUntil = data.lockedUntil
	local selected = 1
	local busy = false
	local solved = false

	local function setStatus(t: string, color: Color3)
		status.Text = t
		status.TextColor3 = color
	end
	local function refresh()
		for i = 1, n do
			local on = lights[i]
			lamps[i].BackgroundColor3 = if on then GREEN else Color3.fromRGB(70, 26, 20)
			TweenService:Create(handles[i], TweenInfo.new(0.12, Enum.EasingStyle.Quad), { Position = UDim2.fromScale(0.5, if on then 0.75 else 0.25), BackgroundColor3 = if on then GREEN else RED }):Play()
			local sel = cols[i]:FindFirstChild("Sel") :: UIStroke
			sel.Transparency = if i == selected then 0.1 else 1
		end
		local left = data.budget - presses
		budgetLabel.Text = string.format("PULSACIONES ANTES DEL CORTOCIRCUITO: %d", left)
		bar.Size = UDim2.fromScale(math.clamp(left / data.budget, 0, 1), 1)
		bar.BackgroundColor3 = if left <= 3 then RED else AMBER
	end
	refresh()
	setStatus("Elige una palanca", PAPER)

	local function press(i: number)
		if busy or solved or i < 1 or i > n then
			return
		end
		if workspace:GetServerTimeNow() < lockedUntil then
			return
		end
		selected = i
		busy = true
		local ok, result = pcall(function()
			return puzzleAction:InvokeServer(id, "Press", i)
		end)
		busy = false
		if not session or session.id ~= id or not ok or type(result) ~= "table" then
			return
		end
		if result.err == "LOCKED" then
			lockedUntil = result.lockedUntil or lockedUntil
			return
		end
		if not result.ok then
			refresh()
			return
		end
		lights = result.lights or lights
		presses = result.presses or presses
		play("Lever", 0.9 + math.random() * 0.2)
		if result.solved then
			solved = true
			refresh()
			setStatus("ACCESO CONCEDIDO · PERSIANA SUBIENDO", GREEN)
			play("Lock", 0.9)
			task.delay(1.0, function()
				if session and session.id == id then
					close(false)
				end
			end)
			return
		end
		if result.short then
			lockedUntil = result.lockedUntil or (workspace:GetServerTimeNow() + O.Door.LockoutSeconds)
			play("Spark")
			shake(root, 16)
		end
		refresh()
	end

	local conns: { RBXScriptConnection } = {}
	table.insert(conns, closeBtn.Activated:Connect(function()
		close(true)
	end))
	for i, lever in levers do
		table.insert(conns, lever.Activated:Connect(function()
			task.spawn(press, i)
		end))
	end

	begin({
		kind = "Door",
		id = id,
		root = root,
		closing = false,
		onKey = function(key, down)
			if not down then
				return
			end
			local digit = DIGITS[key]
			if digit then
				task.spawn(press, digit)
			elseif key == Enum.KeyCode.A or key == Enum.KeyCode.Left or key == Enum.KeyCode.DPadLeft then
				selected = math.max(1, selected - 1)
				refresh()
			elseif key == Enum.KeyCode.D or key == Enum.KeyCode.Right or key == Enum.KeyCode.DPadRight then
				selected = math.min(n, selected + 1)
				refresh()
			elseif key == Enum.KeyCode.Space or key == Enum.KeyCode.E or key == Enum.KeyCode.Return or key == Enum.KeyCode.ButtonA then
				task.spawn(press, selected)
			end
		end,
		onStep = function(_dt)
			if solved then
				return
			end
			local wait = lockedUntil - workspace:GetServerTimeNow()
			if wait > 0 then
				setStatus(string.format("¡CORTOCIRCUITO! Panel bloqueado %.1f s", wait), RED)
			elseif status.TextColor3 == RED then
				setStatus("Panel reiniciado: vuelve a intentarlo", PAPER)
			end
		end,
		cleanup = function()
			for _, c in conns do
				c:Disconnect()
			end
		end,
	})
end

puzzleOpen.OnClientEvent:Connect(function(kind: string, id: string, data: any)
	if kind == "Generator" then
		openGenerator(id, data)
	elseif kind == "Safe" then
		openSafe(id, data)
	elseif kind == "Door" then
		openDoor(id, data)
	end
end)

local REASONS: { [string]: string } = {
	TooFar = "Te alejaste demasiado",
	LevelEnded = "El nivel terminó",
}
puzzleClose.OnClientEvent:Connect(function(id: string, reason: string)
	local s = session
	if s and s.id == id and reason == "Done" then
		-- Terminado: deja ver el mensaje de éxito antes de cerrar (si el propio minijuego no lo cerró ya).
		task.delay(1.2, function()
			if session == s then
				close(false)
			end
		end)
	elseif s and s.id == id then
		close(false)
		local msg = REASONS[reason]
		if msg then
			player:SetAttribute("HudNotice", msg .. "|" .. tostring(os.clock()))
		end
	end
end)

-- Morir cierra el minijuego.
player.CharacterAdded:Connect(function()
	close(false)
end)
