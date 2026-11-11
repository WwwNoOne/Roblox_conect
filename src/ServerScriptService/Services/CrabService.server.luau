--!strict
-- Cangrejo guardián (T07): vigila su guarida, te atrapa y te lleva a la zona profunda haciendo poco daño.
-- Marcadores del mapa (ver creation_models.md): CrabLair, GuardZone, DeepZone, CrabDrop1..N, CrabPatrol1..N.
-- Sin marcadores usa respaldos: CreatureSpawn como guarida y el extremo más lejano de Bounds como zona profunda.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local KeyframeSequenceProvider = game:GetService("KeyframeSequenceProvider")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Types = require(Shared:WaitForChild("Types"))
local Runs = require(script.Parent:WaitForChild("Runs"))
local Assets = require(script.Parent:WaitForChild("Assets"))

local C = Config.Crab

type Crab = {
	code: string,
	model: Model,
	root: BasePart,
	state: string, -- Idle | Alert | Chase | Carry | Return | Wait
	timer: number,
	scan: number,
	target: Player?,
	lair: Vector3,
	drops: { Vector3 },
	guard: BasePart?,
	dock: Vector3?,
	patrol: { Vector3 },
	wanderTo: Vector3?,
	carryTo: Vector3?,
	carryDps: number,
	carrySpeed: number,
	tracks: { [string]: AnimationTrack? },
	grabOffset: Vector3,
}

local crab: Crab? = nil

local function posOf(inst: Instance?): Vector3?
	if inst and inst:IsA("BasePart") then
		return inst.Position
	elseif inst and inst:IsA("Attachment") then
		return inst.WorldPosition
	end
	return nil
end

local function inVolume(part: BasePart, pos: Vector3): boolean
	local rel = part.CFrame:PointToObjectSpace(pos)
	local h = part.Size / 2
	return math.abs(rel.X) <= h.X and math.abs(rel.Y) <= h.Y and math.abs(rel.Z) <= h.Z
end

local function playerRoot(player: Player): BasePart?
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if humanoid and humanoid.Health > 0 and root and root:IsA("BasePart") then
		return root
	end
	return nil
end

local function loadTrack(c: Crab, name: string): AnimationTrack?
	if c.tracks[name] ~= nil then
		return c.tracks[name]
	end
	local folder = c.model:FindFirstChild("Animaciones")
	local src = folder and folder:FindFirstChild(name)
	local controller = c.model:FindFirstChildOfClass("AnimationController")
	local animator = controller and controller:FindFirstChildOfClass("Animator")
	if not src or not animator then
		return nil
	end
	local animation: Animation? = nil
	if src:IsA("Animation") then
		animation = src
	elseif src:IsA("KeyframeSequence") then
		-- Solo en Studio; en el juego real las animaciones deben estar publicadas como Animation.
		local ok, id = pcall(function()
			return KeyframeSequenceProvider:RegisterKeyframeSequence(src)
		end)
		if ok and id then
			animation = Instance.new("Animation")
			animation.AnimationId = id
		end
	end
	local track: AnimationTrack? = nil
	if animation then
		local ok, loaded = pcall(function()
			return animator:LoadAnimation(animation :: Animation)
		end)
		if ok then
			track = loaded
		end
	end
	c.tracks[name] = track or false :: any
	return track
end

local function play(c: Crab, name: string, looped: boolean)
	local track = loadTrack(c, name)
	if track then
		track.Looped = looped
		if not track.IsPlaying then
			track:Play()
		end
	end
end

local function stopAll(c: Crab, except: string?)
	for name, track in c.tracks do
		if track and name ~= except and track.IsPlaying then
			track:Stop()
		end
	end
end

local function faceAndMove(c: Crab, to: Vector3, speed: number, dt: number, keepY: boolean?): boolean
	local from = c.model:GetPivot().Position
	local target = if keepY then Vector3.new(to.X, from.Y, to.Z) else to
	local delta = target - from
	local dist = delta.Magnitude
	if dist < 0.5 then
		return true
	end
	local step = math.min(dist, speed * dt)
	local newPos = from + delta.Unit * step
	local look = Vector3.new(delta.X, 0, delta.Z)
	local cf = if look.Magnitude > 0.01 then CFrame.lookAt(newPos, newPos + look) else CFrame.new(newPos)
	c.model:PivotTo(cf)
	return step >= dist - 1e-3
end

