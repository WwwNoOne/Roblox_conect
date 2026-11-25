--!strict
-- Panel del submarino: casco, Reparar (solo en la Parada), Salir (solo en niveles) y Avanzar (cuenta atrás de 60 s
-- para que entren los demás; solo, parte ya). Se abre con E junto al indicador de casco (HullGauge.Screen).
-- Teclado: 1 reparar, 2 salir, 3 avanzar, X cerrar (en PC, además, el panel libera el cursor: FirstPersonClient).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Types = require(Shared:WaitForChild("Types"))
local WorldRefs = require(Shared:WaitForChild("WorldRefs"))
local UiArt = require(Shared:WaitForChild("UiArt"))
local Sfx = require(Shared:WaitForChild("Sfx"))
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local updateHud = remotes:WaitForChild("UpdateHUD") :: RemoteEvent
local requestDescend = remotes:WaitForChild("RequestDescend") :: RemoteFunction
local requestExit = remotes:WaitForChild("RequestExit") :: RemoteFunction
local requestPurchase = remotes:WaitForChild("RequestPurchase") :: RemoteFunction
local player = Players.LocalPlayer

local MESSAGES: { [string]: string } = {
	NOT_INSIDE = "Debes estar dentro del submarino",
	NOT_DOCKED = "El submarino está en movimiento",
	NOT_LEVEL = "Solo se sale en los niveles",
	NOT_AT_PARADA = "Solo se repara en la parada",
	HULL_FULL = "El casco está intacto",
	NOT_ENOUGH_MONEY = "No hay dinero suficiente",
	ALREADY_COUNTING = "Ya hay una cuenta atrás en marcha",
	ALREADY_AT_BOTTOM = "Este es el último nivel",
}

local gui = Instance.new("ScreenGui")
gui.Name = "SubPanel"
gui.ResetOnSpawn = false
gui.Enabled = false
gui.Parent = player:WaitForChild("PlayerGui")

-- Placa de acero generada (UiArt.Panel, 9-slice); el contenido va encima, en un marco transparente con márgenes.
local frame = Instance.new("ImageLabel")
frame.Name = "Plate"
frame.AnchorPoint = Vector2.new(0.5, 0.5)
frame.Position = UDim2.fromScale(0.5, 0.5)
frame.Size = UDim2.fromOffset(420, 430)
UiArt.Apply(frame, UiArt.Panel, 0.45)
frame.Parent = gui
local sizeLimit = Instance.new("UISizeConstraint")
sizeLimit.MaxSize = Vector2.new(420, 430)
sizeLimit.Parent = frame
local scale = Instance.new("UIScale") -- pantallas pequeñas: encoge el panel entero
scale.Parent = frame
local function fitScale()
	local cam = workspace.CurrentCamera
	local vp = if cam then cam.ViewportSize else Vector2.new(1280, 720)
	scale.Scale = math.min(1, (vp.Y - 40) / 430, (vp.X - 20) / 420)
end
fitScale()
if workspace.CurrentCamera then
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fitScale)
end

local content = Instance.new("Frame")
content.BackgroundTransparency = 1
content.Position = UDim2.fromOffset(34, 30)
content.Size = UDim2.new(1, -68, 1, -60)
content.Parent = frame
local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 7)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = content

local TEXT = Color3.fromRGB(205, 225, 222)
local ACCENT = Color3.fromRGB(120, 230, 230)
local order = 0
local function nextOrder(): number
	order += 1
	return order
end

local function text(size: number, color: Color3, height: number, parent: Instance?): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size = UDim2.new(1, 0, 0, height)
	l.Font = Enum.Font.GothamBold
	l.TextSize = size
	l.TextColor3 = color
	l.TextWrapped = true
	l.Text = ""
	l.LayoutOrder = nextOrder()
	l.Parent = parent or content
	return l
end

-- Fila con icono a la izquierda y texto.
local function iconRow(piece: UiArt.Piece, size: number, color: Color3): TextLabel
	local row = Instance.new("Frame")
	row.BackgroundTransparency = 1
	row.Size = UDim2.new(1, 0, 0, 24)
	row.LayoutOrder = nextOrder()
	row.Parent = content
	local ic = UiArt.Icon(piece, 22, row)
	ic.Position = UDim2.fromOffset(0, 1)
	local l = text(size, color, 24, row)
	l.Position = UDim2.fromOffset(30, 0)
	l.Size = UDim2.new(1, -30, 1, 0)
	l.TextXAlignment = Enum.TextXAlignment.Left
	return l
