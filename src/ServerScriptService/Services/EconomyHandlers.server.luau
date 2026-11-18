--!strict
-- Conecta Economy con el mundo: objetos de recolección sobre el laberinto generado, paneles del submarino y remotos.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Types = require(Shared:WaitForChild("Types"))
local Runs = require(script.Parent:WaitForChild("Runs"))
local Economy = require(script.Parent:WaitForChild("Economy"))
local WorldRefs = require(Shared:WaitForChild("WorldRefs"))
local Assets = require(script.Parent:WaitForChild("Assets"))
local LevelState = require(script.Parent:WaitForChild("LevelState"))

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local shopOpen = remotes:WaitForChild("ShopOpen") :: RemoteEvent
local depositTreasure = remotes:WaitForChild("DepositTreasure") :: RemoteFunction
local requestPurchase = remotes:WaitForChild("RequestPurchase") :: RemoteFunction

local treasureFolder = Instance.new("Folder")
treasureFolder.Name = "RunTreasure"
treasureFolder.Parent = workspace

local MESSAGES: { [string]: string } = {
	INVENTORY_FULL = "Inventario lleno (4/4)",
	NOT_ENOUGH_MONEY = "Fondos insuficientes",
	NOTHING_TO_DEPOSIT = "No llevas tesoros",
	NOT_IN_LEVEL = "Solo se deposita durante un nivel",
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

local rng = Random.new()

-- Objetos del kit de recolección (AbismoAssets.<Config.Economy.Kit>) por clase, según su atributo ClaseSugerida.
local function kitModels(tier: string): { Model }
	local kit = Assets.Find(Config.Economy.Kit)
	local list: { Model } = {}
	if kit then
		for _, d in kit:GetDescendants() do
			if d:IsA("Model") and d:GetAttribute("ClaseSugerida") == tier then
				table.insert(list, d)
			end
		end
	end
	return list
end

local function pickTemplate(tier: string): Model?
	local list = kitModels(tier)
	return if #list > 0 then list[rng:NextInteger(1, #list)] else nil
end

local function prettyName(name: string): string
	return (string.gsub(name, "_", " "))
end

-- `ground`: punto de apoyo en el suelo. El objeto se coloca encima, con giro al azar.
local function makeTreasure(ground: Vector3, tier: string)
	local def = (Config.Economy.Treasure :: any)[tier]
	if not def then
		return
	end
	local template = pickTemplate(tier)
	local rootOrNil: BasePart? = nil
	local objectOrNil: Instance? = nil
	local label = "Objeto " .. tier
	if template then
		local clone = template:Clone()
		local handle = clone.PrimaryPart or clone:FindFirstChild("Handle") or clone:FindFirstChildWhichIsA("BasePart", true)
		if handle and handle:IsA("BasePart") then
			if def.Scale and def.Scale ~= 1 then
				clone:ScaleTo(clone:GetScale() * def.Scale)
			end
			for _, d in clone:GetDescendants() do
				if d:IsA("BasePart") then
					d.Anchored = true
					d.CanCollide = false
				end
			end
			local box, size = clone:GetBoundingBox()
			local target = ground + Vector3.new(0, size.Y / 2 + 0.1, 0)
			clone:PivotTo(clone:GetPivot() + (target - box.Position)) -- el centro de la caja queda en el punto objetivo
			local yaw = CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
			clone:PivotTo(CFrame.new(target) * yaw * CFrame.new(-target) * clone:GetPivot())
			objectOrNil = clone
			rootOrNil = handle
			label = prettyName(template.Name)
		else
			clone:Destroy()
		end
	end
	if not rootOrNil or not objectOrNil then
		local part = Instance.new("Part") -- provisional (sin kit)
		part.Name = "Objeto_" .. tier
		part.Size = def.Size
		part.Color = def.Color
		part.Material = Enum.Material.Neon
		part.CFrame = CFrame.new(ground + Vector3.new(0, def.Size.Y / 2 + 0.2, 0))
		objectOrNil = part
		rootOrNil = part
	end
	local object = objectOrNil :: Instance
	local root = rootOrNil :: BasePart
	root.Anchored = true
	root.CanCollide = false
	object:SetAttribute("Size", tier)
	object:SetAttribute("Value", def.Value)

	-- Luz propia: sin ella el objeto es casi invisible en el agua oscura.
	local glow = Instance.new("PointLight")
	glow.Color = def.Color
	glow.Range = Config.TreasureGlowRange
	glow.Brightness = Config.TreasureGlowBrightness
	glow.Shadows = false
	glow.Parent = root

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Recoger"
	prompt.ObjectText = string.format("%s  ($%d)", label, def.Value)
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0.4
	prompt.MaxActivationDistance = 8
	prompt.RequiresLineOfSight = false
	prompt.Parent = root
	prompt.Triggered:Connect(function(player: Player)
		if not object.Parent then
			return -- ya recogido por otro jugador
		end
		local result = Economy.Pickup(player, tier)
		if result.ok then
			object:Destroy()
		else
			fail(player, result.err)
		end
	end)
	object.Parent = treasureFolder
end

-- Huecos de un nivel: puntos de suelo al azar dentro de las piezas del laberinto generado (más en las salas) y los TreasureSpawn
-- (Attachment) que haya colocado a mano en las piezas. Cada hueco es el punto de suelo donde se apoya el objeto.
local function collectSlots(): { Vector3 }
	local slots: { Vector3 } = {}
	local B = Config.Economy.Balance
	local container = LevelState.container
	local plan = LevelState.plan
	if not container or not plan or #plan.nodes == 0 then
		return slots
	end
	for _, d in container:GetDescendants() do
		if d:IsA("Attachment") and d.Name == "TreasureSpawn" then
			table.insert(slots, d.WorldPosition)
		end
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { container }
	params.RespectCanCollide = true
	params.IgnoreWater = true
	local overlap = OverlapParams.new()
	overlap.FilterType = Enum.RaycastFilterType.Include
	overlap.FilterDescendantsInstances = { container }
	overlap.RespectCanCollide = true
	-- piezas con peso: las salas atraen más huecos que los tramos de pasillo
	local nodes: { any } = {}
	local total = 0
	for _, node in plan.nodes do
		local w = if node.def.kind == "room" then B.RoomWeight else 1
		total += w
		table.insert(nodes, { node = node, w = w })
	end
	local entry = LevelState.entry
	local attempts = 0
	while #slots < B.SlotCandidates and attempts < B.SlotAttempts do
		attempts += 1
		local r = rng:NextNumber() * total
		local pick: any = nodes[1].node
		for _, n in nodes do
			r -= n.w
			if r <= 0 then
				pick = n.node
				break
			end
		end
		local c: Vector3, h: Vector3 = pick.center, pick.half
		local margin = if pick.def.kind == "room" then B.EdgeMargin else 3
		local hx, hy, hz = math.max(h.X - margin, 1), math.max(h.Y - 2, 1), math.max(h.Z - margin, 1)
		local start = c + Vector3.new(rng:NextNumber(-hx, hx), rng:NextNumber(-hy, hy), rng:NextNumber(-hz, hz))
		if #workspace:GetPartBoundsInRadius(start, B.ClearRadius, overlap) == 0 then
			local hit = workspace:Raycast(start, Vector3.new(0, -(2 * h.Y + 4), 0), params)
			if hit and hit.Normal.Y > 0.7 and hit.Position.Y >= c.Y - h.Y - 1 then
				local ok = not entry or (hit.Position - entry).Magnitude >= B.SlotMinEntryDistance
				if ok then
					for _, s in slots do
						if (s - hit.Position).Magnitude < B.SlotSpacing then
							ok = false
							break
						end
					end
				end
				if ok then
					table.insert(slots, hit.Position)
				end
			end
		end
	end
	return slots
end

-- Reparte tipos para que el valor total sea >= cuota * margen y no mucho más (Config.Economy.Balance).
local TIERS = { "Small", "Medium", "Large" }

local function planTreasure(quota: number, run: Runs.Run?, slotCount: number): { string }
	local E = Config.Economy
	local B = E.Balance
	local upgradeLevels = 0
	if run then
		for _, lvl in run.upgrades do
			upgradeLevels += lvl
		end
	end
	local players = if run then #run.members else 1
	local margin = math.min(B.MaxMargin, B.Margin + B.PerUpgradeLevel * upgradeLevels + B.PerExtraPlayer * math.max(0, players - 1))
	local target = quota * margin
	local ceiling = target * B.MaxOver
	local small = E.Treasure.Small.Value

	local count = math.min(slotCount, math.max(B.MinCount, math.floor(slotCount * B.FillFraction + 0.5)))
	count = math.max(1, math.min(count, math.floor(ceiling / small)))
	local plan: { string } = table.create(count, "Small")
	local total = count * small

	-- Sube tipos al azar hasta llegar al objetivo.
	local function rank(t: string): number
		return table.find(TIERS, t) or 99
	end
	local guard = 0
	while total < target and guard < 1000 do
		guard += 1
		local i = rng:NextInteger(1, count)
		local r = rank(plan[i])
		if r < #TIERS then
			local nextTier = TIERS[r + 1]
			local gain = E.Treasure[nextTier].Value - E.Treasure[plan[i]].Value
			-- Si el salto se pasaría mucho del objetivo, usa el ascenso más pequeño (Small -> Medium) para quedar "un poco más".
			if gain > (target - total) + small * 2 then
				local smallIdx: number? = nil
				for k, t in plan do
					if t == "Small" then
						smallIdx = k
						break
					end
				end
				if smallIdx then
					i, nextTier = smallIdx, TIERS[2]
					gain = E.Treasure.Medium.Value - small
				end
			end
			if total + gain <= ceiling or total < target * 0.8 then
				plan[i] = nextTier
				total += gain
			end
		end
	end
	-- Si aún falta (pocos huecos en tipos bajos), añade más tesoros pequeños hasta llenar los huecos.
	while total < target and #plan < slotCount do
		table.insert(plan, "Small")
		total += small
	end
	return plan
end

local function spawnTreasure(run: Runs.Run?)
	clearTreasure()
	local slots = collectSlots()
	if #slots == 0 then
		warn("[Economy] No hay huecos para los objetos de recolección (laberinto sin generar o sin suelo libre)")
		return
	end
	local stage = run and (Config.Run.Stages :: any)[run.zone]
	local quota = (stage and stage.Quota) or 0
	for i = #slots, 2, -1 do
		local j = rng:NextInteger(1, i)
		slots[i], slots[j] = slots[j], slots[i]
	end
	if quota <= 0 then
		-- Nivel sin cuota (baliza): sin objetos de cuota, solo una muestra pequeña.
		for i = 1, math.min(#slots, Config.Economy.Balance.MinCount) do
			makeTreasure(slots[i], "Small")
		end
		return
	end
	local plan = planTreasure(quota, run, #slots)
	for i, tier in plan do
		makeTreasure(slots[i], tier)
	end
	print(string.format("[Economy] %d objetos de recolección repartidos (cuota %d, %d huecos)", #plan, quota, #slots))
end

-- ===== Paneles del submarino =====
local sub = WorldRefs.WaitSubmarine(30)
local panelPrompts: { { prompt: ProximityPrompt, state: string } } = {}
if sub then
	local function panel(stationName: string, action: string, activeIn: string, handler: (Player) -> ())
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
		table.insert(panelPrompts, { prompt = prompt, state = activeIn })
	end

	panel("SellStation", "Depositar tesoros", "Level", function(player)
		local r = Economy.Deposit(player)
		if r.ok then
			notice(player, "Depositado: $" .. tostring(r.earned))
		else
			fail(player, r.err)
		end
	end)
	panel("RepairStation", "Reparar casco", "Stopover", function(player)
		local r = Economy.Repair(player)
		if r.ok then
			notice(player, "Casco reparado")
		else
			fail(player, r.err)
		end
	end)
	panel("ShopStation", "Tienda", "Stopover", function(player)
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
	if state == "Stopover" then
		for _, userId in run.members do
			local p = Players:GetPlayerByUserId(userId)
			if p then
				notice(p, "El submarino sufrió daño. ¡Repárenlo y aprovechen para comprar suministros!")
			end
		end
	end
	if state == "Level" then
		spawnTreasure(run)
	elseif state == "Descending" or state == "Won" or state == "Lost" then
		clearTreasure()
	end
	for _, p in panelPrompts do
		p.prompt.Enabled = state == p.state
	end
end)

-- Resultado del cierre de nivel (cuota): aviso a la tripulación y sincronizar slots.
Runs.Settled:Connect(function(code: string, info: Runs.Settlement)
	local run = Runs.Get(code)
	if not run then
		return
	end
	local text
	if info.met then
		text = string.format("Cuota cumplida (%d/%d). +$%d (extra $%d)", info.deposited, info.quota, info.payout, info.bonus)
	else
		text = string.format("Cuota fallida (%d/%d). +$%d. Fallo %d/%d", info.deposited, info.quota, info.payout, info.failures, Config.Economy.Quota.MaxFailures)
	end
	if info.lostItems > 0 then
		text ..= string.format(" (perdidos sin depositar: %d)", info.lostItems)
	end
	for _, userId in run.members do
		local p = Players:GetPlayerByUserId(userId)
		if p then
			notice(p, text)
			Economy.SyncCarry(p, run)
		end
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

depositTreasure.OnServerInvoke = function(player: Player)
	if throttled(player) then
		return { ok = false, err = "TOO_FAST" }
	end
	return Economy.Deposit(player)
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
