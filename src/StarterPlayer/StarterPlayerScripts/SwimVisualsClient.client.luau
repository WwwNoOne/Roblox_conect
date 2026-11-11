--!strict
-- Efectos de natación para TODOS los personajes (cada cliente los dibuja localmente):
--  * inclinación del cuerpo según la dirección de nado (vertical al flotar, horizontal al avanzar);
--  * burbujas que salen de la boca cada pocos segundos (visibles en primera y tercera persona).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local S = Config.Swim
local terrain = workspace.Terrain

type State = {
	character: Model,
	root: BasePart,
	joint: (Motor6D | AnimationConstraint)?,
	baseC0: CFrame?,
	pitch: number,
	emitter: ParticleEmitter,
	nextBubble: number,
	water: boolean, -- en agua (cacheado; el estado Swimming de otros jugadores no siempre se replica)
	waterAt: number,
}

local states: { [Model]: State } = {}

local function inWater(position: Vector3): boolean
	local region = Region3.new(position - Vector3.new(2, 2, 2), position + Vector3.new(2, 2, 2)):ExpandToGrid(4)
	local ok, materials = pcall(function()
		local mats = terrain:ReadVoxels(region, 4)
		return mats
	end)
	if not ok then
		return false
	end
	local size = materials.Size
	for x = 1, size.X do
		for y = 1, size.Y do
			for z = 1, size.Z do
				if materials[x][y][z] == Enum.Material.Water then
					return true
				end
			end
		end
	end
	return false
end

-- R6 usa Motor6D "RootJoint"; R15 moderno usa Motor6D o AnimationConstraint "Root".
local function findRootJoint(character: Model): (Motor6D | AnimationConstraint)?
	for _, d in character:GetDescendants() do
		if (d:IsA("Motor6D") or d:IsA("AnimationConstraint")) and (d.Name == "RootJoint" or d.Name == "Root") then
			return d
		end
	end
	return nil
end

local function setup(character: Model)
	local head = character:WaitForChild("Head", 10) :: BasePart?
	local root = character:WaitForChild("HumanoidRootPart", 10) :: BasePart?
	if not head or not root or states[character] then
		return
	end
	local mouth = Instance.new("Attachment")
	mouth.Name = "BubbleMouth"
	mouth.Position = Vector3.new(0, -0.15, -0.55)
	mouth.Parent = head

	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "Bubbles"
	emitter.Texture = "rbxasset://textures/particles/smoke_main.dds"
	emitter.Rate = 0
	emitter.Lifetime = NumberRange.new(1.8, 3)
	emitter.Speed = NumberRange.new(1, 2.5)
	emitter.SpreadAngle = Vector2.new(25, 25)
	emitter.Acceleration = Vector3.new(0, 6, 0)
	emitter.Drag = 1.5
	emitter.EmissionDirection = Enum.NormalId.Top
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.12), NumberSequenceKeypoint.new(1, 0.4) })
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.45),
		NumberSequenceKeypoint.new(0.7, 0.6),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Color = ColorSequence.new(Color3.fromRGB(200, 240, 255))
	emitter.LightEmission = 0.5
	emitter.RotSpeed = NumberRange.new(-30, 30)
	emitter.Parent = mouth

	local joint = findRootJoint(character)
	states[character] = {
		character = character,
		root = root,
		joint = joint,
		baseC0 = if joint then joint.C0 else nil,
		pitch = 0,
		emitter = emitter,
		nextBubble = os.clock() + math.random() * S.BubbleMinSeconds,
		water = false,
		waterAt = 0,
	}
	character.AncestryChanged:Connect(function(_, parent)
		if not parent then
			states[character] = nil
		end
	end)
end

local function watch(p: Player)
	if p.Character then
		task.spawn(setup, p.Character)
	end
	p.CharacterAdded:Connect(function(character)
		task.spawn(setup, character)
	end)
end
for _, p in Players:GetPlayers() do
	watch(p)
end
Players.PlayerAdded:Connect(watch)

-- Los AnimationConstraint solo aceptan Transform, y debe fijarse antes de la simulación del fotograma.
RunService.Stepped:Connect(function()
	for _, st in states do
		local joint = st.joint
		if joint and joint:IsA("AnimationConstraint") and math.abs(st.pitch) > 0.01 then
			joint.Transform = CFrame.Angles(st.pitch, 0, 0)
		end
	end
end)

RunService.Heartbeat:Connect(function(dt)
	local now = os.clock()
	for _, st in states do
		local humanoid = st.character:FindFirstChildOfClass("Humanoid")
		if not humanoid or humanoid.Health <= 0 then
			continue
		end
		if now - st.waterAt > 0.5 then
			st.waterAt = now
			st.water = inWater(st.root.Position)
		end
		local swimming = st.water or humanoid:GetState() == Enum.HumanoidStateType.Swimming
		-- Inclinación: cuerpo vertical al flotar; se alinea con la dirección de nado al moverse.
		if st.joint and st.baseC0 then
			local target = 0
			if swimming then
				local v = st.root.AssemblyLinearVelocity
				local horizontal = Vector3.new(v.X, 0, v.Z).Magnitude
				local speed = v.Magnitude
				local activity = math.clamp(speed / S.LeanMinSpeed, 0, 1)
				local elevation = math.atan2(v.Y, horizontal) -- +: sube, −: baja
				target = -(math.pi / 2 - elevation) * activity * 0.9
			end
			st.pitch += (target - st.pitch) * (1 - math.exp(-S.LeanSmoothing * dt))
			if st.joint:IsA("Motor6D") then
				st.joint.C0 = CFrame.Angles(st.pitch, 0, 0) * st.baseC0
			end -- AnimationConstraint (R15 moderno): C0 es de solo lectura; se usa Transform en Stepped (ver abajo)
		end
		-- Burbujas ocasionales (solo en agua).
		if now >= st.nextBubble then
			st.nextBubble = now + S.BubbleMinSeconds + math.random() * (S.BubbleMaxSeconds - S.BubbleMinSeconds)
			if swimming then
				st.emitter:Emit(math.random(3, 6))
			end
		end
	end
end)
