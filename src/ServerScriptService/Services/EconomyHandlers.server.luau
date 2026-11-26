--!strict
-- Conecta Economy con el mundo: objetos de recolección en los TreasureSpawn del mapa (TreasureSpawner), paneles del ascensor y remotos.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Types = require(Shared:WaitForChild("Types"))
local Runs = require(script.Parent:WaitForChild("Runs"))
local Economy = require(script.Parent:WaitForChild("Economy"))
local WorldRefs = require(Shared:WaitForChild("WorldRefs"))
local TreasureSpawner = require(script.Parent:WaitForChild("TreasureSpawner"))

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local shopOpen = remotes:WaitForChild("ShopOpen") :: RemoteEvent
local depositTreasure = remotes:WaitForChild("DepositTreasure") :: RemoteFunction
local requestPurchase = remotes:WaitForChild("RequestPurchase") :: RemoteFunction

local MESSAGES: { [string]: string } = {
	INVENTORY_FULL = "Inventario lleno (4/4)",
	NOT_ENOUGH_MONEY = "Fondos insuficientes",
	NOTHING_TO_DEPOSIT = "No llevas tesoros",
	NOT_IN_LEVEL = "Solo se deposita durante un nivel",
	NOT_AT_PARADA = "Solo en la Parada",
	NOT_INSIDE = "Debes estar dentro del ascensor",
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
	TreasureSpawner.Clear()
end

local rng = Random.new()

local function makeTreasure(ground: Vector3, tier: string)
	TreasureSpawner.Spawn(ground, tier)
end

-- Huecos de un nivel: los TreasureSpawn (Attachment) colocados a mano en el mapa fijo cargado (Workspace.Maps). Cada hueco es el punto
-- donde se apoya el objeto.
local function collectSlots(): { Vector3 }
	local slots: { Vector3 } = {}
	local maps = workspace:FindFirstChild("Maps")
	if not maps then
		return slots
	end
	-- Huecos ocupados por generadores o cajas fuertes (ObjectiveService los coloca antes) no se usan.
	local blockers: { { cf: CFrame, half: Vector3 } } = {}
	local objectives = workspace:FindFirstChild("RunObjectives")
	if objectives then
		for _, m in objectives:GetChildren() do
			if m:IsA("Model") then
				local cf, size = m:GetBoundingBox()
				table.insert(blockers, { cf = cf, half = size / 2 + Vector3.new(1.5, 2, 1.5) })
			end
		end
	end
	local function blocked(p: Vector3): boolean
		for _, b in blockers do
			local rel = b.cf:PointToObjectSpace(p)
			if math.abs(rel.X) <= b.half.X and math.abs(rel.Y) <= b.half.Y and math.abs(rel.Z) <= b.half.Z then
				return true
			end
		end
		return false
	end
	for _, d in maps:GetDescendants() do
		if d:IsA("Attachment") and d.Name == "TreasureSpawn" and not blocked(d.WorldPosition) then
			table.insert(slots, d.WorldPosition)
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
		warn("[Economy] No hay huecos para los objetos de recolección (el mapa no tiene TreasureSpawn)")
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

-- ===== Paneles del ascensor =====
local sub = WorldRefs.WaitElevator(30)
local panelPrompts: { { prompt: ProximityPrompt, state: string } } = {}
if sub then
	local function panel(stationName: string, action: string, activeIn: string, handler: (Player) -> ())
		local station = sub:FindFirstChild(stationName, true)
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
				notice(p, "Parada segura. Aprovechen para comprar suministros.")
			end
		end
	end
	if state == "Level" then
		-- Tras colocar los objetivos (ObjectiveService), para no poner tesoros dentro de ellos.
		task.delay(0.3, function()
			if run.state == "Level" and not run.ended then
				spawnTreasure(run)
			end
		end)
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

-- itemId: id de una mejora de la tienda.
requestPurchase.OnServerInvoke = function(player: Player, itemId: unknown)
	if throttled(player) then
		return { ok = false, err = "TOO_FAST" }
	end
	local result = Economy.Buy(player, itemId)
	result.state = Economy.ShopState(player)
	return result
end

Players.PlayerRemoving:Connect(function(player)
	last[player] = nil
end)
