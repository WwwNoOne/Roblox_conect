--!strict
-- Tienda del puerto: estación con prompt (la UI la abre el cliente) y RequestPurchase.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Upgrades = require(script.Parent:WaitForChild("Upgrades"))
local requestPurchase = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("RequestPurchase") :: RemoteFunction

local station = Instance.new("Part")
station.Name = "ShopStation"
station.Size = Vector3.new(3, 4, 3)
station.Color = Color3.fromRGB(60, 170, 90)
station.Anchored = true
station.Position = Vector3.new(-68, 6, 8)
station.Parent = workspace

local prompt = Instance.new("ProximityPrompt")
prompt.Name = "ShopPrompt"
prompt.ActionText = "Abrir tienda"
prompt.ObjectText = "Mejoras"
prompt.HoldDuration = 0
prompt.MaxActivationDistance = 14
prompt.KeyboardKeyCode = Enum.KeyCode.E
prompt.Parent = station

local function notify(player: Player, msg: string)
	player:SetAttribute("HudNotice", msg .. "|" .. tostring(os.clock()))
end

local MESSAGES: { [string]: string } = {
	NoFunds = "Monedas insuficientes",
	MaxLevel = "Ya tienes el nivel máximo",
	NotReady = "Datos aún cargando",
	BadRequest = "Solicitud inválida",
	TooFar = "Acércate a la tienda",
}

local lastPurchase: { [Player]: number } = {}

requestPurchase.OnServerInvoke = function(player: Player, itemId: unknown)
	local now = os.clock()
	if now - (lastPurchase[player] or 0) < Config.PurchaseCooldown then
		return false, "Cooldown"
	end
	lastPurchase[player] = now

	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root or (root.Position - station.Position).Magnitude > Config.ShopUseDistance then
		notify(player, MESSAGES.TooFar)
		return false, "TooFar"
	end

	local ok, info = Upgrades.Purchase(player, itemId)
	if ok then
		notify(player, "Comprado: " .. Config.Upgrades[itemId :: string].Name)
	else
		notify(player, MESSAGES[info] or "No se pudo comprar")
	end
	return ok, info
end

Players.PlayerRemoving:Connect(function(p)
	lastPurchase[p] = nil
end)
