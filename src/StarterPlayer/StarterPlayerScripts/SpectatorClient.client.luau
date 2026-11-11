--!strict
-- Espectador (T06): el jugador muerto en partida observa a un compañero vivo. Q/E o botones para cambiar.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer

local gui = Instance.new("ScreenGui")
gui.Name = "Spectator"
gui.ResetOnSpawn = false
gui.Enabled = false
gui.Parent = player:WaitForChild("PlayerGui")

local label = Instance.new("TextLabel")
label.AnchorPoint = Vector2.new(0.5, 1)
label.Position = UDim2.new(0.5, 0, 1, -24)
label.Size = UDim2.fromOffset(320, 36)
label.BackgroundColor3 = Color3.fromRGB(10, 30, 50)
label.BackgroundTransparency = 0.25
label.Font = Enum.Font.GothamBold
label.TextSize = 16
label.TextColor3 = Color3.new(1, 1, 1)
label.Parent = gui
Instance.new("UICorner").Parent = label

local function makeButton(text: string, x: number, onClick: () -> ()): TextButton
	local b = Instance.new("TextButton")
	b.AnchorPoint = Vector2.new(0.5, 1)
	b.Position = UDim2.new(0.5, x, 1, -24)
	b.Size = UDim2.fromOffset(40, 36)
	b.BackgroundColor3 = Color3.fromRGB(30, 90, 130)
	b.Font = Enum.Font.GothamBold
	b.TextSize = 18
	b.TextColor3 = Color3.new(1, 1, 1)
	b.Text = text
	b.Parent = gui
	Instance.new("UICorner").Parent = b
	b.Activated:Connect(onClick)
	return b
end

local index = 1

local function candidates(): { Player }
	local list: { Player } = {}
	for _, p in Players:GetPlayers() do
		local humanoid = p.Character and p.Character:FindFirstChildOfClass("Humanoid")
		if p ~= player and p:GetAttribute("InRun") and p:GetAttribute("RunAlive") and humanoid and humanoid.Health > 0 then
			table.insert(list, p)
		end
	end
	return list
end

local function cycle(step: number)
	index += step
end

makeButton("<", -200, function()
	cycle(-1)
end)
makeButton(">", 200, function()
	cycle(1)
end)
UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	if input.KeyCode == Enum.KeyCode.Q then
		cycle(-1)
	elseif input.KeyCode == Enum.KeyCode.E then
		cycle(1)
	end
end)

local spectating = false

RunService.RenderStepped:Connect(function()
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local dead = player:GetAttribute("InRun") == true and player:GetAttribute("RunAlive") == false
	if dead then
		local list = candidates()
		gui.Enabled = true
		if #list == 0 then
			label.Text = "Espectador: sin compañeros vivos"
			return
		end
		index = ((index - 1) % #list) + 1
		local target = list[index]
		local humanoid = target.Character and target.Character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			camera.CameraSubject = humanoid
			label.Text = "Espectador: " .. target.DisplayName .. "  (Q / E)"
			spectating = true
		end
	elseif spectating then
		spectating = false
		gui.Enabled = false
		local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			camera.CameraSubject = humanoid
		end
	else
		gui.Enabled = false
	end
end)
