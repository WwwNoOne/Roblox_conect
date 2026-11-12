--!strict
-- Efectos de sonido. Los sonidos viven en Workspace.sonidos (se agregan a mano); aquí se buscan por prefijo
-- del nombre (sin distinguir mayúsculas), así que "Bubbles Small..." encuentra todas las variantes de burbujas
-- y se elige una al azar. Los nombres/prefijos que usa el juego están en Config.Sfx.
local Debris = game:GetService("Debris")
local SoundService = game:GetService("SoundService")

local Sfx = {}

local function matches(prefix: string): { Sound }
	local list: { Sound } = {}
	local folder = workspace:FindFirstChild("sonidos")
	if not folder then
		return list
	end
	local p = string.lower(prefix)
	for _, s in folder:GetChildren() do
		if s:IsA("Sound") and string.sub(string.lower(s.Name), 1, #p) == p then
			table.insert(list, s)
		end
	end
	return list
end

-- Reproduce una copia (así varios a la vez no se cortan). Con `parent` = BasePart el sonido es 3D.
function Sfx.Play(prefix: string, parent: Instance?, volume: number?): Sound?
	local list = matches(prefix)
	if #list == 0 then
		return nil
	end
	local sound = list[math.random(#list)]:Clone()
	sound.Looped = false
	if volume then
		sound.Volume = volume
	end
	sound.Parent = parent or SoundService
	sound.Ended:Once(function()
		sound:Destroy()
	end)
	Debris:AddItem(sound, 20)
	sound:Play()
	return sound
end

return Sfx
