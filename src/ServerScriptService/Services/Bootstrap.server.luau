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

local toggleLamp = Instance.new("RemoteEvent")
toggleLamp.Name = "ToggleLamp"
toggleLamp.Parent = remotes

local aimLamp = Instance.new("RemoteEvent")
aimLamp.Name = "AimLamp"
aimLamp.Parent = remotes

-- Aviso interno (servidor) de que el arpón golpeó una criatura; lo escucha CreatureService.
local creatureHit = Instance.new("BindableEvent")
creatureHit.Name = "CreatureHit"
creatureHit.Parent = game:GetService("ServerScriptService")

local requestPurchase = Instance.new("RemoteFunction")
requestPurchase.Name = "RequestPurchase"
requestPurchase.Parent = remotes

-- RequestPurchase.OnServerInvoke lo define ShopService.
