--!strict
-- Estado de movimiento del jugador local, compartido entre MovementController (lo escribe), FootstepAudio (escribe el ritmo de las
-- pisadas) y CameraMotion / SurvivalHud (lo leen). Todos los LocalScripts de PlayerScripts reciben la misma tabla al hacer require.

export type Gait = "Idle" | "Crouch" | "Walk" | "Sprint"

local MotionState = {
	gait = "Idle" :: Gait,
	crouching = false,
	sprinting = false, -- corriendo de verdad (predicho y confirmado)
	grounded = true,
	speed = 0, -- velocidad horizontal real (studs/s)
	walkSpeed = 12, -- velocidad de andar de referencia (para normalizar)
	exertion = 0, -- 0..1 esfuerzo (estamina gastada, agotamiento)
	stepCycle = 0, -- 0..1 ciclo de dos pisadas (FootstepAudio); pisadas en 0 y 0,5
	bobWeight = 0, -- 0..1 cuánto balanceo aplicar (sube al andar, baja al pararse)
	-- Aterrizaje: CameraMotion y FootstepAudio lo leen por el contador (cambia en cada aterrizaje).
	landCount = 0,
	landImpact = 0, -- velocidad vertical al tocar suelo (studs/s)
	jumpCount = 0,
	stanceCount = 0, -- cambia al agacharse/levantarse (sonido de ropa)
}

return MotionState
