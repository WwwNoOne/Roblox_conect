--!strict
-- Movimiento en tierra realista y único dueño de Humanoid.WalkSpeed (parámetros: Config.Movement).
--   * Inercia: al arrancar se parte de una fracción de la velocidad y se acelera; al frenar se pierde velocidad deprisa.
--   * Andar hacia atrás o de lado es más lento; correr (Shift / L3 / botón táctil) solo hacia delante.
--   * Estamina del servidor (StaminaService): el cliente predice el sprint durante SprintGrace y luego obedece al atributo Sprinting,
--     así no se nota la latencia pero no se puede correr más de lo que el servidor permite. Agotado: se camina más lento y no se salta.
--   * Peso: cada objeto cargado (CarryCount) resta velocidad. Con poca vida se cojea un poco.
--   * Agacharse (C / B / botón táctil, alterna): más lento, sin saltar, cámara baja (CameraMotion) y los enemigos te oyen a menos
--     distancia (atributo Crouching del servidor). No te levantas si hay techo encima; Espacio también te levanta.
--   * Aterrizajes: mide la velocidad de caída; un golpe fuerte frena un momento y reproduce la animación de aterrizaje.
-- Publica todo en MotionState para la cámara, el sonido y el HUD, y el atributo local "Gait" en el personaje (lo lee Animate2).
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local MotionState = require(script.Parent:WaitForChild("MotionState"))
local M = Config.Movement
local SP = Config.Sprint
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local setSprint = remotes:WaitForChild("SetSprint") :: RemoteEvent
local setStance = remotes:WaitForChild("SetStance") :: RemoteEvent

local player = Players.LocalPlayer
MotionState.walkSpeed = M.WalkSpeed

-- ===== Estado =====
local character: Model? = nil
local humanoid: Humanoid? = nil
local root: BasePart? = nil
local crouchIdleTrack: AnimationTrack? = nil
local crouchWalkTrack: AnimationTrack? = nil
local landTrack: AnimationTrack? = nil

local sprintHeld = false
local crouching = false
local sentSprint = false
local wantSince = -math.huge -- desde cuándo se quiere correr (para la gracia de predicción)
local speedNow = 0
local airMinVy = 0
local wasGrounded = true
local slowStart, slowUntil = 0, 0

-- ===== Utilidades =====
local function setWantSprint(value: boolean)
	if value ~= sentSprint then
		sentSprint = value
		setSprint:FireServer(value)
	end
end

local function hasHeadroom(): boolean
	if not root or not character then
		return true
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }
	return workspace:Raycast(root.Position, Vector3.new(0, 1 + M.CrouchHeadroom, 0), params) == nil
end

local function setCrouch(value: boolean)
	if value == crouching then
		return
	end
	if not value and not hasHeadroom() then
		return -- hay techo: sigue agachado
	end
	if value and humanoid and humanoid.FloorMaterial == Enum.Material.Air then
		return -- no se agacha en el aire
	end
	crouching = value
	MotionState.crouching = value
	MotionState.stanceCount += 1
	setStance:FireServer(value)
	if root then
		root:SetAttribute("IsCrouching", value) -- compatibilidad con Turning / Animate2
	end
end

local function loadTrack(anim: string, priority: Enum.AnimationPriority, looped: boolean): AnimationTrack?
	if anim == "" or not humanoid then
		return nil
	end
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		return nil
	end
	local a = Instance.new("Animation")
	a.AnimationId = anim
	local ok, track = pcall(function()
		return (animator :: Animator):LoadAnimation(a)
	end)
	if not ok then
		warn("[MovementController] no se pudo cargar la animación", anim)
		return nil
	end
	track.Priority = priority
	track.Looped = looped
	return track
end

local function play(track: AnimationTrack?, speed: number)
	if track then
		if not track.IsPlaying then
			track:Play(0.2)
		end
		track:AdjustSpeed(speed)
	end
