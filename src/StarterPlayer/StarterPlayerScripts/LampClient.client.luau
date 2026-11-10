--!strict
-- Tecla F (o botón táctil) para encender/apagar la lámpara; el servidor decide el estado.
local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local toggleLamp = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("ToggleLamp") :: RemoteEvent

ContextActionService:BindAction("ToggleLamp", function(_name, state)
	if state == Enum.UserInputState.Begin then
		toggleLamp:FireServer()
	end
	return Enum.ContextActionResult.Sink
end, true, Enum.KeyCode.F)
ContextActionService:SetTitle("ToggleLamp", "Luz")
