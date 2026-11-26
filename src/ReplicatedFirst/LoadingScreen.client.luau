--!strict
-- Pantalla de carga: negra, con un engranaje girando, hasta que el personaje, los sonidos y las mallas estén listos.
-- Sin esto el audio y los efectos tardan en entrar tras aparecer el juego. Parámetros: Config.Loading.
local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

ReplicatedFirst:RemoveDefaultLoadingScreen()

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local started = os.clock()

-- UI mínima y sin dependencias (aún no ha cargado nada más).
local gui = Instance.new("ScreenGui")
gui.Name = "LoadingScreen"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.DisplayOrder = 1000
gui.Parent = playerGui

local bg = Instance.new("Frame")
bg.Size = UDim2.fromScale(1, 1)
bg.BackgroundColor3 = Color3.new(0, 0, 0)
bg.BorderSizePixel = 0
bg.Active = true -- bloquea clics hacia abajo
bg.Parent = gui

local gear = Instance.new("TextLabel")
gear.AnchorPoint = Vector2.new(0.5, 0.5)
gear.Position = UDim2.fromScale(0.5, 0.47)
gear.Size = UDim2.fromOffset(96, 96)
gear.BackgroundTransparency = 1
gear.Text = "⚙"
gear.TextScaled = true
gear.TextColor3 = Color3.fromRGB(120, 180, 230)
gear.Font = Enum.Font.GothamBold
gear.Parent = bg

local label = Instance.new("TextLabel")
label.AnchorPoint = Vector2.new(0.5, 0)
label.Position = UDim2.new(0.5, 0, 0.47, 64)
label.Size = UDim2.fromOffset(300, 30)
label.AutomaticSize = Enum.AutomaticSize.None
label.BackgroundTransparency = 1
label.Text = "Cargando..."
label.TextSize = 20
label.TextColor3 = Color3.fromRGB(150, 175, 200)
label.Font = Enum.Font.Gotham
label.Parent = bg

local spin = RunService.RenderStepped:Connect(function(dt)
	gear.Rotation = (gear.Rotation + dt * 140) % 360
end)

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local L = Config.Loading
label.Text = L.Text

-- Espera a que cargue lo esencial y precarga sonidos y recursos para que no tarden al primer uso.
local function waitReady()
	if not game:IsLoaded() then
		game.Loaded:Wait()
	end
	ReplicatedStorage:WaitForChild("Remotes")
	local character = player.Character or player.CharacterAdded:Wait()
	character:WaitForChild("HumanoidRootPart")

	-- El servidor prepara el mundo al arrancar (LevelService) y avisa con el atributo Workspace.WorldReady.
	if workspace:GetAttribute("WorldReady") ~= true then
		label.Text = L.WorldText
		while workspace:GetAttribute("WorldReady") ~= true do
			workspace:GetAttributeChangedSignal("WorldReady"):Wait()
		end
		label.Text = L.Text
	end

	local assets: { Instance } = {}
	local function collect(root: Instance?)
		if not root then
			return
		end
		for _, d in root:GetDescendants() do
			if d:IsA("Sound") or d:IsA("MeshPart") or d:IsA("Animation") or d:IsA("ImageLabel") or d:IsA("Decal") then
				table.insert(assets, d)
			end
		end
	end
	local sonidos = workspace:WaitForChild("sonidos", 5)
	collect(sonidos)
	for _, c in workspace:GetChildren() do
		if c:IsA("Sound") then
			table.insert(assets, c)
		end
	end
	collect(SoundService)
	collect(ReplicatedStorage)
	local hotspot = Instance.new("ImageLabel")
	hotspot.Image = Config.LampHotspotImage
	table.insert(assets, hotspot)
	ContentProvider:PreloadAsync(assets, function(id: string, status: Enum.AssetFetchStatus)
		if status ~= Enum.AssetFetchStatus.Success then
			warn(string.format("[Carga] No se pudo cargar %s (%s)", id, status.Name)) -- así se ve en Output qué audio/malla falla
		end
	end)
end

local done = false
task.spawn(function()
	waitReady()
	done = true
end)

local deadline = started + L.MaxSeconds
while (not done or os.clock() - started < L.MinSeconds) and os.clock() < deadline do
	task.wait(0.1)
end

spin:Disconnect()
local info = TweenInfo.new(L.FadeSeconds)
TweenService:Create(bg, info, { BackgroundTransparency = 1 }):Play()
TweenService:Create(gear, info, { TextTransparency = 1 }):Play()
TweenService:Create(label, info, { TextTransparency = 1 }):Play()
task.delay(L.FadeSeconds, function()
	gui:Destroy()
end)