end

local function stop(track: AnimationTrack?)
	if track and track.IsPlaying then
		track:Stop(0.2)
	end
end

-- ===== Entrada =====
ContextActionService:BindAction("Sprint", function(_name, state)
	if state == Enum.UserInputState.Begin then
		sprintHeld = true
		if crouching then
			setCrouch(false) -- correr te levanta
		end
	elseif state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
		sprintHeld = false
	end
	return Enum.ContextActionResult.Pass
end, true, SP.Key, SP.PadKey)
ContextActionService:SetTitle("Sprint", "Correr")

ContextActionService:BindAction("Crouch", function(_name, state)
	if state == Enum.UserInputState.Begin then
		setCrouch(not crouching)
	end
	return Enum.ContextActionResult.Pass
end, true, M.CrouchKey, M.CrouchPadKey)
ContextActionService:SetTitle("Crouch", "Agachar")

UserInputService.JumpRequest:Connect(function()
	if crouching then
		setCrouch(false) -- Espacio agachado = levantarse
	end
end)

-- ===== Personaje =====
local function onCharacter(char: Model)
	character = char
	humanoid = char:WaitForChild("Humanoid", 10) :: Humanoid?
	root = char:WaitForChild("HumanoidRootPart", 10) :: BasePart?
	if not humanoid or not root then
		return
	end
	local h = humanoid :: Humanoid
	h:WaitForChild("Animator", 5)
	crouchIdleTrack = loadTrack(M.CrouchIdleAnim, Enum.AnimationPriority.Movement, true)
	crouchWalkTrack = loadTrack(M.CrouchWalkAnim, Enum.AnimationPriority.Movement, true)
	landTrack = loadTrack(M.LandAnim, Enum.AnimationPriority.Action, false)
	crouching = false
	MotionState.crouching = false
	setStance:FireServer(false)
	speedNow = 0
	wasGrounded = true
	airMinVy = 0
	slowUntil = 0
	h.WalkSpeed = M.WalkSpeed * M.StartSpeedFactor
	h.StateChanged:Connect(function(_old, new)
		if new == Enum.HumanoidStateType.Jumping then
			MotionState.jumpCount += 1
		elseif new == Enum.HumanoidStateType.Dead then
			stop(crouchIdleTrack)
			stop(crouchWalkTrack)
			crouching = false
			MotionState.crouching = false
		end
	end)
end
if player.Character then
	task.spawn(onCharacter, player.Character)
end
player.CharacterAdded:Connect(onCharacter)
player.CharacterRemoving:Connect(function()
	sprintHeld = false
	setWantSprint(false)
end)

-- ===== Bucle =====
local function approach(current: number, target: number, up: number, down: number, dt: number): number
	if current < target then
		return math.min(target, current + up * dt)
	end
	return math.max(target, current - down * dt)
end

