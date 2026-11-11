--!strict
-- Conecta Economy con el mundo: tesoros en los TreasureSpawn del nivel, paneles del submarino y remotos.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Types = require(Shared:WaitForChild("Types"))
local Runs = require(script.Parent:WaitForChild("Runs"))
local Economy = require(script.Parent:WaitForChild("Economy"))

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local shopOpen = remotes:WaitForChild("ShopOpen") :: RemoteEvent
local sellTreasure = remotes:WaitForChild("SellTreasure") :: RemoteFunction
local requestPurchase = remotes:WaitForChild("RequestPurchase") :: RemoteFunction

local treasureFolder = Instance.new("Folder")
treasureFolder.Name = "RunTreasure"
treasureFolder.Parent = workspace

local MESSAGES: { [string]: string } = {
	TOO_HEAVY = "Demasiado peso",
	NOT_ENOUGH_MONEY = "Fondos insuficientes",
	NOTHING_TO_SELL = "No llevas tesoros",
	HULL_FULL = "El casco está intacto",
	NOT_AT_PARADA = "Solo en la Parada",
	NOT_INSIDE = "Debes estar dentro del submarino",
	MAX_LEVEL = "Nivel máximo",
}

local function notice(player: Player, text: string)
	player:SetAttribute("HudNotice", text .. "|" .. tostring(os.clock()))
end

local function fail(player: Player, err: string?)
	if err and MESSAGES[err] then
		notice(player, MESSAGES[err])
	end
end

-- ===== Tesoros =====
local function clearTreasure()
	treasureFolder:ClearAllChildren()
end

local function makeTreasure(att: Attachment, size: string)
	local def = (Config.Economy.Treasure :: any)[size]
	if not def then
		return
	end
	local models = ServerStorage:FindFirstChild("Models")
	local template = models and models:FindFirstChild("Treasure_" .. size)
	local root: BasePart
	local object: Instance
	if template and template:IsA("Model") and template.PrimaryPart then
		local clone = template:Clone()
		clone:PivotTo(CFrame.new(att.WorldPosition + Vector3.new(0, def.Size.Y / 2, 0)))
		object = clone
		root = clone.PrimaryPart :: BasePart
	else
		local part = Instance.new("Part") -- provisional hasta A03
		part.Name = "Treasure_" .. size
		part.Size = def.Size
		part.Color = def.Color
		part.Material = Enum.Material.Neon
		part.CFrame = CFrame.new(att.WorldPosition + Vector3.new(0, def.Size.Y / 2 + 0.2, 0))
		object = part
		root = part
	end
	root.Anchored = true
	root.CanCollide = false
	object:SetAttribute("Size", size)

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Recoger"
	prompt.ObjectText = "Tesoro " .. size
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0.4
	prompt.MaxActivationDistance = 8
	prompt.RequiresLineOfSight = false
	prompt.Parent = root
	prompt.Triggered:Connect(function(player: Player)
		if not object.Parent then
			return -- ya recogido por otro jugador
		end
		local result = Economy.Pickup(player, size)
		if result.ok then
			object:Destroy()
		else
			fail(player, result.err)
		end
	end)
	object.Parent = treasureFolder
end

local function spawnTreasure(mapName: string)
	clearTreasure()
	local maps = workspace:FindFirstChild("Maps")
	local map = maps and maps:FindFirstChild(mapName)
	if not map then
		return
	end
	for _, d in map:GetDescendants() do
		if d:IsA("Attachment") and d.Name == "TreasureSpawn" then
			local size = d:GetAttribute("Size")
			makeTreasure(d, if type(size) == "string" then size else "Small")
		end
	end
end

-- ===== Paneles del submarino =====
local sub = workspace:WaitForChild("Submarine", 30)
local panelPrompts: { ProximityPrompt } = {}
if sub then
	local function panel(stationName: string, action: string, handler: (Player) -> ())
		local station = sub:FindFirstChild(stationName)
		local att = station and station:FindFirstChild("PromptAttachment", true)
		if not att then
			warn("[Economy] Falta " .. stationName .. ".PromptAttachment")
			return
		end
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = action
		prompt.ObjectText = stationName
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt.HoldDuration = 0.3
		prompt.MaxActivationDistance = 8
		prompt.RequiresLineOfSight = false
		prompt.Enabled = false
		prompt.Parent = att
		prompt.Triggered:Connect(handler)
		table.insert(panelPrompts, prompt)
	end

	panel("SellStation", "Vender tesoros", function(player)
		local r = Economy.Sell(player)
		if r.ok then
			notice(player, "Vendido: +$" .. tostring(r.earned))
		else
			fail(player, r.err)
		end
	end)
	panel("RepairStation", "Reparar casco", function(player)
		local r = Economy.Repair(player)
		if r.ok then
			notice(player, "Casco reparado")
		else
			fail(player, r.err)
		end
	end)
	panel("ShopStation", "Tienda", function(player)
		local state = Economy.ShopState(player)
		if state then
			shopOpen:FireClient(player, state)
		end
	end)
end

-- ===== Estados =====
Runs.StateChanged:Connect(function(code: string, state: Types.RunState)
	local run = Runs.Get(code)
	if not run then
		return
	end
	if state == "Descending" and run.zone == 0 then
		for _, userId in run.members do
			local p = Players:GetPlayerByUserId(userId)
			if p then
				Economy.SyncCarry(p, run)
			end
		end
	end
	if state == "Level" then
		local def = Config.Run.Stages[run.zone]
		if def then
			spawnTreasure(def.Map)
		end
	elseif state == "Descending" or state == "Won" or state == "Lost" then
		clearTreasure()
	end
	for _, prompt in panelPrompts do
		prompt.Enabled = state == "Stopover"
	end
end)

-- ===== Remotos (validados en servidor; mismo camino que los paneles) =====
local last: { [Player]: number } = {}
local function throttled(player: Player): boolean
	local now = os.clock()
	if now - (last[player] or 0) < 0.3 then
		return true
	end
	last[player] = now
	return false
end

sellTreasure.OnServerInvoke = function(player: Player)
	if throttled(player) then
		return { ok = false, err = "TOO_FAST" }
	end
	return Economy.Sell(player)
end

-- itemId: "Repair" o el id de una mejora (Armor, Oxygen).
requestPurchase.OnServerInvoke = function(player: Player, itemId: unknown)
	if throttled(player) then
		return { ok = false, err = "TOO_FAST" }
	end
	local result = if itemId == "Repair" then Economy.Repair(player) else Economy.Buy(player, itemId)
	result.state = Economy.ShopState(player)
	return result
end

Players.PlayerRemoving:Connect(function(player)
	last[player] = nil
end)
