--!strict
-- Silencia el sonido de nadar por defecto de Roblox (RbxCharacterSounds crea un Sound "Swimming" en HumanoidRootPart).
-- Solo suena la brazada propia (Sfx "Movimiento", ver SwimClient).
local Players = game:GetService("Players")

local player = Players.LocalPlayer

local function mute(sound: Instance)
	if sound:IsA("Sound") and sound.Name == "Swimming" then
		sound.Volume = 0
		sound:GetPropertyChangedSignal("Volume"):Connect(function()
			if sound.Volume ~= 0 then
				sound.Volume = 0
			end
		end)
		sound:Stop()
	end
end

local function onCharacter(character: Model)
	local root = character:WaitForChild("HumanoidRootPart", 10)
	if not root then
		return
	end
	for _, d in root:GetChildren() do
		mute(d)
	end
	root.ChildAdded:Connect(mute)
end

player.CharacterAdded:Connect(onCharacter)
if player.Character then
	task.spawn(onCharacter, player.Character)
end
