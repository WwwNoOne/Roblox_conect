--!strict
-- Vista desde dentro del escondite (atributos de jugador Hidden / HiddenKind que pone Hiding en el servidor):
--  * Locker (taquilla, armario): todo negro salvo las rendijas de la puerta, a la altura de los ojos.
--  * Bush (arbusto): hojas que tapan los bordes y se mecen; el centro queda entre ramas.
--  * Box (cajas antiguas): penumbra con una grieta.
-- Solo interfaz local; no cambia lo que ven los demás.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer

local gui = Instance.new("ScreenGui")
gui.Name = "HidingView"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.DisplayOrder = 5
gui.Enabled = false
gui.Parent = player:WaitForChild("PlayerGui")

local root = Instance.new("CanvasGroup")
root.Size = UDim2.fromScale(1, 1)
root.BackgroundTransparency = 1
root.GroupTransparency = 1
root.Parent = gui

local function frame(parent: Instance, pos: UDim2, size: UDim2, color: Color3, transparency: number?): Frame
	local f = Instance.new("Frame")
	f.Position = pos
	f.Size = size
	f.BackgroundColor3 = color
	f.BackgroundTransparency = transparency or 0
	f.BorderSizePixel = 0
	f.Parent = parent
	return f
end

-- ===== Taquilla: negro con rendijas horizontales
local locker = frame(root, UDim2.new(), UDim2.fromScale(1, 1), Color3.new(), 1)
do
	local dark = Color3.fromRGB(8, 9, 11)
	local top, slitH, barH, n = 0.37, 0.024, 0.02, 5
	frame(locker, UDim2.new(), UDim2.fromScale(1, top), dark)
	local y = top
	for i = 1, n do
		-- rendija: deja ver, con un velo metálico frío en los bordes
		local slit = frame(locker, UDim2.fromScale(0.3, y), UDim2.fromScale(0.4, slitH), Color3.fromRGB(20, 26, 30), 0.55)
		local grad = Instance.new("UIGradient")
		grad.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.2),
			NumberSequenceKeypoint.new(0.2, 1),
			NumberSequenceKeypoint.new(0.8, 1),
			NumberSequenceKeypoint.new(1, 0.2),
		})
		grad.Parent = slit
		frame(locker, UDim2.fromScale(0, y), UDim2.fromScale(0.3, slitH), dark)
		frame(locker, UDim2.fromScale(0.7, y), UDim2.fromScale(0.3, slitH), dark)
		y += slitH
		if i < n then
			frame(locker, UDim2.fromScale(0, y), UDim2.fromScale(1, barH), dark)
			y += barH
		end
	end
	frame(locker, UDim2.fromScale(0, y), UDim2.fromScale(1, 1 - y), dark)
end

-- ===== Arbusto: hojas en los bordes
local bush = frame(root, UDim2.new(), UDim2.fromScale(1, 1), Color3.fromRGB(10, 22, 12), 0.55)
local leaves: { { f: Frame, base: number, phase: number } } = {}
do
	local rng = Random.new(7)
	local greens = { Color3.fromRGB(26, 52, 28), Color3.fromRGB(34, 66, 34), Color3.fromRGB(20, 40, 22), Color3.fromRGB(44, 78, 40) }
	for i = 1, 26 do
		-- en el borde: ángulo alrededor del centro, radio grande
		local a = (i / 26) * math.pi * 2 + rng:NextNumber(-0.1, 0.1)
		local r = rng:NextNumber(0.42, 0.56)
		local cx, cy = 0.5 + math.cos(a) * r, 0.5 + math.sin(a) * r * 0.9
		local s = rng:NextNumber(0.22, 0.38)
		local f = frame(bush, UDim2.fromScale(cx, cy), UDim2.fromScale(s, s * 0.55), greens[rng:NextInteger(1, #greens)],
			rng:NextNumber(0, 0.15))
		f.AnchorPoint = Vector2.new(0.5, 0.5)
		f.Rotation = math.deg(a) + 90 + rng:NextNumber(-25, 25)
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(1, 0)
		corner.Parent = f
		table.insert(leaves, { f = f, base = f.Rotation, phase = rng:NextNumber(0, 6) })
	end
end

-- ===== Caja
local box = frame(root, UDim2.new(), UDim2.fromScale(1, 1), Color3.fromRGB(10, 9, 8), 0.25)
frame(box, UDim2.fromScale(0.2, 0.47), UDim2.fromScale(0.6, 0.012), Color3.fromRGB(40, 36, 30), 0.6)

local hint = Instance.new("TextLabel")
hint.AnchorPoint = Vector2.new(0.5, 1)
hint.Position = UDim2.fromScale(0.5, 0.94)
hint.Size = UDim2.fromScale(0.5, 0.04)
hint.BackgroundTransparency = 1
hint.Font = Enum.Font.GothamMedium
hint.TextScaled = true
hint.TextColor3 = Color3.fromRGB(200, 200, 190)
hint.TextTransparency = 0.25
hint.Text = "Escondido · mantén E para salir"
hint.Parent = root
local hintSize = Instance.new("UITextSizeConstraint")
hintSize.MaxTextSize = 20
hintSize.Parent = hint

local swayConn: RBXScriptConnection? = nil
local function show(kind: string?)
	locker.Visible = kind == "Locker"
	bush.Visible = kind == "Bush"
	box.Visible = kind ~= "Locker" and kind ~= "Bush"
	gui.Enabled = true
	TweenService:Create(root, TweenInfo.new(0.25), { GroupTransparency = 0 }):Play()
	if kind == "Bush" and not swayConn then
		swayConn = RunService.RenderStepped:Connect(function()
			local t = os.clock()
			for _, l in leaves do
				l.f.Rotation = l.base + math.sin(t * 0.9 + l.phase) * 3
			end
		end)
	end
end

local function hide()
	if swayConn then
		swayConn:Disconnect()
		swayConn = nil
	end
	local tw = TweenService:Create(root, TweenInfo.new(0.2), { GroupTransparency = 1 })
	tw.Completed:Connect(function()
		if not player:GetAttribute("Hidden") then
			gui.Enabled = false
		end
	end)
	tw:Play()
end

local function refresh()
	if player:GetAttribute("Hidden") then
		show(player:GetAttribute("HiddenKind") :: string?)
	else
		hide()
	end
end
player:GetAttributeChangedSignal("Hidden"):Connect(refresh)
player:GetAttributeChangedSignal("HiddenKind"):Connect(refresh)
refresh()
