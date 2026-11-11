--!strict
-- HUD de buceo: profundidad (calculada localmente) y barra de oxígeno (del servidor).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Types = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Types"))
local updateHud = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("UpdateHUD") :: RemoteEvent
local player = Players.LocalPlayer

local gui = Instance.new("ScreenGui")
gui.Name = "DiveHud"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local frame = Instance.new("Frame")
frame.AnchorPoint = Vector2.new(0, 1)
frame.Position = UDim2.new(0, 16, 1, -16)
frame.Size = UDim2.fromOffset(300, 120)
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

local function refreshInfo(hull: number?, hullMax: number?, money: number?)
	local hullText = if hull and hullMax then string.format("Casco: %d/%d", hull, hullMax) else "Casco: --"
	local moneyText = if money then string.format("  $%d", money) else ""
	invLabel.Text = string.format(
		"%s%s  Slots %d/%d  [F] %s",
		hullText,
		moneyText,
		player:GetAttribute("CarryCount") or 0,
		player:GetAttribute("CarryCapacity") or 0,
		if player:GetAttribute("LampOn") then "ON" else "OFF"
	)
end
refreshInfo(nil, nil, nil)
local lastHull: number?, lastHullMax: number?, lastMoney: number? = nil, nil, nil
local runDepth: number? = nil -- profundidad del submarino (servidor) durante una partida
for _, attr in { "LampOn", "CarryCount", "CarryCapacity" } do
	player:GetAttributeChangedSignal(attr):Connect(function()
		refreshInfo(lastHull, lastHullMax, lastMoney)
	end)
end

local quotaLabel = Instance.new("TextLabel")
quotaLabel.BackgroundTransparency = 1
quotaLabel.Position = UDim2.fromOffset(8, 90)
quotaLabel.Size = UDim2.new(1, -16, 0, 22)
quotaLabel.TextXAlignment = Enum.TextXAlignment.Left
quotaLabel.Font = Enum.Font.GothamMedium
quotaLabel.TextSize = 14
quotaLabel.TextColor3 = Color3.fromRGB(255, 220, 120)
quotaLabel.Text = ""
quotaLabel.Parent = frame

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

updateHud.OnClientEvent:Connect(function(payload: Types.HudPayload)
	lastHull, lastHullMax, lastMoney = payload.hull, payload.hullMax, payload.money
	runDepth = payload.depth
	if payload.quota then
		quotaLabel.Text = string.format("Cuota %d/%d   Fallos %d/%d", payload.deposited or 0, payload.quota, payload.failures or 0, Config.Economy.Quota.MaxFailures)
	else
		quotaLabel.Text = ""
	end
	refreshInfo(lastHull, lastHullMax, lastMoney)
	local current, max = payload.oxygen, payload.oxygenMax
	local ratio = math.clamp(current / max, 0, 1)
	bar.Size = UDim2.fromScale(ratio, 1)
	bar.BackgroundColor3 = if ratio < 0.2 then Color3.fromRGB(255, 70, 70) else Color3.fromRGB(60, 190, 255)
	o2Label.Text = string.format("O₂ %d:%02d", current // 60, current % 60)
end)

RunService.RenderStepped:Connect(function()
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root then
		local depth = runDepth or math.max(0, Config.SeaLevelY - root.Position.Y)
		depthLabel.Text = string.format("Profundidad: %d m", depth)
	end
end)
