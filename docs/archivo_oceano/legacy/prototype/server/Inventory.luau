--!strict
-- Inventario por jugador (solo servidor). El HUD lee el conteo por atributos del Player.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local Inventory = {}
local data: { [Player]: { [string]: number } } = {}

local function count(items: { [string]: number }): number
	local n = 0
	for _, v in items do
		n += v
	end
	return n
end

local function refresh(player: Player)
	local items = data[player]
	player:SetAttribute("InventoryCount", if items then count(items) else 0)
	player:SetAttribute("InventoryCapacity", Config.InventoryCapacity)
end

-- Carga desde datos guardados (se descartan claves desconocidas).
function Inventory.Set(player: Player, saved: any)
	local items: { [string]: number } = {}
	if type(saved) == "table" then
		for kind in Config.Values do
			local v = saved[kind]
			if type(v) == "number" and v > 0 then
				items[kind] = math.floor(v)
			end
		end
	end
	data[player] = items
	refresh(player)
end

function Inventory.Get(player: Player): { [string]: number }?
	return data[player]
end

function Inventory.Clear(player: Player)
	data[player] = nil
end

-- false si el inventario está lleno o el tipo no existe.
function Inventory.Add(player: Player, kind: string): boolean
	local items = data[player]
	if not items or Config.Values[kind] == nil or count(items) >= Config.InventoryCapacity then
		return false
	end
	items[kind] = (items[kind] or 0) + 1
	refresh(player)
	return true
end

-- Vende todo; devuelve las monedas ganadas.
function Inventory.SellAll(player: Player): number
	local items = data[player]
	local stats = player:FindFirstChild("leaderstats")
	if not items or not stats then
		return 0
	end
	local total = 0
	for kind, n in items do
		total += (Config.Values[kind] or 0) * n
	end
	table.clear(items)
	local coins = (stats :: any).Coins
	coins.Value += total
	refresh(player)
	return total
end

return Inventory
