--!strict
-- Crea los Remotes definidos en el GDD y levanta los servicios.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local remotes = Instance.new("Folder")
remotes.Name = "Remotes"
remotes.Parent = ReplicatedStorage

local updateHud = Instance.new("RemoteEvent")
updateHud.Name = "UpdateHUD"
updateHud.Parent = remotes

local fireHarpoon = Instance.new("RemoteEvent")
fireHarpoon.Name = "FireHarpoon"
fireHarpoon.Parent = remotes

local requestPurchase = Instance.new("RemoteFunction")
requestPurchase.Name = "RequestPurchase"
requestPurchase.Parent = remotes

-- TODO(RequestPurchase): validar saldo en servidor cuando exista el catálogo de mejoras.
requestPurchase.OnServerInvoke = function(_player: Player, _itemId: unknown)
	return false, "NotImplemented"
end
