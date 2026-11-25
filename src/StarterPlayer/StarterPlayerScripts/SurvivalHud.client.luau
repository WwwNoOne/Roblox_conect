--!strict
-- Interfaz de supervivencia (sustituye al panel de datos de GameHud, que queda solo con el reloj y los avisos). Estética de oficina liminal: tinta casi negra, papel envejecido, ámbar de
-- fluorescente y rojo de alarma; tipografía monoespaciada. Parámetros: Config.Hud.
--   * Vida (abajo a la izquierda): barra segmentada con rastro blanco del daño que se encoge con retardo; tiembla al recibir daño
--     y se vuelve roja con poca vida (más viñeta roja y desaturación de la pantalla que laten con el corazón).
--   * Estamina: tira fina justo encima de la vida; aparece al gastarla y se oculta llena. Agotado: parpadea en rojo y oscurece bordes.
--   * Ranuras (abajo al centro): una por hueco de carga con su tecla, icono del objeto (hoja de iconos de Codex si está; si no, un
--     código de texto), ocupación y cuánta velocidad quita el peso (MovementController).
--   * Cuota (arriba a la derecha): nivel, depositado / cuota del piso, barra, fondo común y cuotas falladas. Verde al cumplirse.
--   * Linterna: indicador en la cabecera de la vida (atributo LampOn).
-- En táctil la vida y la estamina suben arriba a la izquierda para no chocar con el joystick.
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Types = require(Shared:WaitForChild("Types"))
local MotionState = require(script.Parent:WaitForChild("MotionState"))
local H = Config.Hud
local updateHud = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("UpdateHUD") :: RemoteEvent

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- ===== Paleta y tipografía =====
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
	f.BackgroundTransparency = 0.32
	f.BorderSizePixel = 0
	new("UICorner", { CornerRadius = UDim.new(0, 3) }, f)
	new("UIStroke", { Color = PAPER, Transparency = 0.86, Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, f)
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

local function bar(parent: Instance, y: number, height: number, color: Color3): (Frame, Frame, Frame)
	local track = new("Frame", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 12, 1, y),
		Size = UDim2.new(1, -24, 0, height),
		BackgroundColor3 = PAPER,
		BackgroundTransparency = 0.88,
		BorderSizePixel = 0,
	}, parent)
	local ghost = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = PAPER, BackgroundTransparency = 0.35, BorderSizePixel = 0 }, track)
	local fill = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = color, BorderSizePixel = 0 }, track)
	return track, ghost, fill
end

-- ===== Pantallas =====
local gui = new("ScreenGui", { Name = "SurvivalHud", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 5, ZIndexBehavior = Enum.ZIndexBehavior.Sibling }, playerGui)
local fxGui = new("ScreenGui", { Name = "SurvivalFx", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 1 }, playerGui)

-- Escala con la altura de la pantalla (diseñado a 1080 px)
local scaled: { UIScale } = {}
local function scaleOf(frame: GuiObject)
	table.insert(scaled, new("UIScale", {}, frame))
end

-- ===== Vida =====
local vitals = panel({ Name = "Vida", AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 28, 1, -28), Size = UDim2.fromOffset(320, 58) }, gui)
scaleOf(vitals)
text({ Text = "VIDA", TextSize = 13, TextColor3 = DIM, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(12, 8), Size = UDim2.fromOffset(100, 16) }, vitals)
local healthValue = text({ Text = "100", TextSize = 17, FontFace = MONO_BOLD, TextXAlignment = Enum.TextXAlignment.Right, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 5), Size = UDim2.fromOffset(100, 20) }, vitals)
local lampLabel = text({ Text = "", TextSize = 12, TextColor3 = DIM, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 9), Size = UDim2.fromOffset(150, 14) }, vitals)
local healthTrack, healthGhost, healthFill = bar(vitals, -12, 12, PAPER)
for i = 1, 9 do
	new("Frame", { Position = UDim2.new(i / 10, -1, 0, 0), Size = UDim2.new(0, 2, 1, 0), BackgroundColor3 = INK, BackgroundTransparency = 0.25, BorderSizePixel = 0, ZIndex = 3 }, healthTrack)
