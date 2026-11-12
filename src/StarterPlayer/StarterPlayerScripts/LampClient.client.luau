--!strict
-- Lámpara: tecla F (o botón táctil) alterna; la luz sigue la dirección de la CÁMARA, tanto en
-- primera como en tercera persona. Cada cliente dibuja las luces (propia y ajenas) localmente.
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local toggleLamp = remotes:WaitForChild("ToggleLamp") :: RemoteEvent
local aimLamp = remotes:WaitForChild("AimLamp") :: RemoteEvent
local localPlayer = Players.LocalPlayer
local camera = workspace.CurrentCamera :: Camera

ContextActionService:BindAction("ToggleLamp", function(_name, state)
	if state == Enum.UserInputState.Begin then
		toggleLamp:FireServer()
	end
	return Enum.ContextActionResult.Sink
end, true, Enum.KeyCode.F)
ContextActionService:SetTitle("ToggleLamp", "Luz")

type Beam3D = typeof(Instance.new("Beam"))
type Beam = { part: Part, light: SpotLight, fill: SpotLight, shaft: Beam3D, tip: Attachment, dir: Vector3 }
local beams: { [Player]: Beam } = {}

local function destroyBeam(player: Player)
	local b = beams[player]
	if b then
		b.part:Destroy()
		beams[player] = nil
	end
end

local function getBeam(player: Player): Beam
	local existing = beams[player]
	if existing then
		return existing
	end
	local part = Instance.new("Part")
	part.Name = "LampBeam"
	part.Size = Vector3.new(0.2, 0.2, 0.2)
	part.Transparency = 1
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Parent = camera -- contenedor local: no se replica
	local light = Instance.new("SpotLight")
	light.Face = Enum.NormalId.Front
	light.Angle = Config.LampAngle
	light.Brightness = Config.LampBrightness
	light.Shadows = false
	light.Parent = part
	-- Relleno: cono ancho y corto, tenue, para que el suelo cercano (p. ej. al mirar hacia abajo) no quede a oscuras.
	local fill = Instance.new("SpotLight")
	fill.Name = "Fill"
	fill.Face = Enum.NormalId.Front
	fill.Angle = Config.LampFillAngle
	fill.Range = Config.LampFillRange
	fill.Brightness = Config.LampFillBrightness
	fill.Shadows = false
	fill.Parent = part
	-- Cono visible: cinta que mira a la cámara, estrecha en la lámpara y ancha al final, casi transparente.
	local origin = Instance.new("Attachment")
	origin.Parent = part
	local tip = Instance.new("Attachment")
	tip.Parent = part
	local shaft = Instance.new("Beam")
	shaft.Attachment0 = origin
	shaft.Attachment1 = tip
	shaft.FaceCamera = true
	shaft.LightEmission = 1
	shaft.LightInfluence = 0
	shaft.Color = ColorSequence.new(Color3.fromRGB(200, 235, 255))
	shaft.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.7),
		NumberSequenceKeypoint.new(1, 1),
	})
	shaft.Parent = part
	local b: Beam = { part = part, light = light, fill = fill, shaft = shaft, tip = tip, dir = camera.CFrame.LookVector }
	beams[player] = b
	return b
end

local aimAccum = 0
local lastSent = Vector3.zero

RunService.RenderStepped:Connect(function(dt)
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local head = character and character:FindFirstChild("Head") :: BasePart?
		if player:GetAttribute("LampOn") and head then
			local b = getBeam(player)
			if player == localPlayer then
				b.dir = camera.CFrame.LookVector
			else
				local target = (player:GetAttribute("LampDir") :: Vector3?) or head.CFrame.LookVector
				b.dir = b.dir:Lerp(target, math.min(1, dt * 12)) -- suaviza los 10 Hz recibidos
			end
			if b.dir.Magnitude < 0.01 then
				b.dir = head.CFrame.LookVector
			end
			local dir = b.dir.Unit
			local pos = head.Position + dir * Config.LampOriginOffset
			b.part.CFrame = CFrame.lookAt(pos, pos + dir)
			local level = (player:GetAttribute("Up_Lamp") :: number?) or 0
			local range = Config.LampRange + level * Config.Upgrades.Lamp.RangeBonus
			b.light.Range = range
			local length = range * Config.LampShaftFraction
			b.tip.Position = Vector3.new(0, 0, -length)
			b.shaft.Width0 = 0.3
			b.shaft.Width1 = 2 * length * math.tan(math.rad(Config.LampAngle / 2))
		else
			destroyBeam(player)
		end
	end

	-- Enviar la dirección propia al servidor a ~10 Hz, solo si cambió.
	aimAccum += dt
	if aimAccum >= 0.1 and localPlayer:GetAttribute("LampOn") then
		aimAccum = 0
		local look = camera.CFrame.LookVector
		if (look - lastSent).Magnitude > 0.02 then
			lastSent = look
			aimLamp:FireServer(look)
		end
	end
end)

Players.PlayerRemoving:Connect(destroyBeam)
