--!strict
-- Crea los remotos (lista en Shared/Remotes) y levanta los servicios.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))

local folder = Instance.new("Folder")
folder.Name = "Remotes"
for name, kind in Remotes.List do
	local remote: Instance = if kind == "Function" then Instance.new("RemoteFunction") else Instance.new("RemoteEvent")
	remote.Name = name
	remote.Parent = folder
end
folder.Parent = ReplicatedStorage

-- Los handlers de RemoteFunction (CreateRoom, JoinRoom, RequestPurchase, DepositTreasure) los definen
-- sus servicios (T02, T05). Mientras no existan, el invoke del cliente queda sin respuesta: no llamarlos aún.

-- Primera persona fija para todos (FirstPersonClient la refuerza en el cliente; esto cubre a quien entra antes de que cargue).
local StarterPlayer = game:GetService("StarterPlayer")
StarterPlayer.CameraMode = Enum.CameraMode.LockFirstPerson
StarterPlayer.CameraMinZoomDistance = 0.5
StarterPlayer.CameraMaxZoomDistance = 0.5
