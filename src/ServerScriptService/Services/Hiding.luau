--!strict
-- Lógica de esconderse en los volúmenes `Escondite` (taquillas, armarios, arbustos, cajas). Hide(): mete al jugador en la caja (anclado e invisible);
-- Release(): lo devuelve a donde estaba. El atributo de jugador `Hidden` lo leen los enemigos (no ven a quien está escondido).
local Players = game:GetService("Players")

local Hiding = {}

type State = { volume: BasePart, entry: CFrame, saved: { { inst: Instance, prop: string, value: any } } }
local hidden: { [Player]: State } = {}

local function character(player: Player): (Model?, BasePart?, Humanoid?)
	local c = player.Character
	local root = c and c:FindFirstChild("HumanoidRootPart")
	local humanoid = c and c:FindFirstChildOfClass("Humanoid")
	if c and root and root:IsA("BasePart") and humanoid and humanoid.Health > 0 then
		return c, root, humanoid
	end
	return nil, nil, nil
end

-- Hace invisible (o visible) al personaje; guarda los valores originales para restaurarlos.
local function setInvisible(c: Model, state: State, invisible: boolean)
	if invisible then
		for _, d in c:GetDescendants() do
			if d:IsA("BasePart") and d.Name ~= "HumanoidRootPart" then
				table.insert(state.saved, { inst = d, prop = "Transparency", value = d.Transparency })
				d.Transparency = 1
			elseif d:IsA("Decal") then
				table.insert(state.saved, { inst = d, prop = "Transparency", value = d.Transparency })
				d.Transparency = 1
			end
		end
	else
		for _, s in state.saved do
			if s.inst.Parent then
				(s.inst :: any)[s.prop] = s.value
			end
		end
		table.clear(state.saved)
	end
end

function Hiding.IsHidden(player: Player): boolean
	return hidden[player] ~= nil
end

function Hiding.Hide(player: Player, volume: BasePart): boolean
	if hidden[player] then
		return false
	end
	local c, root = character(player)
	if not c or not root then
		return false
	end
	local state: State = { volume = volume, entry = root.CFrame, saved = {} }
	hidden[player] = state
	setInvisible(c, state, true)
	root.AssemblyLinearVelocity = Vector3.zero
	local kind = volume:GetAttribute("Kind")
	if type(kind) == "string" then
		-- Escondites de los mapas nuevos: se mira hacia fuera (la puerta de la taquilla, el claro desde el arbusto). -Z del volumen.
		local out = volume.CFrame.LookVector * Vector3.new(1, 0, 1)
		local look = if out.Magnitude > 0.1 then out.Unit else root.CFrame.LookVector
		root.CFrame = CFrame.lookAt(volume.Position, volume.Position + look)
	else
		root.CFrame = CFrame.new(volume.Position) * root.CFrame.Rotation
	end
	root.Anchored = true
	player:SetAttribute("HiddenKind", if type(kind) == "string" then kind else "Box")
	player:SetAttribute("Hidden", true)
	return true
end

function Hiding.Release(player: Player): boolean
	local state = hidden[player]
	if not state then
		return false
	end
	hidden[player] = nil
	local c, root = character(player)
	if c then
		setInvisible(c, state, false)
	end
	if root then
		root.CFrame = state.entry
		root.AssemblyLinearVelocity = Vector3.zero
		root.Anchored = false
	end
	player:SetAttribute("Hidden", nil)
	player:SetAttribute("HiddenKind", nil)
	return true
end

function Hiding.ReleaseAll()
	for player in hidden do
		Hiding.Release(player)
	end
end

-- Limpieza al morir, reaparecer o salir.
local function watch(player: Player)
	player.CharacterRemoving:Connect(function()
		if hidden[player] then
			hidden[player] = nil
			player:SetAttribute("Hidden", nil)
			player:SetAttribute("HiddenKind", nil)
		end
	end)
end
for _, p in Players:GetPlayers() do
	watch(p)
end
Players.PlayerAdded:Connect(watch)
Players.PlayerRemoving:Connect(function(player)
	hidden[player] = nil
end)

return Hiding