local function collectMarkers(map: Instance, c: { lair: Vector3?, drops: { Vector3 }, guard: BasePart?, patrol: { Vector3 }, dock: Vector3? })
	local dockPart = map:FindFirstChild("SubDock", true)
	c.dock = posOf(dockPart)
	c.lair = posOf(map:FindFirstChild("CrabLair", true)) or posOf(map:FindFirstChild("CreatureSpawn", true))
	local deep = map:FindFirstChild("DeepZone", true)
	local guard = map:FindFirstChild("GuardZone", true) or deep
	c.guard = if guard and guard:IsA("BasePart") then guard else nil
	for _, d in map:GetDescendants() do
		if d:IsA("Attachment") or d:IsA("BasePart") then
			if string.match(d.Name, "^CrabDrop%d*$") then
				local p = posOf(d)
				if p then
					table.insert(c.drops, p)
				end
			elseif string.match(d.Name, "^CrabPatrol%d*$") then
				local p = posOf(d)
				if p then
					table.insert(c.patrol, p)
				end
			end
		end
	end
	if #c.drops == 0 then
		-- Respaldo: esquina de Bounds más lejana al SubDock (en el plano horizontal).
		local bounds = map:FindFirstChild("Bounds")
		if bounds and bounds:IsA("BasePart") and c.dock then
			local best: Vector3? = nil
			local bestDist = -1
			for _, sx in { -1, 1 } do
				for _, sz in { -1, 1 } do
					local corner = (bounds.CFrame * CFrame.new(sx * (bounds.Size.X / 2 - 10), 0, sz * (bounds.Size.Z / 2 - 10))).Position
					local d = (Vector3.new(corner.X, 0, corner.Z) - Vector3.new(c.dock.X, 0, c.dock.Z)).Magnitude
					if d > bestDist then
						best, bestDist = corner, d
					end
				end
			end
			if best then
				table.insert(c.drops, best)
			end
		end
	end
end

local function destroyCrab()
	if crab then
		if crab.target then
			local root = playerRoot(crab.target)
			local humanoid = crab.target.Character and crab.target.Character:FindFirstChildOfClass("Humanoid")
			if humanoid then
				humanoid.PlatformStand = false
			end
			if root then
				pcall(function()
					root:SetNetworkOwner(crab.target)
				end)
			end
		end
		crab.model:Destroy()
		crab = nil
	end
end

local function spawnCrab(code: string, map: Instance)
	destroyCrab()
	local template = Assets.Find("Cangrejo")
	if not template or not template:IsA("Model") then
		warn("[Crab] Falta AbismoAssets.Creatures.Cangrejo")
		return
	end
	local m = { lair = nil :: Vector3?, drops = {} :: { Vector3 }, guard = nil :: BasePart?, patrol = {} :: { Vector3 }, dock = nil :: Vector3? }
	collectMarkers(map, m)
	if not m.lair then
		warn("[Crab] " .. map.Name .. " no tiene CrabLair ni CreatureSpawn")
		return
	end
	local model = template:Clone()
	local root = model.PrimaryPart or model:FindFirstChildWhichIsA("MeshPart")
	if not root then
		model:Destroy()
		return
	end
	model.PrimaryPart = root
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
		end
	end
	model:PivotTo(CFrame.new(m.lair))
	model.Name = "CangrejoGuardian"
	model.Parent = workspace
	local grab = model:FindFirstChild("GrabPoint", true)
	crab = {
		code = code,
		model = model,
		root = root,
		state = "Idle",
		timer = 0,
		scan = 0,
		target = nil,
		lair = m.lair,
		drops = m.drops,
		guard = m.guard,
		dock = m.dock,
		patrol = m.patrol,
		wanderTo = nil,
		carryTo = nil,
		carryDps = 0,
		carrySpeed = 0,
		tracks = {},
		-- GrabPoint (Attachment del modelo) o, si falta, delante de la boca del cangrejo.
		grabOffset = if grab and grab:IsA("Attachment") then root.CFrame:PointToObjectSpace(grab.WorldPosition) else Vector3.new(0, 0, -(root.Size.Z / 2 + 1)),
	}
end

local function eligible(player: Player, c: Crab): BasePart?
	local run = Runs.GetByUser(player.UserId)
	if not run or run.code ~= c.code or run.state ~= "Level" then
		return nil
	end
	if (player:GetAttribute("CrabImmuneUntil") or 0) > os.clock() then
		return nil
	end
	local root = playerRoot(player)
	if not root or Runs.IsUserInside(player.UserId) then
		return nil -- dentro del submarino están a salvo
	end
	if c.guard and not inVolume(c.guard, root.Position) then
		return nil
	end
	return root
end

local function release(c: Crab, dropPos: Vector3?)
	local target = c.target
	if target then
		local humanoid = target.Character and target.Character:FindFirstChildOfClass("Humanoid")
		local root = playerRoot(target)
		if humanoid then
			humanoid.PlatformStand = false
		end
		if root then
			if dropPos then
				root.CFrame = CFrame.new(dropPos)
			end
			root.AssemblyLinearVelocity = Vector3.zero
			pcall(function()
				root:SetNetworkOwner(target)
			end)
		end
		target:SetAttribute("CrabImmuneUntil", os.clock() + C.Immunity)
	end
	c.target = nil
	c.carryTo = nil
	stopAll(c, "Caminar")
	c.state = "Return"
end