end

local title = text(19, ACCENT, 26)
title.Text = "PANEL DEL SUBMARINO"
local hullLabel = iconRow(UiArt.Icons.Hull, 16, TEXT)

local barBg = Instance.new("Frame")
barBg.Size = UDim2.new(1, 0, 0, 12)
barBg.BackgroundColor3 = Color3.fromRGB(12, 20, 22)
barBg.BorderSizePixel = 0
barBg.LayoutOrder = nextOrder()
barBg.Parent = content
local barStroke = Instance.new("UIStroke")
barStroke.Color = Color3.fromRGB(70, 90, 92)
barStroke.Thickness = 1
barStroke.Parent = barBg
local bar = Instance.new("Frame")
bar.Size = UDim2.fromScale(1, 1)
bar.BorderSizePixel = 0
bar.Parent = barBg

local moneyLabel = iconRow(UiArt.Icons.Money, 15, Color3.fromRGB(235, 210, 140))
local status = text(14, Color3.fromRGB(170, 215, 225), 34)

local function playClick()
	Sfx.Play(Config.Sfx.PanelClick, nil, 0.6)
end

-- Botón con el arte de consola; el icono va a la izquierda del texto.
local actions: { [string]: () -> () } = {} -- tecla -> acción del botón

local function button(label: string, piece: UiArt.Piece?, onClick: () -> (), key: string): TextButton
	local holder = Instance.new("ImageButton")
	holder.Size = UDim2.new(1, 0, 0, 46)
	holder.AutoButtonColor = false
	holder.LayoutOrder = nextOrder()
	UiArt.Apply(holder, UiArt.Button, 0.22)
	holder.Parent = content
	local b = Instance.new("TextButton")
	b.BackgroundTransparency = 1
	b.Size = UDim2.fromScale(1, 1)
	b.Font = Enum.Font.GothamBold
	b.TextSize = 15
	b.TextColor3 = TEXT
	b.Text = string.format("[%s] %s", key, label)
	b.Parent = holder
	if piece then
		local ic = UiArt.Icon(piece, 20, holder)
		ic.AnchorPoint = Vector2.new(0, 0.5)
		ic.Position = UDim2.new(0, 22, 0.5, 0)
	end
	local press = Instance.new("UIScale")
	press.Parent = holder
	b.MouseButton1Down:Connect(function()
		if b.Active then
			press.Scale = 0.97
		end
	end)
	b.MouseButton1Up:Connect(function()
		press.Scale = 1
	end)
	b.MouseLeave:Connect(function()
		press.Scale = 1
	end)
	local function run()
		if b.Active then
			playClick()
			onClick()
		end
	end
	actions[key] = run
	b.Activated:Connect(run)
	return b
end

local function setEnabled(b: TextButton, on: boolean)
	b.Active = on
	local holder = b.Parent :: ImageButton
	holder.ImageColor3 = if on then Color3.new(1, 1, 1) else Color3.fromRGB(110, 110, 110)
	b.TextTransparency = if on then 0 else 0.55
end

local last: Types.HudPayload? = nil

local function say(err: string?)
	status.Text = if err then (MESSAGES[err] or err) else ""
end

local repairBtn = button("Reparar casco", UiArt.Icons.Repair, function()
	local r = requestPurchase:InvokeServer("Repair")
	say(if r and not r.ok then r.err else nil)
end, "1")
local exitBtn = button("Salir del submarino", UiArt.Icons.Exit, function()
	local r = requestExit:InvokeServer()
	if r and r.ok then
		gui.Enabled = false
	else
		say(if r then r.err else nil)
	end
end, "2")
local advanceBtn = button("Avanzar al siguiente nivel", UiArt.Icons.Depth, function()
	local r = requestDescend:InvokeServer()
	if r and r.ok then
		if r.counting then
			status.Text = string.format("Cuenta atrás: los demás tienen %d s para entrar", Config.Run.AdvanceCountdown)
		else
			gui.Enabled = false
		end
	else
		say(if r then r.err else nil)
	end
end, "3")
local closeBtn = button("Cerrar", nil, function()
	gui.Enabled = false
end, "X")
closeBtn.TextColor3 = Color3.fromRGB(230, 150, 140)

