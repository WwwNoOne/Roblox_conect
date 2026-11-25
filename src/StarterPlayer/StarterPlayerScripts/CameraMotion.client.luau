--!strict
-- Cámara en primera persona con cuerpo (parámetros: Config.Movement). Único dueño de Camera.FieldOfView y de Humanoid.CameraOffset.
--   * Balanceo de cabeza sincronizado con las pisadas (MotionState.stepCycle, lo marca FootstepAudio): la cabeza baja en cada
--     apoyo y se mece hacia la pierna de apoyo. Más amplio al correr, más contenido agachado.
--   * Inclinación al moverse de lado y al girar rápido (inercia de la cabeza).
--   * Aterrizaje: muelle que hunde la cámara según la fuerza de la caída.
--   * Respiración en reposo; se vuelve jadeo con la estamina baja.
--   * FOV: se abre con la velocidad real al correr y se cierra un poco agachado.
--   * Posición: a la altura de los ojos (Config.FirstPerson.EyeUp) y por delante de la cara (EyeForward). El modo primera persona
--     de Roblox deja la cámara en el centro de la cabeza, donde el cuello y los hombros tapan la vista. La altura sigue a la cabeza
--     suavizada (así una animación de agachado la baja sola); sin animación de agachado se baja CrouchCameraDrop.
-- Se aplica después del script de cámara de Roblox (que recalcula la cámara cada cuadro), así que no se acumula.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local MotionState = require(script.Parent:WaitForChild("MotionState"))
local M = Config.Movement
local FP = Config.FirstPerson
local CROUCH_DROP = if M.CrouchIdleAnim == "" then M.CrouchCameraDrop else 0 -- con animación, la cabeza ya baja sola

local player = Players.LocalPlayer

local function smooth(current: number, target: number, rate: number, dt: number): number
	return current + (target - current) * (1 - math.exp(-rate * dt))
end

-- Muelle amortiguado para el aterrizaje
local landPos, landVel = 0, 0
local LAND_K, LAND_DAMP = 140, 16
local lastLand = MotionState.landCount
local lastJump = MotionState.jumpCount

local bobAmp = 0
local strafeRoll = 0
local lookRoll = 0
local crouchBlend = 0
local fovNow = M.FieldOfView
local breathT = 0
local lastYaw: number? = nil
local eyeY: number? = nil -- altura suavizada del centro de la cabeza sobre la raíz
local eyeOwner: Instance? = nil