end

-- ===== Estamina =====
local staminaGroup = new("CanvasGroup", { Name = "Estamina", AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 28, 1, -92), Size = UDim2.fromOffset(320, 34), BackgroundTransparency = 1, GroupTransparency = 1 }, gui)
scaleOf(staminaGroup)
local staminaPanel = panel({ Size = UDim2.fromScale(1, 1) }, staminaGroup)
local staminaLabel = text({ Text = "ESTAMINA", TextSize = 12, TextColor3 = DIM, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(12, 3), Size = UDim2.fromOffset(200, 14) }, staminaPanel)
local _staminaTrack, staminaGhost, staminaFill = bar(staminaPanel, -8, 5, AMBER)
staminaGhost.BackgroundTransparency = 1

-- ===== Ranuras =====
local slotsHolder = new("Frame", { Name = "Ranuras", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -28), Size = UDim2.fromOffset(280, 88), BackgroundTransparency = 1, Visible = false }, gui)
scaleOf(slotsHolder)
local carryLabel = text({ Text = "CARGA 0/4", TextSize = 12, TextColor3 = DIM, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.fromOffset(160, 16) }, slotsHolder)
local weightLabel = text({ Text = "", TextSize = 12, TextColor3 = AMBER, TextXAlignment = Enum.TextXAlignment.Right, AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.fromOffset(160, 16) }, slotsHolder)
local slotRow = new("Frame", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromScale(0.5, 1), Size = UDim2.fromOffset(280, 64), BackgroundTransparency = 1 }, slotsHolder)
new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, slotRow)

type Slot = { frame: Frame, stroke: UIStroke, icon: ImageLabel, code: TextLabel, pop: UIScale, occupied: boolean }
local slots: { Slot } = {}

-- Hoja de iconos de Codex (la interfaz antigua sigue en PlayerGui, desactivada): glifo -> recorte.
type Glyph = { image: string, offset: Vector2, size: Vector2 }
local glyphs: { [string]: Glyph } = {}
task.spawn(function()
	local old = playerGui:WaitForChild("Abismo_HUD_Buceo", 8)
	if old then
		for _, d in old:GetDescendants() do
			local g = d:GetAttribute("Glifo")
			if type(g) == "string" and d:IsA("ImageLabel") and glyphs[g] == nil and d.Image ~= "" then
				glyphs[g] = { image = d.Image, offset = d.ImageRectOffset, size = d.ImageRectSize }
			end
		end
	end
end)

local function makeSlot(i: number): Slot
	local f = panel({ Name = "Ranura_" .. i, Size = UDim2.fromOffset(64, 64), LayoutOrder = i }, slotRow)
	local stroke = f:FindFirstChildOfClass("UIStroke") :: UIStroke
	text({ Text = tostring(i), TextSize = 10, TextColor3 = DIM, Position = UDim2.fromOffset(5, 3), Size = UDim2.fromOffset(10, 12), TextXAlignment = Enum.TextXAlignment.Left }, f)
	local icon = new("ImageLabel", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.55), Size = UDim2.fromOffset(38, 38), BackgroundTransparency = 1, Visible = false, ScaleType = Enum.ScaleType.Fit }, f)
	local code = text({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.55), Size = UDim2.fromScale(1, 0.5), TextSize = 14, FontFace = MONO_BOLD, TextColor3 = AMBER, Text = "" }, f)
	return { frame = f, stroke = stroke, icon = icon, code = code, pop = new("UIScale", {}, f), occupied = false }
end

