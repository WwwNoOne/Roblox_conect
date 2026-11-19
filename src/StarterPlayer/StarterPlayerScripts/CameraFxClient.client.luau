--!strict
-- Impacto y temblor de cámara para dar suspenso (Config.CameraFx).
--   * Impacto: cuando un enemigo te golpea (remoto PlayerHit) la cámara se sacude con fuerza un instante, hay un destello rojo y suena
--     Config.Sfx.Impact si existe un sonido con ese nombre.
--   * Tensión: temblor leve y continuo que sube cuanto más cerca está un enemigo que te persigue (o rastrea / merodea muy cerca), y un
--     pulso cuando empieza su zarpazo (Windup), tu aviso para esquivar.
-- Solo gira la cámara unos grados (no mueve su posición ni toca el FOV) después de que el script de cámara de Roblox la coloque.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Sfx = require(Shared:WaitForChild("Sfx"))
local C = Config.CameraFx
local playerHit = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("PlayerHit") :: RemoteEvent

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera :: Camera

-- ===== Destello rojo =====
local gui = Instance.new("ScreenGui")
gui.Name = "ImpactFx"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 50
gui.Parent = player:WaitForChild("PlayerGui")
local flash = Instance.new("Frame")
flash.Size = UDim2.fromScale(1, 1)
flash.BackgroundColor3 = C.FlashColor
flash.BackgroundTransparency = 1
flash.BorderSizePixel = 0
flash.Active = false
flash.Parent = gui

-- ===== Sacudidas puntuales =====
type Shake = { t0: number, duration: number, angle: number, frequency: number, seed: number }
local shakes: { Shake } = {}
local seedCounter = 0

local function addShake(angle: number, duration: number, frequency: number)
	seedCounter += 1
	table.insert(shakes, { t0 = os.clock(), duration = duration, angle = angle, frequency = frequency, seed = seedCounter * 17.3 })
end

playerHit.OnClientEvent:Connect(function(damage: unknown)
	local amount = if type(damage) == "number" then damage else C.ImpactRefDamage
	local scale = math.clamp(amount / C.ImpactRefDamage, 0.6, 1.5)
	addShake(C.ImpactAngle * scale, C.ImpactSeconds, C.ImpactFrequency)
	flash.BackgroundTransparency = C.FlashTransparency
	TweenService:Create(flash, TweenInfo.new(C.FlashSeconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { BackgroundTransparency = 1 }):Play()
	Sfx.Play(Config.Sfx.Impact)
end)

-- ===== Tensión por enemigos cercanos =====
local lastState: { [Instance]: string } = {}
local tension = 0 -- 0..1 suavizado

local function threatNow(): number
	local best = 0
	for _, model in CollectionService:GetTagged("ProcCreature") do
		if model:IsA("Model") and model:IsDescendantOf(workspace) then
			local state = model:GetAttribute("Estado")
			if type(state) == "string" and state ~= "Hidden" then
				local distance = (model:GetPivot().Position - camera.CFrame.Position).Magnitude
				-- pulso al empezar su zarpazo
				if state == "Windup" and lastState[model] ~= "Windup" and distance < C.TensionRange then
					addShake(C.WindupPulseAngle, C.WindupPulseSeconds, 30)
				end
				lastState[model] = state
				local weight = 0
				local range = C.TensionRange
				if state == "Chase" or state == "Windup" or state == "Lunge" or state == "Recover" then
					weight = 1
				elseif state == "Search" or state == "Investigate" then
					weight = C.SearchWeight
				elseif state == "Patrol" then
					weight, range = C.PatrolWeight, C.PatrolRange
				end
				if weight > 0 and distance < range then
					local proximity = 1 - distance / range
					best = math.max(best, weight * proximity * proximity)
				end
			end
		end
	end
	return best
end

-- ===== Aplicar sobre la cámara =====
RunService:BindToRenderStep("CameraFx", Enum.RenderPriority.Camera.Value + 1, function(dt)
	local now = os.clock()
	local rx, ry, rz = 0, 0, 0

	for i = #shakes, 1, -1 do
		local s = shakes[i]
		local a = (now - s.t0) / s.duration
		if a >= 1 then
			table.remove(shakes, i)
		else
			local envelope = (1 - a) * (1 - a)
			local t = (now - s.t0) * s.frequency
			rx += math.noise(t, s.seed, 0) * 2 * s.angle * envelope
			ry += math.noise(s.seed, t, 1) * 2 * s.angle * envelope
			rz += math.noise(0, s.seed, t) * 2 * s.angle * envelope * 0.6
		end
	end

	local inRun = player:GetAttribute("InRun") == true
	local target = if inRun then threatNow() else 0
	tension += (target - tension) * math.min(1, dt * C.TensionSmoothing)
	if tension > 0.002 then
		local t = now * C.TensionFrequency
		local angle = C.TensionAngle * tension
		rx += math.noise(t, 11.1, 0) * 2 * angle
		ry += math.noise(22.2, t, 0) * 2 * angle
		rz += math.noise(0, 33.3, t) * 2 * angle * 0.5
	end

	if rx ~= 0 or ry ~= 0 or rz ~= 0 then
		camera.CFrame = camera.CFrame * CFrame.Angles(rx, ry, rz)
	end
end)
