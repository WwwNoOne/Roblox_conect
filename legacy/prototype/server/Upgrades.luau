--!strict
-- Niveles de mejoras por jugador (solo servidor). El cliente los lee por atributos "Up_<Id>".
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local Upgrades = {}
local levels: { [Player]: { [string]: number } } = {}

local function refresh(player: Player)
	local own = levels[player]
	for id in Config.Upgrades do
		player:SetAttribute("Up_" .. id, if own then own[id] or 0 else 0)
	end
end

-- Carga desde datos guardados (descarta ids desconocidos y niveles fuera de rango).
function Upgrades.Set(player: Player, saved: any)
	local own: { [string]: number } = {}
	for id, def in Config.Upgrades do
		local v = if type(saved) == "table" then saved[id] else nil
		if type(v) == "number" then
			own[id] = math.clamp(math.floor(v), 0, #def.Prices)
		else
			own[id] = 0
		end
	end
	levels[player] = own
	refresh(player)
end

function Upgrades.Get(player: Player): { [string]: number }?
	return levels[player]
end

function Upgrades.Clear(player: Player)
	levels[player] = nil
end

function Upgrades.Level(player: Player, id: string): number
	local own = levels[player]
	return if own then own[id] or 0 else 0
end

function Upgrades.MaxOxygen(player: Player): number
	return Config.BaseOxygenSeconds + Upgrades.Level(player, "OxygenTank") * Config.Upgrades.OxygenTank.PerLevel
end

function Upgrades.LampRange(player: Player): number
	return Config.LampRange + Upgrades.Level(player, "Lamp") * Config.Upgrades.Lamp.RangeBonus
end

function Upgrades.HarpoonRange(player: Player): number
	return Config.HarpoonRange + Upgrades.Level(player, "Harpoon") * Config.Upgrades.Harpoon.RangeBonus
end

function Upgrades.HasSuit(player: Player): boolean
	return Upgrades.Level(player, "PressureSuit") > 0
end

-- Devuelve (ok, nuevoNivel | motivo). Valida id, nivel máximo y saldo en el servidor.
function Upgrades.Purchase(player: Player, id: unknown): (boolean, any)
	if type(id) ~= "string" then
		return false, "BadRequest"
	end
	local def = Config.Upgrades[id]
	local own = levels[player]
	local stats = player:FindFirstChild("leaderstats")
	if not def then
		return false, "BadRequest"
	end
	if not own or not stats then
		return false, "NotReady"
	end
	local level = own[id] or 0
	if level >= #def.Prices then
		return false, "MaxLevel"
	end
	local coins = (stats :: any).Coins
	local price = def.Prices[level + 1]
	if coins.Value < price then
		return false, "NoFunds"
	end
	coins.Value -= price
	own[id] = level + 1
	refresh(player)
	return true, level + 1
end

return Upgrades
