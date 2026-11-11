--!strict
-- Peces, tesoros, arpón y estación de venta (modelos provisionales hasta tener los de Codex).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Inventory = require(script.Parent:WaitForChild("Inventory"))
local Upgrades = require(script.Parent:WaitForChild("Upgrades"))
local fireHarpoon = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("FireHarpoon") :: RemoteEvent
local creatureHit = ServerScriptService:WaitForChild("CreatureHit") :: BindableEvent
local markers = workspace:WaitForChild("Markers")
local creaturesFolder = workspace:WaitForChild("Creatures")

local FISH_COUNT = 5
local FISH_SPEED = 6 -- studs/s
local PULL_SPEED = 45 -- studs/s al jalar un pez con el cable
local PULL_TIMEOUT = 3
local READY_COLOR = Color3.fromRGB(80, 255, 120)
local COOLDOWN_COLOR = Color3.fromRGB(255, 60, 60)

local function markerPos(name: string): Vector3
	return (markers:WaitForChild(name) :: BasePart).Position
end

local function notify(player: Player, msg: string)
	player:SetAttribute("HudNotice", msg .. "|" .. tostring(os.clock()))
end

local function randomOffset(): Vector3
	return Vector3.new(math.random(-15, 15), math.random(-8, 8), math.random(-15, 15))
end

-- Peces ---------------------------------------------------------------------
local fishFolder = Instance.new("Folder")
fishFolder.Name = "Fish"
fishFolder.Parent = workspace
local fishCenter = markerPos("Marker_Fish_01")

local fishTween: { [Instance]: Tween } = {}

local function spawnFish()
	local fish = Instance.new("Part")
	fish.Name = "Fish"
	fish.Size = Vector3.new(1, 1.2, 3)
	fish.Color = Color3.fromRGB(255, 140, 40)
	fish.Material = Enum.Material.SmoothPlastic
	fish.Anchored = true
	fish.CanCollide = false
	fish.Position = fishCenter + randomOffset()
	fish.Parent = fishFolder

	task.spawn(function()
		while fish.Parent and not fish:GetAttribute("Hooked") do
			local target = fishCenter + randomOffset()
			local delta = target - fish.Position
			if delta.Magnitude > 1 then
				local duration = delta.Magnitude / FISH_SPEED
				local tween = TweenService:Create(fish, TweenInfo.new(duration, Enum.EasingStyle.Linear), {
					CFrame = CFrame.lookAt(target, target + delta),
				})
				fishTween[fish] = tween
				tween:Play()
				task.wait(duration)
			else
				task.wait(0.5)
			end
		end
		fishTween[fish] = nil
	end)
end

-- Tesoro --------------------------------------------------------------------
local function spawnTreasure()
	local chest = Instance.new("Part")
	chest.Name = "Treasure"
	chest.Size = Vector3.new(2.5, 1.5, 1.8)
	chest.Color = Color3.fromRGB(235, 190, 40)
	chest.Material = Enum.Material.Metal
	chest.Anchored = true
	chest.Position = markerPos("Marker_Treasure_01")
	chest.Parent = workspace

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Recoger"
	prompt.ObjectText = "Tesoro"
	prompt.HoldDuration = 0.5
	prompt.MaxActivationDistance = 10
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.Parent = chest

	prompt.Triggered:Connect(function(player: Player)
		if Inventory.Add(player, "Treasure") then
			chest:Destroy()
			task.delay(Config.TreasureRespawn, spawnTreasure)
		else
			notify(player, "Inventario lleno")
		end
	end)
end

-- Estación de venta en el puerto ---------------------------------------------
local station = Instance.new("Part")
station.Name = "SellStation"
station.Size = Vector3.new(3, 4, 3)
station.Color = Color3.fromRGB(40, 110, 200)
station.Anchored = true
station.Position = Vector3.new(-68, 6, 0)
station.Parent = workspace

local sellPrompt = Instance.new("ProximityPrompt")
sellPrompt.ActionText = "Vender botín"
sellPrompt.ObjectText = "Puerto"
sellPrompt.HoldDuration = 0
sellPrompt.MaxActivationDistance = 14
sellPrompt.KeyboardKeyCode = Enum.KeyCode.E
sellPrompt.Parent = station

sellPrompt.Triggered:Connect(function(player: Player)
	local gained = Inventory.SellAll(player)
	notify(player, if gained > 0 then `Vendido: +{gained} monedas` else "No tienes nada que vender")
end)

-- Arpón ----------------------------------------------------------------------
-- Cable visual: un Beam entre la punta del arpón y el objetivo (se replica solo, sin código de cliente).
local function makeCable(startAtt: Attachment, endAtt: Attachment, parent: Instance)
	local beam = Instance.new("Beam")
	beam.Attachment0 = startAtt
	beam.Attachment1 = endAtt
	beam.Width0 = 0.12
	beam.Width1 = 0.12
	beam.Color = ColorSequence.new(Color3.fromRGB(200, 200, 210))
	beam.FaceCamera = true
	beam.Segments = 1
	beam.Parent = parent
end

-- Cable que aparece un instante hasta un punto (fallo, criatura o pez que no entra).
local function tempShot(startAtt: Attachment, endPos: Vector3)
	local anchor = Instance.new("Part")
	anchor.Name = "HarpoonShot"
	anchor.Size = Vector3.new(0.2, 0.2, 0.2)
	anchor.Transparency = 1
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.Position = endPos
	anchor.Parent = workspace
	local att = Instance.new("Attachment")
	att.Parent = anchor
	makeCable(startAtt, att, anchor)
	Debris:AddItem(anchor, 0.25)
