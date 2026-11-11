--!strict
-- Lógica de tesoros, venta, reparación y tienda (T05). Todo ocurre en el servidor, sin yields,
-- así que cada operación es atómica frente a solicitudes simultáneas.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Types = require(Shared:WaitForChild("Types"))
local Runs = require(script.Parent:WaitForChild("Runs"))

export type Result = { ok: boolean, err: string?, earned: number?, state: Types.ShopState? }

local Economy = {}

local function weightOf(run: Runs.Run, userId: number): number
	local total = 0
	for _, item in run.carried[userId] or {} do
		total += item.weight
	end
	return total
end

local function syncCarry(player: Player, run: Runs.Run?)
	player:SetAttribute("CarryWeight", if run then weightOf(run, player.UserId) else 0)
	player:SetAttribute("CarryCapacity", Config.Economy.CarryCapacity)
end

local function aliveInside(player: Player): boolean
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	return humanoid ~= nil and humanoid.Health > 0 and Runs.IsUserInside(player.UserId)
end

function Economy.Pickup(player: Player, size: string): Result
	local run = Runs.GetByUser(player.UserId)
	local def = (Config.Economy.Treasure :: any)[size]
	if not run or run.ended or run.state ~= "Level" or not def then
		return { ok = false, err = "NOT_AVAILABLE" }
	end
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return { ok = false, err = "DEAD" }
	end
	if weightOf(run, player.UserId) + def.Weight > Config.Economy.CarryCapacity then
		return { ok = false, err = "TOO_HEAVY" }
	end
	local list = run.carried[player.UserId] or {}
	run.carried[player.UserId] = list
	table.insert(list, { size = size, value = def.Value, weight = def.Weight })
	syncCarry(player, run)
	return { ok = true }
end

-- Vende todo lo que carga el jugador; suma al fondo común una sola vez.
function Economy.Sell(player: Player): Result
	local run = Runs.GetByUser(player.UserId)
	if not run or run.ended or run.state ~= "Stopover" then
		return { ok = false, err = "NOT_AT_PARADA" }
	end
	if not aliveInside(player) then
		return { ok = false, err = "NOT_INSIDE" }
	end
	local list = run.carried[player.UserId]
	if not list or #list == 0 then
		return { ok = false, err = "NOTHING_TO_SELL" }
	end
	local total = 0
	for _, item in list do
		total += item.value
	end
	run.carried[player.UserId] = {}
	Runs.AddMoney(run.code, total)
	syncCarry(player, run)
	return { ok = true, earned = total }
end

local function repairCost(run: Runs.Run): number
	local missing = Config.Run.HullMax - run.hull
	local amount = math.min(Config.Economy.RepairChunk, missing)
	return math.ceil(amount * Config.Economy.RepairCostPerHp)
end

function Economy.Repair(player: Player): Result
	local run = Runs.GetByUser(player.UserId)
	if not run or run.ended or run.state ~= "Stopover" then
		return { ok = false, err = "NOT_AT_PARADA" }
	end
	if not aliveInside(player) then
		return { ok = false, err = "NOT_INSIDE" }
	end
	local missing = Config.Run.HullMax - run.hull
	if missing <= 0.01 then
		return { ok = false, err = "HULL_FULL" }
	end
	local amount = math.min(Config.Economy.RepairChunk, missing)
	local cost = math.ceil(amount * Config.Economy.RepairCostPerHp)
	if run.money < cost then
		return { ok = false, err = "NOT_ENOUGH_MONEY" }
	end
	run.money -= cost
	run.hull = math.min(Config.Run.HullMax, run.hull + amount)
	return { ok = true }
end

function Economy.ShopState(player: Player): Types.ShopState?
	local run = Runs.GetByUser(player.UserId)
	if not run then
		return nil
	end
	local items: { Types.ShopItem } = {}
	for id, def in Config.Economy.Shop :: any do
		local level = run.upgrades[id] or 0
		table.insert(items, {
			id = id,
			name = def.Name,
			level = level,
			maxLevel = #def.Prices,
			price = def.Prices[level + 1],
		})
	end
	table.sort(items, function(a, b)
		return a.id < b.id
	end)
	return {
		money = run.money,
		items = items,
		hull = math.floor(run.hull + 0.5),
		hullMax = Config.Run.HullMax,
		repairCost = repairCost(run),
	}
end

function Economy.Buy(player: Player, itemId: unknown): Result
	local run = Runs.GetByUser(player.UserId)
	if not run or run.ended or run.state ~= "Stopover" then
		return { ok = false, err = "NOT_AT_PARADA" }
	end
	if not aliveInside(player) then
		return { ok = false, err = "NOT_INSIDE" }
	end
	local def = if type(itemId) == "string" then (Config.Economy.Shop :: any)[itemId] else nil
	if not def or type(itemId) ~= "string" then
		return { ok = false, err = "UNKNOWN_ITEM" }
	end
	local level = run.upgrades[itemId] or 0
	local price = def.Prices[level + 1]
	if not price then
		return { ok = false, err = "MAX_LEVEL" }
	end
	if run.money < price then
		return { ok = false, err = "NOT_ENOUGH_MONEY" }
	end
	run.money -= price
	run.upgrades[itemId] = level + 1
	return { ok = true, state = Economy.ShopState(player) }
end

Players.PlayerAdded:Connect(function(player)
	syncCarry(player, nil)
end)
for _, p in Players:GetPlayers() do
	syncCarry(p, nil)
end

Economy.SyncCarry = syncCarry

return Economy
