--!strict
-- Panel de tienda/reparación del submarino (provisional; la UI final es de Codex).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Types = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Types"))
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local shopOpen = remotes:WaitForChild("ShopOpen") :: RemoteEvent
local requestPurchase = remotes:WaitForChild("RequestPurchase") :: RemoteFunction
local player = Players.LocalPlayer

local gui = Instance.new("ScreenGui")
gui.Name = "Shop"
gui.ResetOnSpawn = false
gui.Enabled = false
gui.Parent = player:WaitForChild("PlayerGui")

local frame = Instance.new("Frame")
frame.AnchorPoint = Vector2.new(0.5, 0.5)
frame.Position = UDim2.fromScale(0.5, 0.5)
frame.Size = UDim2.fromOffset(340, 300)
frame.BackgroundColor3 = Color3.fromRGB(10, 30, 50)
frame.BackgroundTransparency = 0.1
frame.Parent = gui
Instance.new("UICorner").Parent = frame
local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 6)
layout.Parent = frame
local pad = Instance.new("UIPadding")
pad.PaddingTop, pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 10), UDim.new(0, 10), UDim.new(0, 10)
pad.Parent = frame

local function label(text: string): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size = UDim2.new(1, 0, 0, 24)
	l.Font = Enum.Font.GothamMedium
	l.TextSize = 16
	l.TextColor3 = Color3.new(1, 1, 1)
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.Text = text
	l.Parent = frame
	return l
end

local function button(text: string, onClick: () -> ()): TextButton
	local b = Instance.new("TextButton")
	b.Size = UDim2.new(1, 0, 0, 32)
	b.BackgroundColor3 = Color3.fromRGB(30, 90, 130)
	b.Font = Enum.Font.GothamBold
	b.TextSize = 15
	b.TextColor3 = Color3.new(1, 1, 1)
	b.Text = text
	b.Parent = frame
	Instance.new("UICorner").Parent = b
	b.Activated:Connect(onClick)
	return b
end

local function render(state: Types.ShopState)
	for _, c in frame:GetChildren() do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
	label(string.format("Fondo común: $%d   Casco: %d/%d", state.money, state.hull, state.hullMax))
	button(string.format("Reparar +10 HP  ($%d)", state.repairCost), function()
		local r = requestPurchase:InvokeServer("Repair")
		if r and r.state then
			render(r.state)
		end
	end)
	for _, item in state.items do
		local text = if item.price
			then string.format("%s  Nv %d/%d  ($%d)", item.name, item.level, item.maxLevel, item.price)
			else string.format("%s  Nv %d/%d  (MAX)", item.name, item.level, item.maxLevel)
		button(text, function()
			local r = requestPurchase:InvokeServer(item.id)
			if r and r.state then
				render(r.state)
			end
		end)
	end
	button("Cerrar", function()
		gui.Enabled = false
	end)
end

shopOpen.OnClientEvent:Connect(function(state: Types.ShopState)
	render(state)
	gui.Enabled = true
end)