-- ===== Cuota =====
local quotaPanel = panel({ Name = "Cuota", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -28, 0, 64), Size = UDim2.fromOffset(270, 82), Visible = false }, gui)
scaleOf(quotaPanel)
local quotaTitle = text({ Text = "CUOTA", TextSize = 12, TextColor3 = DIM, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(12, 8), Size = UDim2.fromOffset(160, 14) }, quotaPanel)
local moneyLabel = text({ Text = "", TextSize = 12, TextColor3 = DIM, TextXAlignment = Enum.TextXAlignment.Right, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 8), Size = UDim2.fromOffset(120, 14) }, quotaPanel)
local quotaValue = text({ Text = "0 / 0", TextSize = 22, FontFace = MONO_BOLD, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(12, 24), Size = UDim2.fromOffset(180, 26), RichText = true }, quotaPanel)
local failLabel = text({ Text = "", TextSize = 11, TextColor3 = RED, TextXAlignment = Enum.TextXAlignment.Right, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 31), Size = UDim2.fromOffset(90, 14) }, quotaPanel)
local _quotaTrack, quotaGhost, quotaFill = bar(quotaPanel, -12, 6, AMBER)
quotaGhost.BackgroundTransparency = 1

-- ===== Viñeta y color de pantalla =====
local function edge(anchor: Vector2, pos: UDim2, size: UDim2, rotation: number): Frame
	local f = new("Frame", { AnchorPoint = anchor, Position = pos, Size = size, BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, BackgroundTransparency = 0 }, fxGui)
	new("UIGradient", { Rotation = rotation, Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) }) }, f)
	return f
end
local edges = {
	edge(Vector2.new(0, 0), UDim2.fromScale(0, 0), UDim2.fromScale(1, 0.28), 90),
	edge(Vector2.new(0, 1), UDim2.fromScale(0, 1), UDim2.fromScale(1, 0.28), -90),
	edge(Vector2.new(0, 0), UDim2.fromScale(0, 0), UDim2.fromScale(0.2, 1), 0),
	edge(Vector2.new(1, 0), UDim2.fromScale(1, 0), UDim2.fromScale(0.2, 1), 180),
}
local grade = Instance.new("ColorCorrectionEffect")
grade.Name = "SurvivalGrade"
grade.Parent = Lighting

-- ===== Disposición por dispositivo y escala =====
local function layout()
	local touch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	if touch then
		vitals.AnchorPoint, vitals.Position = Vector2.new(0, 0), UDim2.fromOffset(16, 60)
		staminaGroup.AnchorPoint, staminaGroup.Position = Vector2.new(0, 0), UDim2.fromOffset(16, 124)
	else
		vitals.AnchorPoint, vitals.Position = Vector2.new(0, 1), UDim2.new(0, 28, 1, -28)
		staminaGroup.AnchorPoint, staminaGroup.Position = Vector2.new(0, 1), UDim2.new(0, 28, 1, -92)
	end
	local camera = workspace.CurrentCamera
	local s = if camera then math.clamp(camera.ViewportSize.Y / 1000, 0.9, 1.35) else 1
	if touch then
		s = math.max(s, 0.8)
	end
	for _, sc in scaled do
		sc.Scale = s
	end
end
layout()
UserInputService.LastInputTypeChanged:Connect(layout)
local function watchCamera()
	local camera = workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(layout)
	end
end
watchCamera()
workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
	watchCamera()
	layout()
end)

-- ===== Datos =====
local health, maxHealth = 100, 100
local shownHealth, ghostHealth = 1, 1
local ghostHoldUntil = 0
local shakeUntil = 0
local staminaShown = 1
local fullSince = 0
local quotaShown = 0
local lastQuota: Types.HudPayload? = nil

local healthConn: RBXScriptConnection? = nil
local function watchCharacter(character: Model)
	if healthConn then
		healthConn:Disconnect()
	end
	local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	if not humanoid then
		return
	end
	health, maxHealth = humanoid.Health, humanoid.MaxHealth
	shownHealth, ghostHealth = 1, 1
	healthConn = humanoid.HealthChanged:Connect(function(newHealth)
		if newHealth < health - 0.5 then
			ghostHoldUntil = os.clock() + H.DamageTrailDelay
			shakeUntil = os.clock() + 0.28
		end
		health, maxHealth = newHealth, humanoid.MaxHealth
	end)