RunService.Heartbeat:Connect(function(dt)
	local h, r = humanoid, root
	if not h or not r or not h.Parent or h.Health <= 0 then
		setWantSprint(false)
		MotionState.gait = "Idle"
		MotionState.sprinting = false
		return
	end
	local now = os.clock()
	local state = h:GetState()
	local grounded = h.FloorMaterial ~= Enum.Material.Air
	local vel = r.AssemblyLinearVelocity
	local flatSpeed = Vector3.new(vel.X, 0, vel.Z).Magnitude

	-- Aterrizajes
	if not grounded then
		airMinVy = math.min(airMinVy, vel.Y)
	elseif not wasGrounded then
		local impact = -airMinVy
		airMinVy = 0
		if impact >= M.SoftLandSpeed then
			MotionState.landImpact = impact
			MotionState.landCount += 1
			if impact >= M.HardLandSpeed then
				slowStart, slowUntil = now, now + M.HardLandSlowSeconds
				if landTrack then
					landTrack:Play(0.05)
					task.delay(0.8, function()
						stop(landTrack)
					end)
				end
			end
		end
	end
	wasGrounded = grounded

	-- Dirección relativa a la mirada
	local moveDir = h.MoveDirection
	local moving = moveDir.Magnitude > 0.05
	local localDir = r.CFrame:VectorToObjectSpace(moveDir)
	local forward = if moving then -localDir.Unit.Z else 0
	local dirFactor = if forward >= 0
		then M.StrafeFactor + (1 - M.StrafeFactor) * forward
		else M.StrafeFactor + (M.BackwardFactor - M.StrafeFactor) * -forward

	-- Sprint (predicción + autoridad del servidor)
	local inRun = player:GetAttribute("InRun") == true
	local exhausted = inRun and player:GetAttribute("Exhausted") == true
	local want = sprintHeld and moving and forward >= M.SprintMinForward and not crouching and grounded
		and state ~= Enum.HumanoidStateType.Swimming
	if want and wantSince == -math.huge then
		wantSince = now
	elseif not want then
		wantSince = -math.huge
	end
	setWantSprint(want)
	local sprinting: boolean
	if inRun then
		local confirmed = player:GetAttribute("Sprinting") == true
		sprinting = want and not exhausted and (confirmed or now - wantSince < M.SprintGrace)
	else
		sprinting = want and M.LobbySprint
	end

	-- Velocidad objetivo
	local target = if crouching then M.CrouchSpeed elseif sprinting then M.SprintSpeed else M.WalkSpeed
	target *= dirFactor
	local carry = player:GetAttribute("CarryCount")
	if type(carry) == "number" and carry > 0 then
		target *= math.max(0.5, 1 - carry * M.CarryPenaltyPerItem)
	end
	if exhausted then
		target *= M.ExhaustedFactor
	end
	if h.MaxHealth > 0 and h.Health / h.MaxHealth < M.LowHealthFraction then
		target *= M.LowHealthFactor
	end
	if now < slowUntil then
		local t = (now - slowStart) / math.max(slowUntil - slowStart, 0.01)
		target *= M.HardLandSlowFactor + (1 - M.HardLandSlowFactor) * t
	end

	if not moving then
		speedNow = target * M.StartSpeedFactor -- el próximo arranque parte de abajo
	else
		speedNow = approach(math.max(speedNow, target * M.StartSpeedFactor * 0.5), target, M.Accel, M.Decel, dt)
	end
	if state ~= Enum.HumanoidStateType.Swimming then
		h.WalkSpeed = math.max(speedNow, 0.1)
	end
	h:SetStateEnabled(Enum.HumanoidStateType.Jumping, not crouching and not exhausted)

	-- Animaciones de agachado
	if crouching then
		if moving and crouchWalkTrack then
			stop(crouchIdleTrack)
			play(crouchWalkTrack, math.max(flatSpeed / M.CrouchSpeed, 0.2))
		else
			stop(crouchWalkTrack)
			play(crouchIdleTrack, 1)
		end
	else
		stop(crouchIdleTrack)
		stop(crouchWalkTrack)
	end

	-- Publicar
	local gait: MotionState.Gait = if not moving or flatSpeed < 1
		then "Idle"
		elseif crouching then "Crouch"
		elseif sprinting then "Sprint"
		else "Walk"
	MotionState.gait = gait
	MotionState.sprinting = sprinting
	MotionState.grounded = grounded
	MotionState.speed = flatSpeed
	local st, stMax = player:GetAttribute("Stamina"), player:GetAttribute("StaminaMax")
	local exertion = if inRun and type(st) == "number" and type(stMax) == "number" and stMax > 0 then 1 - st / stMax else 0
	if exhausted then
		exertion = math.max(exertion, 0.9)
	end
	MotionState.exertion = math.clamp(exertion, 0, 1)
	if character and character:GetAttribute("Gait") ~= gait then
		character:SetAttribute("Gait", gait)
	end
end)