local function refresh()
	local p = last
	if not p or not p.hull or not p.hullMax then
		return
	end
	local ratio = math.clamp(p.hull / p.hullMax, 0, 1)
	hullLabel.Text = string.format("Casco: %d / %d", p.hull, p.hullMax)
	bar.Size = UDim2.fromScale(ratio, 1)
	bar.BackgroundColor3 = if ratio < 0.3 then Color3.fromRGB(255, 70, 70) elseif ratio < 0.6 then Color3.fromRGB(255, 190, 60) else Color3.fromRGB(80, 220, 140)
	moneyLabel.Text = string.format("Fondo común: $%d", p.money or 0)
	local state = p.runState
	setEnabled(repairBtn, state == "Stopover" and p.hull < p.hullMax)
	setEnabled(exitBtn, state == "Level")
	local canAdvance = (state == "Level" or state == "Stopover") and (p.zone or 0) < #Config.Run.Stages and p.advanceIn == nil
	setEnabled(advanceBtn, canAdvance)
	advanceBtn.Text = if p.advanceIn then string.format("[3] Partiendo en %d s...", p.advanceIn) else "[3] Avanzar al siguiente nivel"
	if p.advanceIn then
		status.Text = "Todos deben estar dentro del submarino antes de que termine la cuenta"
	end
	if state == "Descending" or state == "Won" or state == "Lost" then
		gui.Enabled = false
	end
end

updateHud.OnClientEvent:Connect(function(payload: Types.HudPayload)
	last = payload
	refresh()
end)

-- Prompt en el indicador de casco (se crea en el cliente: solo lo ve y usa este jugador).
task.spawn(function()
	-- Con StreamingEnabled el submarino y sus piezas llegan poco a poco: se reintenta hasta que aparezcan.
	local sub: Model? = nil
	local anchor: Instance? = nil
	local deadline = os.clock() + 90
	while os.clock() < deadline do
		sub = WorldRefs.Submarine()
		local gauge = sub and sub:FindFirstChild("HullGauge", true)
		anchor = gauge and (gauge:FindFirstChild("Screen") or gauge:FindFirstChildWhichIsA("BasePart", true))
		if anchor and anchor:IsA("BasePart") then
			break
		end
		task.wait(1)
	end
	if not sub or not anchor or not anchor:IsA("BasePart") then
		warn("[SubPanel] Falta HullGauge.Screen para el panel del submarino")
		return
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "SubPanelPrompt"
	prompt.ActionText = "Panel del submarino"
	prompt.ObjectText = "Casco"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0.2
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	-- El prompt va en un Attachment adelantado hacia el interior (el indicador está pegado a la pared) y más abajo,
	-- a la altura de las estaciones, para alcanzarlo desde dentro del submarino como el resto de paneles.
	local zone = sub and sub:FindFirstChild("InteriorZone", true)
	local toInside = if zone and zone:IsA("BasePart") then Vector3.new(zone.Position.X - anchor.Position.X, 0, zone.Position.Z - anchor.Position.Z) else Vector3.zero
	local att = Instance.new("Attachment")
	att.Name = "SubPanelAttachment"
	att.Parent = anchor -- primero el padre: WorldPosition solo es mundo con el Attachment ya dentro de una pieza
	att.WorldPosition = anchor.Position + (if toInside.Magnitude > 0.1 then toInside.Unit * 5 else Vector3.zero) - Vector3.new(0, 3, 0)
	prompt.Parent = att
	prompt.Triggered:Connect(function()
		if player:GetAttribute("InRun") == true then
			status.Text = ""
			gui.Enabled = true
			refresh()
		end
	end)
end)

local KEYS = {
	[Enum.KeyCode.One] = "1",
	[Enum.KeyCode.Two] = "2",
	[Enum.KeyCode.Three] = "3",
	[Enum.KeyCode.X] = "X",
}
UserInputService.InputBegan:Connect(function(input, processed)
	if processed or not gui.Enabled then
		return
	end
	local key = KEYS[input.KeyCode]
	local action = if key then actions[key] else nil
	if action then
		action()
	end
end)
