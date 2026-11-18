--!strict
-- Sprint (sustituye al dash): mantener Shift (L3 en mando, botón "Correr" en táctil) para nadar más rápido. La estamina es del
-- servidor (StaminaService): aquí solo se avisa de si se mantiene la tecla y se dibuja la barra de estamina (arriba del HUD de
-- buceo). SwimClient aplica la velocidad al leer el atributo Sprinting. Parámetros: Config.Sprint.
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local P = Config.Sprint
local setSprint = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("SetSprint") :: RemoteEvent

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera :: Camera
local held = false

local function setHeld(value: boolean)
	if held ~= value then
		held = value
		setSprint:FireServer(value)
	end
end

ContextActionService:BindAction("Sprint", function(_name, state)
	if state == Enum.UserInputState.Begin then
		setHeld(true)
	elseif state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
		setHeld(false)
	end
	return Enum.ContextActionResult.Pass
end, true, P.Key, P.PadKey)
ContextActionService:SetTitle("Sprint", "Correr")

-- ===== Barra de estamina =====
local gui = Instance.new("ScreenGui")
gui.Name = "StaminaHud"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local holder = Instance.new("Frame")
-- Justo encima del panel de vida/oxígeno de la interfaz de Codex (Abismo_HUD_Buceo: x 2,3 %, borde superior ~86 % de la pantalla),
-- con su mismo ancho (14 %). En móvil ese panel va arriba, así que aquí queda libre.
holder.AnchorPoint = Vector2.new(0, 1)
holder.Position = UDim2.new(0.0229, 0, 0.85, 0)
holder.Size = UDim2.new(0.1406, 0, 0, 18)
holder.BackgroundColor3 = Color3.fromRGB(10, 30, 50)
holder.BackgroundTransparency = 0.25
holder.Visible = false
holder.Parent = gui
Instance.new("UICorner").Parent = holder

local barBg = Instance.new("Frame")
barBg.Position = UDim2.fromOffset(4, 4)
barBg.Size = UDim2.new(1, -8, 1, -8)
barBg.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
barBg.Parent = holder
Instance.new("UICorner").Parent = barBg

local bar = Instance.new("Frame")
bar.Size = UDim2.fromScale(1, 1)
bar.BackgroundColor3 = Color3.fromRGB(120, 230, 120)
bar.Parent = barBg
Instance.new("UICorner").Parent = bar

local label = Instance.new("TextLabel")
label.BackgroundTransparency = 1
label.Size = UDim2.fromScale(1, 1)
label.Font = Enum.Font.GothamMedium
label.TextSize = 11
label.TextColor3 = Color3.new(1, 1, 1)
label.Text = "ESTAMINA  [Shift]"
label.Parent = barBg

local shown = P.StaminaMax
local baseFov = camera.FieldOfView
local fovKick = 0

RunService.RenderStepped:Connect(function(dt)
	local inRun = player:GetAttribute("InRun") == true
	local stamina = player:GetAttribute("Stamina")
	local max = player:GetAttribute("StaminaMax")
	local sprinting = player:GetAttribute("Sprinting") == true
	local exhausted = player:GetAttribute("Exhausted") == true
	local full = type(stamina) == "number" and type(max) == "number" and stamina >= max - 0.5
	-- solo se ve en partida y cuando no está llena (o se está usando)
	holder.Visible = inRun and type(stamina) == "number" and (not full or sprinting or held)
	if type(stamina) == "number" and type(max) == "number" then
		shown += (stamina - shown) * math.min(1, dt * 14)
		bar.Size = UDim2.fromScale(math.clamp(shown / max, 0, 1), 1)
		if exhausted then
			-- parpadea en rojo hasta recuperar
			local on = math.floor(os.clock() * 6) % 2 == 0
			bar.BackgroundColor3 = if on then Color3.fromRGB(255, 70, 70) else Color3.fromRGB(150, 40, 40)
			label.Text = "AGOTADO"
		else
			local ratio = shown / max
			bar.BackgroundColor3 = if ratio < 0.3 then Color3.fromRGB(255, 190, 70) else Color3.fromRGB(120, 230, 120)
			label.Text = "ESTAMINA  [Shift]"
		end
	end
	-- patada de campo de visión al correr (sensación de velocidad)
	if P.FovKick > 0 then
		local target = if sprinting then P.FovKick else 0
		fovKick += (target - fovKick) * math.min(1, dt * 6)
		if math.abs(fovKick) > 0.02 or sprinting then
			camera.FieldOfView = baseFov + fovKick
		elseif camera.FieldOfView ~= baseFov and math.abs(fovKick) <= 0.02 then
			camera.FieldOfView = baseFov
		end
	end
end)

-- si se pierde el foco o se muere con la tecla pulsada, suelta el sprint
player.CharacterRemoving:Connect(function()
	setHeld(false)
end)