end

-- Jala el pez hacia el jugador por el cable y lo retira al llegar.
local function pullFish(player: Player, fish: BasePart, startAtt: Attachment)
	fish:SetAttribute("Hooked", true)
	local swim = fishTween[fish]
	if swim then
		swim:Cancel()
	end
	local att = Instance.new("Attachment")
	att.Parent = fish
	makeCable(startAtt, att, fish)

	local elapsed = 0
	local conn: RBXScriptConnection? = nil
	conn = RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not fish.Parent or not root or elapsed > PULL_TIMEOUT or (root.Position - fish.Position).Magnitude < 3 then
			if conn then
				conn:Disconnect()
			end
			fish:Destroy()
			return
		end
		local delta = root.Position - fish.Position
		local newPos = fish.Position + delta.Unit * math.min(delta.Magnitude, PULL_SPEED * dt)
		fish.CFrame = CFrame.lookAt(newPos, root.Position)
	end)
end

-- Indicador de "listo" sin interfaz: la punta brilla verde lista / roja en recarga, con un "ping".
local function setTipReady(tool: Tool, ready: boolean)
	local tip = tool:FindFirstChild("Tip") :: BasePart?
	if tip then
		tip.Color = if ready then READY_COLOR else COOLDOWN_COLOR
	end
end

local function giveHarpoon(player: Player)
	task.wait(0.3) -- el Backpack se recrea al reaparecer
	local backpack = player:FindFirstChildOfClass("Backpack")
	local character = player.Character
	if not backpack or backpack:FindFirstChild("Harpoon") or (character and character:FindFirstChild("Harpoon")) then
		return
	end
	local tool = Instance.new("Tool")
	tool.Name = "Harpoon"
	tool.CanBeDropped = false

	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.4, 0.4, 4)
	handle.Color = Color3.fromRGB(150, 150, 160)
	handle.Material = Enum.Material.Metal
	handle.Parent = tool

	local tip = Instance.new("Part")
	tip.Name = "Tip"
	tip.Shape = Enum.PartType.Ball
	tip.Size = Vector3.new(0.6, 0.6, 0.6)
	tip.Material = Enum.Material.Neon
	tip.Color = READY_COLOR
	tip.CanCollide = false
	tip.Massless = true
	tip.Parent = tool
	local weld = Instance.new("Weld")
	weld.Part0 = handle
	weld.Part1 = tip
	weld.C0 = CFrame.new(0, 0, -2.2)
	weld.Parent = tip
	local rope = Instance.new("Attachment")
	rope.Name = "RopeStart"
	rope.Parent = tip

	local ping = Instance.new("Sound")
	ping.Name = "ReadyPing"
	ping.SoundId = "rbxasset://sounds/electronicpingshort.wav"
	ping.Volume = 0.5
	ping.Parent = handle

	tool.Parent = backpack
end

local lastShot: { [Player]: number } = {}

fireHarpoon.OnServerEvent:Connect(function(player: Player, aim: unknown)
	if typeof(aim) ~= "Vector3" then
		return
	end
	local now = os.clock()
	if now - (lastShot[player] or 0) < Config.HarpoonCooldown then
		return
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local tool = character and character:FindFirstChild("Harpoon")
	if not character or not root or not tool or not tool:IsA("Tool") then
		return -- debe tener el arpón equipado
	end
	local delta = aim - root.Position
	if delta.Magnitude < 0.1 then
		return
	end
	lastShot[player] = now

	-- Recarga: punta roja y, al terminar, verde + ping.
	setTipReady(tool, false)
	task.delay(Config.HarpoonCooldown, function()
		if tool.Parent then
			setTipReady(tool, true)
			local ping = tool:FindFirstChild("ReadyPing", true) :: Sound?
			if ping then
				ping:Play()
			end
		end
	end)

	local tip = tool:FindFirstChild("Tip")
	local rope = tip and tip:FindFirstChild("RopeStart") :: Attachment?
	if not rope then
		return
	end

	local range = Upgrades.HarpoonRange(player)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }
	params.IgnoreWater = true
	local result = workspace:Raycast(root.Position, delta.Unit * range, params)
	local endPos = if result then result.Position else root.Position + delta.Unit * range
	local hit = result and result.Instance

	if hit and hit:IsDescendantOf(fishFolder) and not hit:GetAttribute("Hooked") then
		if Inventory.Add(player, "Fish") then
			pullFish(player, hit :: BasePart, rope)
			task.delay(Config.FishRespawn, spawnFish)
		else
			tempShot(rope, endPos)
			notify(player, "Inventario lleno")
		end
	elseif hit and hit.Parent == creaturesFolder then
		tempShot(rope, endPos)
		if hit.Name == "Creature_Small" then
			creatureHit:Fire(hit)
		else
			notify(player, "Esa criatura es demasiado grande para el arpón")
		end
	else
		tempShot(rope, endPos)
	end
end)

local function onPlayer(player: Player)
	player.CharacterAdded:Connect(function()
		giveHarpoon(player)
	end)
	if player.Character then
		task.spawn(giveHarpoon, player)
	end
end
Players.PlayerAdded:Connect(onPlayer)
for _, p in Players:GetPlayers() do
	onPlayer(p)
end
Players.PlayerRemoving:Connect(function(p)
	lastShot[p] = nil
end)

for _ = 1, FISH_COUNT do
	spawnFish()
end
spawnTreasure()
