--!strict
-- Efectos de sonido. Los sonidos viven en Workspace.sonidos o sueltos en Workspace (se agregan a mano); aquí se buscan por prefijo
-- del nombre (sin distinguir mayúsculas), así que "Bubbles Small..." encuentra todas las variantes de burbujas
-- y se elige una al azar. Los nombres/prefijos que usa el juego están en Config.Sfx.
local Debris = game:GetService("Debris")
local SoundService = game:GetService("SoundService")

local Sfx = {}

-- Busca en Workspace.sonidos y también entre los Sound sueltos del Workspace.
local function matches(prefix: string): { Sound }
	local list: { Sound } = {}
	local p = string.lower(prefix)
	-- workspace.sonidos con todas sus subcarpetas (Efectos_ascensor, ...) y los Sound sueltos del Workspace.
	local pools: { { Instance } } = {}
	local sonidos = workspace:FindFirstChild("sonidos")
	if sonidos then
		table.insert(pools, sonidos:GetDescendants())
	end
	table.insert(pools, workspace:GetChildren())
	for _, pool in pools do
		for _, s in pool do
			if s:IsA("Sound") and string.sub(string.lower(s.Name), 1, #p) == p then
				table.insert(list, s)
			end
		end
	end
	return list
end

-- Reproduce una copia (así varios a la vez no se cortan). Con `parent` = BasePart el sonido es 3D.
-- `maxDistance`: alcance (studs) del sonido 3D; sin él se usa el de la plantilla.
function Sfx.Play(prefix: string, parent: Instance?, volume: number?, maxDistance: number?): Sound?
	local list = matches(prefix)
	if #list == 0 then
		return nil
	end
	local sound = list[math.random(#list)]:Clone()
	sound.Looped = false
	if volume then
		sound.Volume = volume
	end
	if maxDistance then
		sound.RollOffMode = Enum.RollOffMode.Linear
		sound.RollOffMaxDistance = maxDistance
		sound.RollOffMinDistance = math.min(sound.RollOffMinDistance, maxDistance / 4)
	end
	sound.Parent = parent or SoundService
	sound.Ended:Once(function()
		sound:Destroy()
	end)
	Debris:AddItem(sound, 20)
	sound:Play()
	return sound
end

-- Plantilla (sin clonar) de un sonido por prefijo, para bucles largos que no deben destruirse a los 20 s.
function Sfx.Find(prefix: string): Sound?
	local list = matches(prefix)
	return if #list > 0 then list[math.random(#list)] else nil
end

-- Como Play, pero elige al azar entre varios prefijos.
function Sfx.PlayAny(prefixes: { string }, parent: Instance?, volume: number?, maxDistance: number?): Sound?
	if #prefixes == 0 then
		return nil
	end
	return Sfx.Play(prefixes[math.random(#prefixes)], parent, volume, maxDistance)
end

return Sfx
