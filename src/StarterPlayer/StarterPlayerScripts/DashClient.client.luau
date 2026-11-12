--!strict
-- Dash: impulso hacia donde mira la cámara, solo nadando. Tecla Q (botón táctil "Dash"), enfriamiento de 15 s.
-- Mientras dura, SwimClient se aparta (atributo local Dashing) para no frenarlo. Parámetros: Config.Dash.
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Sfx = require(Shared:WaitForChild("Sfx"))
local D = Config.Dash

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera :: Camera
local readyAt = 0
local dashing = false

-- Indicador discreto abajo a la derecha.
local gui = Instance.new("ScreenGui")
gui.Name = "DashHud"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")
local label = Instance.new("TextLabel")
label.AnchorPoint = Vector2.new(1, 1)
label.Position = UDim2.new(1, -16, 1, -16)
label.Size = UDim2.fromOffset(150, 28)
label.BackgroundColor3 = Color3.fromRGB(10, 20, 35)
label.BackgroundTransparency = 0.3
label.TextColor3 = Color3.fromRGB(120, 220, 255)
label.Font = Enum.Font.GothamMedium
label.TextSize = 14
label.Visible = false
label.Parent = gui
Instance.new("UICorner", label).CornerRadius = UDim.new(0, 6)

local function tryDash()
	if dashing or os.clock() < readyAt then
		return
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not humanoid or not root or humanoid.Health <= 0 then
		return
	end
	if humanoid:GetState() ~= Enum.HumanoidStateType.Swimming then
		return -- fuera del agua no hay dash
	end
	local direction = camera.CFrame.LookVector
	readyAt = os.clock() + D.Cooldown
	dashing = true
	player:SetAttribute("Dashing", true)
	Sfx.Play(Config.Sfx.Dash)

	local started = os.clock()
	local connection: RBXScriptConnection
	connection = RunService.Heartbeat:Connect(function()
		local a = (os.clock() - started) / D.Duration
		if a >= 1 or not root.Parent or humanoid.Health <= 0 then
			connection:Disconnect()
			dashing = false
			player:SetAttribute("Dashing", false)
			return
		end
		root.AssemblyLinearVelocity = direction * (D.Speed * (1 - a))
	end)
end

ContextActionService:BindAction("Dash", function(_name, state)
	if state == Enum.UserInputState.Begin then
		tryDash()
	end
	return Enum.ContextActionResult.Pass
end, true, D.Key)
ContextActionService:SetTitle("Dash", "Dash")

RunService.Heartbeat:Connect(function()
	label.Visible = player:GetAttribute("InRun") == true
	if label.Visible then
		local left = readyAt - os.clock()
		label.Text = if left > 0 then ("Dash  %ds"):format(math.ceil(left)) else "Dash [Q] listo"
	end
end)