RunService:BindToRenderStep("CameraMotion", Enum.RenderPriority.Camera.Value + 1, function(dt)
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	dt = math.min(dt, 0.1)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local alive = humanoid ~= nil and root ~= nil and humanoid.Health > 0
	local hidden = player:GetAttribute("Hidden") == true

	-- ===== Aterrizaje y salto =====
	if MotionState.landCount ~= lastLand then
		lastLand = MotionState.landCount
		local strength = math.clamp((MotionState.landImpact - M.SoftLandSpeed) / (M.HardLandSpeed * 1.4 - M.SoftLandSpeed), 0.15, 1)
		landVel -= strength * M.LandDip * 14
	end
	if MotionState.jumpCount ~= lastJump then
		lastJump = MotionState.jumpCount
		landVel -= M.LandDip * 3 -- pequeño impulso al flexionar las piernas
	end
	local accel = -LAND_K * landPos - LAND_DAMP * landVel
	landVel += accel * dt
	landPos += landVel * dt

	-- ===== Balanceo de pasos =====
	local gait = MotionState.gait
	local gaitScale = (M.GaitBobScale :: any)[gait] or 0
	local speedRatio = math.clamp(MotionState.speed / math.max(MotionState.walkSpeed, 1), 0, 2.6)
	local targetAmp = if alive and MotionState.grounded and not hidden and gait ~= "Idle" then gaitScale * math.min(speedRatio, 1.2) else 0
	bobAmp = smooth(bobAmp, targetAmp, 8, dt)
	local c = MotionState.stepCycle * math.pi * 2
	local bobY = -M.BobVertical * bobAmp * (math.cos(c * 2) + 1) * 0.5
	local bobX = M.BobLateral * bobAmp * math.sin(c)
	local bobRoll = math.rad(M.BobRoll) * bobAmp * math.sin(c)
	local bobPitch = math.rad(M.BobPitch) * bobAmp * math.cos(c * 2)

	-- ===== Respiración =====
	local exertion = MotionState.exertion
	breathT += dt * (0.25 + exertion * 0.45) * math.pi * 2
	local breathAmp = M.BreathAmplitude + (M.BreathAmplitudeTired - M.BreathAmplitude) * exertion
	local breathY = math.sin(breathT) * breathAmp * (1 - math.min(bobAmp, 1) * 0.7)
	local breathPitch = math.sin(breathT) * math.rad(0.25) * exertion

	-- ===== Inclinaciones =====
	local targetStrafe = 0
	if alive and root then
		local localVel = root.CFrame:VectorToObjectSpace(root.AssemblyLinearVelocity)
		targetStrafe = -math.clamp(localVel.X / math.max(MotionState.walkSpeed, 1), -1.5, 1.5) * math.rad(M.StrafeRoll)
	end
	strafeRoll = smooth(strafeRoll, targetStrafe, 6, dt)

	local _, yaw, _ = camera.CFrame:ToEulerAnglesYXZ()
	local yawRate = 0
	if lastYaw then
		local d = yaw - lastYaw
		if d > math.pi then
			d -= math.pi * 2
		elseif d < -math.pi then
			d += math.pi * 2
		end
		yawRate = d / math.max(dt, 1e-3)
	end
	lastYaw = yaw
	local lookTarget = math.clamp(yawRate * 0.012, -1, 1) * math.rad(M.LookRoll)
	lookRoll = smooth(lookRoll, lookTarget, 7, dt)

	-- ===== Agachado =====
	crouchBlend = smooth(crouchBlend, if MotionState.crouching and alive then 1 else 0, 9, dt)
	if humanoid and humanoid.CameraOffset ~= FP.CameraOffset then
		humanoid.CameraOffset = FP.CameraOffset
	end

	-- ===== FOV =====
	local fovTarget = M.FieldOfView
	if alive then
		local overWalk = math.clamp((MotionState.speed - MotionState.walkSpeed) / math.max(M.SprintSpeed - MotionState.walkSpeed, 1), 0, 1)
		if MotionState.sprinting then
			fovTarget += M.SprintFovBonus * overWalk
		end
		fovTarget += M.CrouchFovBonus * crouchBlend
	end
	fovNow = smooth(fovNow, fovTarget, 5, dt)
	camera.FieldOfView = fovNow

	if not alive or hidden or not root or not humanoid then
		return
	end
	-- Solo con la cámara normal siguiendo a tu personaje (no en cinemáticas, espectador ni cámara libre)
	if camera.CameraType ~= Enum.CameraType.Custom or camera.CameraSubject ~= humanoid then
		return
	end
	local head = character and character:FindFirstChild("Head") :: BasePart?
	local rootPart = root :: BasePart
	if head then
		local measured = head.Position.Y - rootPart.Position.Y
		if eyeOwner ~= head or eyeY == nil then
			eyeOwner, eyeY = head, measured
		else
			eyeY = smooth(eyeY :: number, measured, 4, dt) -- filtra el vaivén de la animación de andar
		end
	end
	if eyeY == nil then
		return
	end
	local flatLook = rootPart.CFrame.LookVector * Vector3.new(1, 0, 1)
	flatLook = if flatLook.Magnitude > 1e-3 then flatLook.Unit else Vector3.new(0, 0, -1)
	local eye = rootPart.Position
		+ Vector3.new(0, (eyeY :: number) + FP.EyeUp - CROUCH_DROP * crouchBlend, 0)
		+ flatLook * (FP.EyeForward + (if CROUCH_DROP > 0 then 0.4 * crouchBlend else 0)) -- sin animación, fuera del pecho
	local y = bobY + breathY + landPos
	camera.CFrame = CFrame.new(eye) * camera.CFrame.Rotation
		* CFrame.new(bobX, y, 0)
		* CFrame.Angles(bobPitch + breathPitch + landPos * 0.06, 0, bobRoll + strafeRoll + lookRoll)
end)