end
if player.Character then
	task.spawn(watchCharacter, player.Character)
end
player.CharacterAdded:Connect(watchCharacter)

local function refreshSlots()
	local capacity = player:GetAttribute("CarryCapacity")
	local cap = if type(capacity) == "number" and capacity > 0 then capacity else Config.Economy.CarrySlots
	local count = player:GetAttribute("CarryCount")
	local n = if type(count) == "number" then count else 0
	local raw = player:GetAttribute("CarryGlyphs")
	local list = if type(raw) == "string" and raw ~= "" then string.split(raw, ",") else {}
	while #slots < cap do
		table.insert(slots, makeSlot(#slots + 1))
	end
	slotRow.Size = UDim2.fromOffset(cap * 64 + (cap - 1) * 8, 64)
	slotsHolder.Size = UDim2.fromOffset(math.max(280, cap * 72), 88)
	for i, s in slots do
		s.frame.Visible = i <= cap
		local occupied = i <= n
		if occupied and not s.occupied then
			s.pop.Scale = 1.18
			TweenService:Create(s.pop, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		end
		s.occupied = occupied
		s.stroke.Color = if occupied then AMBER else PAPER
		s.stroke.Transparency = if occupied then 0.25 else 0.86
		s.frame.BackgroundColor3 = if occupied then Color3.fromRGB(40, 33, 18) else INK
		local glyph = list[i] or Config.Economy.DefaultGlyph
		local art = if occupied then glyphs[glyph] else nil
		s.icon.Visible = art ~= nil
		if art then
			s.icon.Image, s.icon.ImageRectOffset, s.icon.ImageRectSize = art.image, art.offset, art.size
		end
		s.code.Text = if occupied and not art then ((H.Glyphs :: any)[glyph] or "OBJ") else ""
	end
	carryLabel.Text = string.format("CARGA %d/%d", n, cap)
	local penalty = math.min(n * Config.Movement.CarryPenaltyPerItem, 0.5)
	weightLabel.Text = if penalty > 0 then string.format("PESO  -%d%% VEL", math.floor(penalty * 100 + 0.5)) else ""
end
refreshSlots()
for _, attr in { "CarryCount", "CarryCapacity", "CarryGlyphs" } do
	player:GetAttributeChangedSignal(attr):Connect(refreshSlots)
end

updateHud.OnClientEvent:Connect(function(payload: Types.HudPayload)
	lastQuota = payload
end)

-- ===== Bucle de dibujo =====
local function smooth(current: number, target: number, rate: number, dt: number): number
	return current + (target - current) * (1 - math.exp(-rate * dt))
end

RunService.RenderStepped:Connect(function(dt)
	local now = os.clock()
	local inRun = player:GetAttribute("InRun") == true
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	local alive = humanoid ~= nil and humanoid.Health > 0
	gui.Enabled = alive

	-- Vida
	local ratio = if maxHealth > 0 then math.clamp(health / maxHealth, 0, 1) else 0
	shownHealth = smooth(shownHealth, ratio, 14, dt)
	if now >= ghostHoldUntil then
		ghostHealth = smooth(ghostHealth, shownHealth, 5, dt)
	end
	ghostHealth = math.max(ghostHealth, shownHealth)
	healthFill.Size = UDim2.fromScale(shownHealth, 1)
	healthGhost.Size = UDim2.fromScale(ghostHealth, 1)
	local low = ratio <= H.LowHealth
	healthFill.BackgroundColor3 = if low then RED else PAPER
	healthValue.Text = tostring(math.ceil(math.max(health, 0)))
	healthValue.TextColor3 = if low then RED else PAPER
	local shake = if now < shakeUntil then (shakeUntil - now) / 0.28 else 0
	vitals.Rotation = if shake > 0 then math.sin(now * 70) * 1.2 * shake else 0

	local lampOn = player:GetAttribute("LampOn") == true
	lampLabel.Text = if lampOn then "LUZ ON [F]" else "LUZ OFF [F]"
	lampLabel.TextColor3 = if lampOn then AMBER else DIM

	-- Estamina
	local st, stMax = player:GetAttribute("Stamina"), player:GetAttribute("StaminaMax")
	local sRatio = if inRun and type(st) == "number" and type(stMax) == "number" and stMax > 0 then math.clamp(st / stMax, 0, 1) else 1
	local exhausted = inRun and player:GetAttribute("Exhausted") == true
	staminaShown = smooth(staminaShown, sRatio, 12, dt)
	staminaFill.Size = UDim2.fromScale(staminaShown, 1)
	if sRatio < 0.995 or exhausted or MotionState.sprinting then
		fullSince = now
	end
	local showStamina = alive and now - fullSince < H.StaminaHideAfter
	staminaGroup.GroupTransparency = smooth(staminaGroup.GroupTransparency, if showStamina then 0 else 1, 8, dt)
	if exhausted then
		local on = math.floor(now * 5) % 2 == 0
		staminaFill.BackgroundColor3 = if on then RED else Color3.fromRGB(120, 40, 32)
		staminaLabel.Text = "AGOTADO"
		staminaLabel.TextColor3 = RED
	else
		staminaFill.BackgroundColor3 = if sRatio < 0.3 then Color3.fromRGB(214, 130, 60) else AMBER
		staminaLabel.Text = if MotionState.crouching then "ESTAMINA · AGACHADO" else "ESTAMINA"
		staminaLabel.TextColor3 = DIM
	end

	-- Ranuras
	slotsHolder.Visible = inRun

	-- Cuota
	local q = lastQuota
	local quota = q and q.quota
	quotaPanel.Visible = inRun and quota ~= nil and quota > 0
	if q and quota and quota > 0 then
		local deposited = q.deposited or 0
		local done = deposited >= quota
		quotaShown = smooth(quotaShown, math.clamp(deposited / quota, 0, 1), 6, dt)
		quotaFill.Size = UDim2.fromScale(quotaShown, 1)
		quotaFill.BackgroundColor3 = if done then GREEN else AMBER
		local where = if q.runState == "Stopover" then "PARADA · PRÓXIMA" elseif q.zone then string.format("NIVEL %d ·", math.max(1, q.zone)) else ""
		quotaTitle.Text = if done then where .. " CUMPLIDA" else where .. " CUOTA"
		quotaTitle.TextColor3 = if done then GREEN else DIM
		quotaValue.Text = string.format('%d <font color="#968F7C">/ %d</font>', deposited, quota)
		moneyLabel.Text = if q.money then string.format("FONDO $%d", q.money) else ""
		local fails = q.failures or 0
		failLabel.Text = if fails > 0 then string.format("FALLOS %d/%d", fails, Config.Economy.Quota.MaxFailures) else ""
	end

	-- Viñeta: roja con poca vida (late), oscura al agotarse
	local danger = if alive then math.clamp(1 - ratio / H.LowHealth, 0, 1) else 0
	local pulse = 0.5 + 0.5 * math.sin(now * (5 + danger * 4))
	local redAmount = danger * (0.55 + 0.25 * pulse)
	local darkAmount = if exhausted then 0.35 else MotionState.exertion * 0.15
	local strength = math.max(redAmount, darkAmount)
	local color = if redAmount >= darkAmount then Color3.fromRGB(110, 8, 4) else Color3.new(0, 0, 0)
	for _, e in edges do
		e.BackgroundColor3 = color
		e.BackgroundTransparency = 1 - strength
	end
	grade.Saturation = smooth(grade.Saturation, -0.55 * danger, 4, dt)
	grade.TintColor = Color3.new(1, 1 - 0.12 * danger, 1 - 0.12 * danger)
end)
