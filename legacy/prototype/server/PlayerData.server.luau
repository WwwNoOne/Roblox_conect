--!strict
-- leaderstats + DataStore PlayerSave_v1 {Coins, Stage, InventoryTable}
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Inventory = require(script.Parent:WaitForChild("Inventory"))
local Upgrades = require(script.Parent:WaitForChild("Upgrades"))
local store: DataStore? = nil
local okStore, storeOrErr = pcall(function()
	return DataStoreService:GetDataStore(Config.SaveKey)
end)
if okStore then
	store = storeOrErr :: DataStore
else
	warn(`[PlayerData] DataStore no disponible (lugar sin publicar?): {storeOrErr}`)
end

local function load(player: Player)
	local data: any = nil
	local ok, err = pcall(function()
		if store then
			data = store:GetAsync(tostring(player.UserId))
		end
	end)
	if not ok then
		warn(`[PlayerData] load failed for {player.Name}: {err}`)
	end

	local stats = Instance.new("Folder")
	stats.Name = "leaderstats"
	local coins = Instance.new("IntValue")
	coins.Name = "Coins"
	coins.Value = if data and type(data.Coins) == "number" then data.Coins else 0
	coins.Parent = stats
	local stage = Instance.new("IntValue")
	stage.Name = "Stage"
	stage.Value = if data and type(data.Stage) == "number" then data.Stage else 1
	stage.Parent = stats
	stats.Parent = player

	Inventory.Set(player, if data then data.InventoryTable else nil)
	Upgrades.Set(player, if data then data.Upgrades else nil)
end

local function save(player: Player)
	local stats = player:FindFirstChild("leaderstats")
	local inv = Inventory.Get(player)
	if not store or not stats or not inv then
		return
	end
	local payload = {
		Coins = (stats :: any).Coins.Value,
		Stage = (stats :: any).Stage.Value,
		InventoryTable = inv,
		Upgrades = Upgrades.Get(player) or {},
	}
	local ok, err = pcall(function()
		(store :: DataStore):SetAsync(tostring(player.UserId), payload)
	end)
	if not ok then
		warn(`[PlayerData] save failed for {player.Name}: {err}`)
	end
end

Players.PlayerAdded:Connect(load)
Players.PlayerRemoving:Connect(function(player)
	save(player)
	Inventory.Clear(player)
	Upgrades.Clear(player)
end)
for _, p in Players:GetPlayers() do
	task.spawn(load, p)
end
game:BindToClose(function()
	for _, p in Players:GetPlayers() do
		save(p)
	end
end)
