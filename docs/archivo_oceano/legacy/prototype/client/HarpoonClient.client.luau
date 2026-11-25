--!strict
-- Dispara el arpón hacia el cursor/toque; el servidor valida alcance, cooldown y golpe.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local fireHarpoon = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("FireHarpoon") :: RemoteEvent
local player = Players.LocalPlayer
local mouse = player:GetMouse()

local hooked: { [Tool]: boolean } = {}
local lastShot = 0

local function hook(tool: Tool)
	if hooked[tool] then
		return
	end
	hooked[tool] = true
	tool.Activated:Connect(function()
		local now = os.clock()
		if now - lastShot < Config.HarpoonCooldown then
			return
		end
		lastShot = now
		fireHarpoon:FireServer(mouse.Hit.Position)
	end)
end

local function watch(container: Instance)
	for _, child in container:GetChildren() do
		if child:IsA("Tool") and child.Name == "Harpoon" then
			hook(child)
		end
	end
	container.ChildAdded:Connect(function(child)
		if child:IsA("Tool") and child.Name == "Harpoon" then
			hook(child)
		end
	end)
end

local function onCharacter(character: Model)
	watch(character)
	watch(player:WaitForChild("Backpack"))
end

player.CharacterAdded:Connect(onCharacter)
if player.Character then
	onCharacter(player.Character)
end
