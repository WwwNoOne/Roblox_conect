--!strict
-- Peces, tesoros, arpón y estación de venta (modelos provisionales hasta tener los de Codex).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Inventory = require(script.Parent:WaitForChild("Inventory"))
local fireHarpoon = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("FireHarpoon") :: RemoteEvent
local markers = workspace:WaitForChild("Markers")

local FISH_COUNT = 5
local FISH_SPEED = 6 -- studs/s

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
		while fish.Parent do
			local target = fishCenter + randomOffset()
			local delta = target - fish.Position
			if delta.Magnitude > 1 then
				local duration = delta.Magnitude / FISH_SPEED
				TweenService
					:Create(fish, TweenInfo.new(duration, Enum.EasingStyle.Linear), {
						CFrame = CFrame.lookAt(target, target + delta),
					})
					:Play()
				task.wait(duration)
			else
				task.wait(0.5)
			end
		end
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
	if not character or not root or not character:FindFirstChild("Harpoon") then
		return -- debe tener el arpón equipado
	end
	lastShot[player] = now

	local delta = aim - root.Position
	if delta.Magnitude < 0.1 then
		return
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }
	params.IgnoreWater = true
	local result = workspace:Raycast(root.Position, delta.Unit * Config.HarpoonRange, params)
	if not result or not result.Instance:IsDescendantOf(fishFolder) then
		return
	end
	if Inventory.Add(player, "Fish") then
		result.Instance:Destroy()
		task.delay(Config.FishRespawn, spawnFish)
	else
		notify(player, "Inventario lleno")
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