local function step(c: Crab, dt: number)
	local pos = c.model:GetPivot().Position
	if c.state == "Idle" or c.state == "Wait" then
		c.timer -= dt
		if c.state == "Wait" and c.timer > 0 then
			return
		end
		c.state = "Idle"
		-- Vaga cerca de la guarida (o por la ruta de patrulla).
		if not c.wanderTo or (c.wanderTo - pos).Magnitude < 1 then
			if #c.patrol > 0 then
				c.wanderTo = c.patrol[math.random(1, #c.patrol)]
			else
				local a = math.random() * math.pi * 2
				c.wanderTo = c.lair + Vector3.new(math.cos(a), 0, math.sin(a)) * math.random(4, 14)
			end
		end
		play(c, "Caminar", true)
		faceAndMove(c, c.wanderTo :: Vector3, C.WanderSpeed, dt, true)
		c.scan -= dt
		if c.scan <= 0 then
			c.scan = 0.25
			local best: Player? = nil
			local bestDist = math.huge
			for _, player in Players:GetPlayers() do
				local root = eligible(player, c)
				if root then
					local range = C.DetectRange * (if player:GetAttribute("LampOn") then C.LampDetectMultiplier else 1)
					local d = (root.Position - pos).Magnitude
					if d <= range and d < bestDist then
						best, bestDist = player, d
					end
				end
			end
			if best then
				c.target = best
				c.state = "Alert"
				c.timer = C.AlertSeconds
				stopAll(c, nil)
				play(c, "Sorprender", false)
			end
		end
	elseif c.state == "Alert" then
		c.timer -= dt
		local root = c.target and eligible(c.target, c)
		if not root then
			c.target = nil
			c.state = "Return"
			return
		end
		local look = Vector3.new(root.Position.X - pos.X, 0, root.Position.Z - pos.Z)
		if look.Magnitude > 0.01 then
			c.model:PivotTo(CFrame.lookAt(pos, pos + look))
		end
		if c.timer <= 0 then
			c.state = "Chase"
			stopAll(c, nil)
			play(c, "Caminar", true)
		end
	elseif c.state == "Chase" then
		local root = c.target and eligible(c.target, c)
		if not root or (root.Position - pos).Magnitude > C.DetectRange * C.LampDetectMultiplier * 1.3 then
			c.target = nil
			c.state = "Return"
			return
		end
		local flat = Vector3.new(root.Position.X, pos.Y, root.Position.Z)
		faceAndMove(c, flat, C.Speed, dt, false)
		local horizontal = (Vector3.new(root.Position.X, 0, root.Position.Z) - Vector3.new(pos.X, 0, pos.Z)).Magnitude
		if horizontal <= C.GrabReach and math.abs(root.Position.Y - pos.Y) <= 10 then
			-- Atrapado: te lleva a la zona profunda.
			local drop = if #c.drops > 0 then c.drops[math.random(1, #c.drops)] else c.lair
			local distance = (drop - pos).Magnitude
			local seconds = math.clamp(distance / C.CarrySpeed, C.CarryMinSeconds, C.CarryMaxSeconds)
			c.carryTo = drop
			c.carryDps = C.TotalDamage / seconds
			c.carrySpeed = distance / seconds -- llega justo al cumplirse el tiempo (daño total constante)
			c.state = "Carry"
			local humanoid = c.target and c.target.Character and c.target.Character:FindFirstChildOfClass("Humanoid")
			if humanoid then
				humanoid.PlatformStand = true
			end
			pcall(function()
				root:SetNetworkOwner(nil)
			end)
			stopAll(c, nil)
			play(c, "Atrapar", false)
			play(c, "Caminar", true)
			c.timer = seconds
		end
	elseif c.state == "Carry" then
		local target = c.target
		local root = target and playerRoot(target)
		if not target or not root then
			release(c, nil) -- murió o se fue
			return
		end
		local arrived = faceAndMove(c, c.carryTo :: Vector3, c.carrySpeed, dt, false)
		local held = c.root.CFrame:PointToWorldSpace(c.grabOffset)
		root.CFrame = CFrame.new(held)
		root.AssemblyLinearVelocity = Vector3.zero
		local humanoid = target.Character and target.Character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid:TakeDamage(c.carryDps * dt)
		end
		c.timer -= dt
		if arrived or c.timer <= -2 then
			release(c, (c.carryTo :: Vector3) + Vector3.new(0, 2, 0))
		end
	elseif c.state == "Return" then
		local arrived = faceAndMove(c, c.lair, C.ReturnSpeed, dt, false)
		if arrived then
			c.state = "Wait"
			c.timer = C.RetryDelay
			c.wanderTo = nil
			stopAll(c, nil)
		end
	end
end

RunService.Heartbeat:Connect(function(dt)
	if crab then
		local run = Runs.Get(crab.code)
		if not run or run.ended then
			destroyCrab()
			return
		end
		step(crab, dt)
	end
end)

Runs.StateChanged:Connect(function(code: string, state: Types.RunState)
	local run = Runs.Get(code)
	if not run then
		return
	end
	if state == "Level" then
		local def = Config.Run.Stages[run.zone]
		if def and def.Crab then
			local maps = workspace:FindFirstChild("Maps")
			local map = maps and maps:FindFirstChild(def.Map)
			if map then
				spawnCrab(code, map)
			end
		else
			destroyCrab()
		end
	elseif state == "Descending" or state == "Stopover" or state == "Won" or state == "Lost" then
		destroyCrab()
	end
end)
