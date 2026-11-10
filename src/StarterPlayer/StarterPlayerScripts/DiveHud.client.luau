--!strict
-- HUD de buceo: profundidad (calculada localmente) y barra de oxígeno (del servidor).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local updateHud = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("UpdateHUD") :: RemoteEvent
local player = Players.LocalPlayer

local gui = Instance.new("ScreenGui")
gui.Name = "DiveHud"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local frame = Instance.new("Frame")
frame.AnchorPoint = Vector2.new(0, 1)
frame.Position = UDim2.new(0, 16, 1, -16)
frame.Size = UDim2.fromOffset(240, 96)
frame.BackgroundColor3 = Color3.fromRGB(10, 30, 50)
frame.BackgroundTransparency = 0.25
frame.Parent = gui
Instance.new("UICorner").Parent = frame

local depthLabel = Instance.new("TextLabel")
depthLabel.BackgroundTransparency = 1
depthLabel.Size = UDim2.new(1, -16, 0, 28)
depthLabel.Position = UDim2.fromOffset(8, 4)
depthLabel.TextXAlignment = Enum.TextXAlignment.Left
depthLabel.Font = Enum.Font.GothamBold
depthLabel.TextSize = 20
depthLabel.TextColor3 = Color3.new(1, 1, 1)
depthLabel.Text = "Profundidad: 0 m"
depthLabel.Parent = frame

local barBg = Instance.new("Frame")
barBg.Position = UDim2.fromOffset(8, 40)
barBg.Size = UDim2.new(1, -16, 0, 20)
barBg.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
barBg.Parent = frame
Instance.new("UICorner").Parent = barBg

local bar = Instance.new("Frame")
bar.Size = UDim2.fromScale(1, 1)
bar.BackgroundColor3 = Color3.fromRGB(60, 190, 255)
bar.Parent = barBg
Instance.new("UICorner").Parent = bar

local o2Label = Instance.new("TextLabel")
o2Label.BackgroundTransparency = 1
o2Label.Size = UDim2.fromScale(1, 1)
o2Label.Font = Enum.Font.GothamMedium
o2Label.TextSize = 14
o2Label.TextColor3 = Color3.new(1, 1, 1)
o2Label.Text = "O₂"
o2Label.Parent = barBg

local invLabel = Instance.new("TextLabel")
invLabel.BackgroundTransparency = 1
invLabel.Position = UDim2.fromOffset(8, 66)
invLabel.Size = UDim2.new(1, -16, 0, 22)
invLabel.TextXAlignment = Enum.TextXAlignment.Left
invLabel.Font = Enum.Font.GothamMedium
invLabel.TextSize = 14
invLabel.TextColor3 = Color3.new(1, 1, 1)
invLabel.Parent = frame

local function refreshInventory()
	invLabel.Text = string.format(
		"Botín: %d/%d",
		player:GetAttribute("InventoryCount") or 0,
		player:GetAttribute("InventoryCapacity") or 0
	)
end
refreshInventory()
player:GetAttributeChangedSignal("InventoryCount"):Connect(refreshInventory)
player:GetAttributeChangedSignal("InventoryCapacity"):Connect(refreshInventory)

local notice = Instance.new("TextLabel")
notice.AnchorPoint = Vector2.new(0.5, 0)
notice.Position = UDim2.new(0.5, 0, 0, 24)
notice.Size = UDim2.fromOffset(320, 32)
notice.BackgroundColor3 = Color3.fromRGB(10, 30, 50)
notice.BackgroundTransparency = 0.25
notice.Font = Enum.Font.GothamBold
notice.TextSize = 18
notice.TextColor3 = Color3.new(1, 1, 1)
notice.Visible = false
notice.Parent = gui
Instance.new("UICorner").Parent = notice

local noticeId = 0
player:GetAttributeChangedSignal("HudNotice"):Connect(function()
	local raw = player:GetAttribute("HudNotice")
	if type(raw) ~= "string" then
		return
	end
	notice.Text = string.split(raw, "|")[1]
	notice.Visible = true
	noticeId += 1
	local mine = noticeId
	task.delay(2.5, function()
		if noticeId == mine then
			notice.Visible = false
		end
	end)
end)

updateHud.OnClientEvent:Connect(function(current: number, max: number)
	local ratio = math.clamp(current / max, 0, 1)
	bar.Size = UDim2.fromScale(ratio, 1)
	bar.BackgroundColor3 = if ratio < 0.2 then Color3.fromRGB(255, 70, 70) else Color3.fromRGB(60, 190, 255)
	o2Label.Text = string.format("O₂ %d:%02d", current // 60, current % 60)
end)

RunService.RenderStepped:Connect(function()
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root then
		local depth = math.max(0, Config.SeaLevelY - root.Position.Y)
		depthLabel.Text = string.format("Profundidad: %d m", depth)
	end
end)
