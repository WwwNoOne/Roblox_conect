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

ContextActionService:BindAction("ToggleLamp", function(_name, state)
	if state == Enum.UserInputState.Begin then
		toggleLamp:FireServer()
	end
	return Enum.ContextActionResult.Sink
end, true, Enum.KeyCode.F)
ContextActionService:SetTitle("ToggleLamp", "Luz")

local LampRig = require(script.Parent:WaitForChild("LampRig"))

local LampHotspot = require(script.Parent:WaitForChild("LampHotspot"))
local hotspot: LampHotspot.Hotspot? = nil

local function getHotspot(character: Model): LampHotspot.Hotspot
	local h = hotspot
	if not h or not h.part.Parent then
		if h then
			h:Destroy()
		end
		local folder = workspace:FindFirstChild("LampRigs") :: Instance
		h = LampHotspot.new(folder)
		hotspot = h
	end
	local hs = h :: LampHotspot.Hotspot
	local ignore: { Instance } = { character }
	for _, name in { "LampRigs", "AmbientFaunaLive" } do
		local f = workspace:FindFirstChild(name)
		if f then
			table.insert(ignore, f)
		end
	end
	hs:SetIgnore(ignore)
	return hs
end

local rigs: { [Player]: LampRig.Rig } = {}

local function dropRig(player: Player)
	local r = rigs[player]
	if r then
		r:Destroy()
		rigs[player] = nil
	end
end

local function getRig(player: Player, initialDir: Vector3): LampRig.Rig
	local r = rigs[player]
	if not r then
		r = LampRig.new(initialDir)
		rigs[player] = r
	end
	r:Validate()
	return r
end

-- Posición de origen: LampOrigin (si el modelo lo trae) o la cabeza.
local function originOf(character: Model): BasePart?
	local o = character:FindFirstChild("LampOrigin", true)
	if o and o:IsA("BasePart") then
		return o
	end
	local head = character:FindFirstChild("Head")
	return if head and head:IsA("BasePart") then head else nil
end

local aimAccum = 0
local lastSent = Vector3.zero

-- Después de que la cámara se actualice: si no, la luz usa la dirección del cuadro anterior y "tiembla" al mover la vista.
RunService:BindToRenderStep("Lamp", Enum.RenderPriority.Camera.Value + 1, function(dt)
	local camera = workspace.CurrentCamera -- se resuelve cada cuadro: Roblox puede recrearla
	if not camera then
		return
	end
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local origin = character and originOf(character)
		if player:GetAttribute("LampOn") and origin and character then
			local r = getRig(player, camera.CFrame.LookVector)
			if player == localPlayer then
				r.dir = camera.CFrame.LookVector
			else
				local target = (player:GetAttribute("LampDir") :: Vector3?) or origin.CFrame.LookVector
				r.dir = r.dir:Lerp(target, math.min(1, dt * 12)) -- suaviza los 10 Hz recibidos
			end
			if r.dir.Magnitude < 0.01 then
				r.dir = origin.CFrame.LookVector
			end
			local dir = r.dir.Unit
			local level = (player:GetAttribute("Up_Lamp") :: number?) or 0
			r:Update(origin.Position + dir * Config.LampOriginOffset, dir, Config.LampRange)
			r:SetUpgrade(level)
			r:SetEnabled(true)
			if player == localPlayer then
				local range = Config.LampRange
				local hs = getHotspot(character)
				hs:SetUpgrade(level)
				hs:Update(origin.Position + dir * Config.LampOriginOffset, dir, math.min(range, 120), dt, r.part:FindFirstChild("Origin") :: Attachment?)
			end
		else
			local r = rigs[player]
			if r then
				r:SetEnabled(false)
			end
			if player == localPlayer and hotspot then
				hotspot:Hide()
			end
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

-- Al reaparecer, el rig propio vuelve a nacer apagado y mirando a la cámara (sin arrastrar la dirección vieja).
localPlayer.CharacterAdded:Connect(function()
	dropRig(localPlayer)
	lastSent = Vector3.zero
end)
Players.PlayerRemoving:Connect(dropRig)
