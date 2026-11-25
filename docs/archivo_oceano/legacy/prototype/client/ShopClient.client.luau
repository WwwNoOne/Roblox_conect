--!strict
-- UI provisional de la tienda (Codex hará la versión final). Se abre con el prompt "ShopPrompt".
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local purchase = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("RequestPurchase") :: RemoteFunction
local player = Players.LocalPlayer
local coins = player:WaitForChild("leaderstats"):WaitForChild("Coins") :: IntValue

local ids: { string } = {}
for id in Config.Upgrades do
	table.insert(ids, id)
end
table.sort(ids, function(a, b)
	return Config.Upgrades[a].Order < Config.Upgrades[b].Order
end)

local gui = Instance.new("ScreenGui")
gui.Name = "Shop"
gui.ResetOnSpawn = false
gui.Enabled = false
gui.Parent = player:WaitForChild("PlayerGui")

local frame = Instance.new("Frame")
frame.AnchorPoint = Vector2.new(0.5, 0.5)
frame.Position = UDim2.fromScale(0.5, 0.5)
frame.Size = UDim2.fromOffset(400, 80 + #ids * 56)
frame.BackgroundColor3 = Color3.fromRGB(10, 30, 50)
frame.BackgroundTransparency = 0.1
frame.Parent = gui
Instance.new("UICorner").Parent = frame

local function label(text: string, pos: UDim2, size: UDim2, align: Enum.TextXAlignment, parent: Instance): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Position = pos
	l.Size = size
	l.TextXAlignment = align
	l.Font = Enum.Font.GothamMedium
	l.TextSize = 16
	l.TextColor3 = Color3.new(1, 1, 1)
	l.Text = text
	l.Parent = parent
	return l
end

label("Tienda del puerto", UDim2.fromOffset(12, 8), UDim2.fromOffset(220, 28), Enum.TextXAlignment.Left, frame).Font =
	Enum.Font.GothamBold
local coinsLabel = label("", UDim2.fromOffset(12, 38), UDim2.fromOffset(220, 24), Enum.TextXAlignment.Left, frame)

local close = Instance.new("TextButton")
close.Position = UDim2.new(1, -44, 0, 8)
close.Size = UDim2.fromOffset(32, 28)
close.Text = "X"
close.Font = Enum.Font.GothamBold
close.TextSize = 16
close.Parent = frame
close.Activated:Connect(function()
	gui.Enabled = false
end)

local rows: { [string]: { level: TextLabel, button: TextButton } } = {}
for i, id in ids do
	local def = Config.Upgrades[id]
	local y = 70 + (i - 1) * 56
	label(def.Name, UDim2.fromOffset(12, y), UDim2.fromOffset(200, 24), Enum.TextXAlignment.Left, frame)
	local level = label("", UDim2.fromOffset(12, y + 24), UDim2.fromOffset(200, 20), Enum.TextXAlignment.Left, frame)
	level.TextSize = 13
	local button = Instance.new("TextButton")
	button.Position = UDim2.new(1, -152, 0, y + 4)
	button.Size = UDim2.fromOffset(140, 36)
	button.Font = Enum.Font.GothamBold
	button.TextSize = 15
	button.Parent = frame
	Instance.new("UICorner").Parent = button
	button.Activated:Connect(function()
		purchase:InvokeServer(id)
	end)
	rows[id] = { level = level, button = button }
end

local function refresh()
	coinsLabel.Text = "Monedas: " .. coins.Value
	for _, id in ids do
		local def = Config.Upgrades[id]
		local row = rows[id]
		local lvl = player:GetAttribute("Up_" .. id) or 0
		row.level.Text = string.format("Nivel %d/%d", lvl, #def.Prices)
		if lvl >= #def.Prices then
			row.button.Text = "MAX"
			row.button.BackgroundColor3 = Color3.fromRGB(90, 90, 90)
		else
			local price = def.Prices[lvl + 1]
			row.button.Text = `Comprar ({price})`
			row.button.BackgroundColor3 = if coins.Value >= price then Color3.fromRGB(60, 170, 90) else Color3.fromRGB(150, 60, 60)
		end
	end
end

coins.Changed:Connect(refresh)
for _, id in ids do
	player:GetAttributeChangedSignal("Up_" .. id):Connect(refresh)
end
refresh()

ProximityPromptService.PromptTriggered:Connect(function(prompt)
	if prompt.Name == "ShopPrompt" then
		refresh()
		gui.Enabled = not gui.Enabled
	end
end)
