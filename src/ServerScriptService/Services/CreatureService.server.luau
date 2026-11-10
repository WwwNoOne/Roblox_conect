--!strict
-- Criaturas hostiles (modelos provisionales). Toda la IA corre en el servidor.
-- Estados: Patrol -> Chase -> (Bite | Grab) -> Patrol.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local markers = workspace:WaitForChild("Markers")

-- Límites de la zona de agua de prueba (ver test_map_spec.md).
local WATER_MIN = Vector3.new(-55, -52, -92)
local WATER_MAX = Vector3.new(135, -6, 92)

type Creature = {
	part: Part,
	tier: any,
	state: "Patrol" | "Chase" | "Grab",
	target: Vector3,
	markerIndex: number,
	victim: Player?,
	victimChar: Model?,
	grabLeft: number,
	hitCooldown: number,
}

local creatures: { Creature } = {}
local grabbedBy: { [Player]: Creature } = {}
local immuneUntil: { [Player]: number } = {} -- inmunidad a agarres
local bitIFrame: { [Player]: number } = {}

local patrolMarkers = { markers:WaitForChild("Marker_Leviathan_Patrol_01") :: BasePart, markers:WaitForChild("Marker_Leviathan_Patrol_02") :: BasePart }

local function notify(player: Player, msg: string)
	player:SetAttribute("HudNotice", msg .. "|" .. tostring(os.clock()))
end

local function clampToWater(p: Vector3): Vector3
	return Vector3.new(
		math.clamp(p.X, WATER_MIN.X, WATER_MAX.X),
		math.clamp(p.Y, WATER_MIN.Y, WATER_MAX.Y),
		math.clamp(p.Z, WATER_MIN.Z, WATER_MAX.Z)
	)
end

local function randomWaterPoint(): Vector3
	return Vector3.new(
		math.random(WATER_MIN.X, WATER_MAX.X),
		math.random(WATER_MIN.Y, WATER_MAX.Y),
		math.random(WATER_MIN.Z, WATER_MAX.Z)
	)
end

local function pickPatrolTarget(c: Creature)
	if c.tier.Patrol == "Markers" then
		c.markerIndex = c.markerIndex % #patrolMarkers + 1
		c.target = patrolMarkers[c.markerIndex].Position
	else
		c.target = randomWaterPoint()
	end
end

local function getVictimParts(player: Player): (BasePart?, Humanoid?)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if root and humanoid and humanoid.Health > 0 then
		return root, humanoid
	end
	return nil, nil
end

-- Un jugador es objetivo si está bajo el agua, dentro de la zona y no inmune/agarrado.
local function isTargetable(player: Player, root: BasePart): boolean
	local p = root.Position
	return grabbedBy[player] == nil
		and (immuneUntil[player] or 0) < os.clock()
		and p.Y < Config.SeaLevelY - 1
		and p.X > WATER_MIN.X - 5
end

local function findTarget(c: Creature): Player?
	local best: Player? = nil
	local bestDist = c.tier.Detect
	for _, player in Players:GetPlayers() do
		local root = getVictimParts(player)
		if root and isTargetable(player, root) then
			local d = (root.Position - c.part.Position).Magnitude
			if d < bestDist then
				best, bestDist = player, d
			end
		end
	end
	return best
end

local function moveToward(c: Creature, goal: Vector3, speed: number, dt: number)
	local pos = c.part.Position
	local delta = goal - pos
	local step = speed * dt
	if delta.Magnitude < 0.01 then
		return
	end
	local newPos = if delta.Magnitude <= step then goal else pos + delta.Unit * step
	newPos = clampToWater(newPos)
	c.part.CFrame = CFrame.lookAt(newPos, newPos + delta)
end

local function endGrab(c: Creature, applyEffect: boolean)
	local player = c.victim
	if player then
		local char = c.victimChar
		local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root then
			root.Anchored = false
		end
		grabbedBy[player] = nil
		immuneUntil[player] = os.clock() + Config.GrabImmunity
		local humanoid = char and char:FindFirstChildOfClass("Humanoid")
		if applyEffect and humanoid and humanoid.Health > 0 then
			if c.tier.Behavior == "GrabKill" then
				humanoid.Health = 0
			else
				humanoid.Health = math.min(humanoid.Health, humanoid.MaxHealth * c.tier.LeaveHealthPct)
				notify(player, "Te soltó: vida al 50%")
			end
		end
	end
	c.victim, c.victimChar = nil, nil
	c.state = "Patrol"
	pickPatrolTarget(c)
