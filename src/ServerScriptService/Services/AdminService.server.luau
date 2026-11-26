--!strict
-- TEMPORAL, solo para pruebas en Studio: invencibilidad del jugador (panel de admin, ver AdminPanel.client).
-- No hace nada fuera de Studio. Borrar este archivo y AdminPanel.client.luau antes de publicar.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

if not RunService:IsStudio() then
	return
end

local remote = Instance.new("RemoteEvent")
remote.Name = "AdminGod"
remote.Parent = ReplicatedStorage

local connections: { [Player]: { RBXScriptConnection } } = {}

local function clear(player: Player)
	local list = connections[player]
	if list then
		for _, c in list do
			c:Disconnect()
		end
	end
	connections[player] = nil
end

-- Aplica o quita la invencibilidad en el personaje actual (y en los siguientes mientras siga activa).
local function apply(player: Player, character: Model?)
	clear(player)
	if not character then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local existing = character:FindFirstChild("AdminFF")
	if player:GetAttribute("AdminGod") ~= true then
		if existing then
			existing:Destroy()
		end
		if humanoid then
			humanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, true)
		end
		return
	end
	if not humanoid then
		return
	end
	if not existing then
		local ff = Instance.new("ForceField")
		ff.Name = "AdminFF"
		ff.Visible = false
		ff.Parent = character
	end
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
	humanoid.Health = humanoid.MaxHealth
	connections[player] = {
		humanoid.HealthChanged:Connect(function(health)
			if health < humanoid.MaxHealth and player:GetAttribute("AdminGod") == true then
				humanoid.Health = humanoid.MaxHealth
			end
		end),
	}
end

remote.OnServerEvent:Connect(function(player: Player, on: unknown)
	player:SetAttribute("AdminGod", on == true)
	apply(player, player.Character)
end)

Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function(character)
		if player:GetAttribute("AdminGod") == true then
			apply(player, character)
		end
	end)
end)

Players.PlayerRemoving:Connect(clear)