end

local function startGrab(c: Creature, player: Player, root: BasePart)
	root.Anchored = true
	grabbedBy[player] = c
	c.victim = player
	c.victimChar = player.Character
	c.grabLeft = c.tier.GrabSeconds
	c.state = "Grab"
	notify(player, "¡Te atrapó!")
	pickPatrolTarget(c)
end

local function step(c: Creature, dt: number)
	c.hitCooldown = math.max(0, c.hitCooldown - dt)

	if c.state == "Grab" then
		local player = c.victim
		local root, humanoid = nil, nil
		if player then
			root, humanoid = getVictimParts(player)
		end
		if not player or not root or player.Character ~= c.victimChar then
			endGrab(c, false) -- la víctima murió, se fue o reapareció
			return
		end
		-- Lleva a la víctima en la boca mientras nada despacio hacia su destino.
		if (c.target - c.part.Position).Magnitude < 2 then
			pickPatrolTarget(c)
		end
		moveToward(c, c.target, c.tier.Speed * 0.5, dt)
		root.CFrame = c.part.CFrame * CFrame.new(0, 0, -c.tier.Size.Z / 2)
		c.grabLeft -= dt
		if c.grabLeft <= 0 then
			endGrab(c, true)
		end
		return
	end

	if c.state == "Chase" then
		local player = c.victim
		local root = if player then getVictimParts(player) else nil
		if not player or not root or not isTargetable(player, root)
			or (root.Position - c.part.Position).Magnitude > c.tier.Detect * 1.5 then
			c.victim = nil
			c.state = "Patrol"
			pickPatrolTarget(c)
			return
		end
		moveToward(c, root.Position, c.tier.Speed, dt)
		if (root.Position - c.part.Position).Magnitude <= c.tier.Reach then
			if c.tier.Behavior == "Bite" then
				local _, humanoid = getVictimParts(player)
				if humanoid and c.hitCooldown <= 0 and (bitIFrame[player] or 0) < os.clock() then
					humanoid:TakeDamage(humanoid.MaxHealth * c.tier.DamagePct)
					c.hitCooldown = c.tier.HitCooldown
					bitIFrame[player] = os.clock() + Config.BiteIFrames
					notify(player, "¡Mordisco! -25% de vida")
				end
			else
				startGrab(c, player, root)
			end
		end
		return
	end

	-- Patrol
	local found = findTarget(c)
	if found then
		c.victim = found
		c.state = "Chase"
		return
	end
	if (c.target - c.part.Position).Magnitude < 2 then
		pickPatrolTarget(c)
	end
	moveToward(c, c.target, c.tier.Speed * 0.6, dt)
end

local folder = Instance.new("Folder")
folder.Name = "Creatures"
folder.Parent = workspace

local function spawnCreature(tierName: string, tier: any)
	local part = Instance.new("Part")
	part.Name = "Creature_" .. tierName
	part.Size = tier.Size
	part.Color = tier.Color
	part.Material = Enum.Material.SmoothPlastic
	part.Anchored = true
	part.CanCollide = false
	part.Position = randomWaterPoint()
	part.Parent = folder
	local c: Creature = {
		part = part, tier = tier, state = "Patrol", target = part.Position, markerIndex = 0,
		victim = nil, victimChar = nil, grabLeft = 0, hitCooldown = 0,
	}
	pickPatrolTarget(c)
	table.insert(creatures, c)
end

for tierName, tier in Config.Creatures do
	for _ = 1, tier.Count do
		spawnCreature(tierName, tier)
	end
end

RunService.Heartbeat:Connect(function(dt)
	for _, c in creatures do
		step(c, dt)
	end
end)

Players.PlayerRemoving:Connect(function(player)
	local c = grabbedBy[player]
	if c then
		endGrab(c, false)
	end
	grabbedBy[player], immuneUntil[player], bitIFrame[player] = nil, nil, nil
end)
