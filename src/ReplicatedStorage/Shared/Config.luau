--!strict
-- Constantes compartidas (GDD: 6 minutos de oxígeno inicial).
-- Mejoras de la tienda (precios por nivel). Valores de prueba aprobados, no están en el GDD.
local Upgrades = table.freeze({
	Lamp = table.freeze({ Name = "Luz potente", Order = 2, Prices = { 150 }, RangeBonus = 30 }),
})

-- Aspecto del agua. Se usa Atmosphere (Lighting.Fog NO se aplica dentro de agua de Terrain).
-- Todos son valores de partida a ajustar jugando; Density/Haze no equivalen a studs exactos.
local Water = table.freeze({
	SurfaceDensity = 0.12, -- densidad justo bajo la superficie
	DeepDensity = 0.2, -- densidad a DeepDepth
	SurfaceHaze = 0.6,
	DeepHaze = 1.5,
	DeepDepth = 60, -- metros a los que se alcanza lo más oscuro/denso
	SurfaceColor = Color3.fromRGB(30, 140, 170),
	DeepColor = Color3.fromRGB(8, 28, 55),
	NightDarkness = 0.35, -- cuánto oscurece de noche el color del agua
	DarkenAtDepth = 0.05, -- oscurecimiento máximo de la imagen a DeepDepth
	LampDensityReduction = 0.05, -- cuánto baja la densidad con la lámpara encendida
	LampDensityPerLevel = 0.07, -- reducción extra por nivel de "Luz potente"
	MinDensity = 0.04,
	NightExposure = 0.9, -- sube la exposición bajo el agua de noche (Lighting.ExposureCompensation, solo local)
	DepthExposure = 0.25, -- exposición extra bajo el agua a cualquier hora
	BlurFarIntensity = 0.3, -- desenfoque de lo lejano bajo el agua (da profundidad sin oscurecer)
	BlurFocusDistance = 60,
	BlurInFocusRadius = 45,
	TransitionSpeed = 4, -- suavizado al cruzar la superficie
})

-- Partida (T03). TODOS son valores de prueba a calibrar en T08.
-- Etapas en orden: Nivel 1 -> Parada -> Nivel 2 -> Parada -> Nivel 3 (final). Map = carpeta en Workspace.Maps.
-- Kind "Level": se sale a explorar (compuerta abierta). Kind "Parada": nadie sale; se vende/repara/compra desde dentro.
-- Crab = true: el nivel tiene al cangrejo guardián.
-- Beacon = true: el nivel tiene la baliza (victoria al activarla).
-- Quota (opcional): valor de tesoros a depositar en ese nivel; el último nivel (baliza) no tiene cuota.
-- Depth en metros (HUD); PressureDps = daño/s al casco en esa etapa (en la parada es 0: refugio seguro).
local Run = table.freeze({
	HullMax = 100,
	StartMoney = 0,
	BeaconHoldSeconds = 5, -- mantener E para activar la baliza (ProximityPrompt.HoldDuration)
	EndScreenSeconds = 8, -- tiempo de la pantalla final antes de volver a la sala
	TravelSeconds = 20, -- duración del viaje entre etapas
	Stages = table.freeze({
		table.freeze({ Kind = "Level", Map = "Level_1", Depth = 200, PressureDps = 0.1, Quota = 100 }),
		table.freeze({ Kind = "Parada", Map = "Parada", Depth = 300, PressureDps = 0 }),
		table.freeze({ Kind = "Level", Map = "Level_2", Depth = 400, PressureDps = 0.5, Quota = 200, Crab = true }),
		table.freeze({ Kind = "Parada", Map = "Parada", Depth = 500, PressureDps = 0 }),
		table.freeze({ Kind = "Level", Map = "Level_3", Depth = 600, PressureDps = 1.2, Beacon = true, Crab = true }),
	}),
})

-- Economía de partida (T05). Valores de prueba a calibrar en T08.
-- Cangrejo guardián (T07). Valores de prueba: velocidades < nado del jugador (16) para poder huir.
-- Natación (cliente). Valores de prueba: Speed ligeramente mayor que la caminata (16) para que no se sienta lento.
local Swim = table.freeze({
	Speed = 20, -- WalkSpeed mientras se nada
	WalkSpeed = 16, -- WalkSpeed fuera del agua
	VerticalSpeed = 16, -- subir (Espacio) / bajar (Ctrl, C)
	VerticalAccel = 6, -- suavizado al subir/bajar (mayor = más brusco)
	Damping = 3, -- planeo al soltar los controles (mayor = frena antes)
	HoldGain = 20, -- fuerza con la que vuelve a su altura al quedarse quieto (anula la flotabilidad)
	HoldMaxSpeed = 8, -- velocidad vertical máxima de esa corrección
	LeanMax = 0.45, -- inclinación máxima del cuerpo en radianes (~26°); 0 = sin inclinación
	LeanSmoothing = 8, -- suavizado de la inclinación del cuerpo
	LeanMinSpeed = 6, -- velocidad a partir de la cual el cuerpo se inclina del todo
	StrokeSeconds = 1.6, -- separación entre sonidos de brazada al nadar
	StrokeVolume = 0.35,
	BubbleMinSeconds = 3,
	BubbleMaxSeconds = 6,
})

local Crab = table.freeze({
	Speed = 12, -- persecución (antes 10; el nado subió a 20)
	WanderSpeed = 4,
	ReturnSpeed = 12,
	DetectRange = 45, -- studs; con la lámpara encendida se multiplica
	LampDetectMultiplier = 1.5,
	AlertSeconds = 1.0, -- animación Sorprender antes de perseguir
	GrabReach = 6, -- distancia horizontal para atrapar
	CarrySpeed = 14,
	CarryMinSeconds = 3,
	CarryMaxSeconds = 8,
	TotalDamage = 20, -- daño total repartido durante el traslado
	Immunity = 6, -- segundos sin poder ser atrapado tras soltarte
	RetryDelay = 4, -- pausa del cangrejo tras soltar
})

local Economy = table.freeze({
	CarrySlots = 4, -- objetos que lleva cada jugador (1 por slot)
	Treasure = table.freeze({
		Small = table.freeze({ Value = 25, Size = Vector3.new(1, 1, 1), Color = Color3.fromRGB(240, 200, 80) }),
		Medium = table.freeze({ Value = 75, Size = Vector3.new(1.6, 1.6, 1.6), Color = Color3.fromRGB(120, 220, 240) }),
		Large = table.freeze({ Value = 200, Size = Vector3.new(2.4, 2.4, 2.4), Color = Color3.fromRGB(230, 90, 220) }),
	}),
	-- Cuota por nivel: se deposita en el submarino durante el nivel y se cobra al cerrarlo.
	Quota = table.freeze({
		BonusFraction = 0.5, -- cuota cumplida: pago = depositado + cuota * BonusFraction (extra para equipamiento)
		ShortfallFactor = 0.75, -- cuota fallida: pago = depositado * ShortfallFactor y suma un fallo
		MaxFailures = 2, -- al llegar a este número de fallos se pierde (GDD: subir a 3 con más niveles)
	}),
	RepairChunk = 10, -- HP por uso del panel de reparación
	RepairCostPerHp = 2,
	StationUseDistance = 14, -- studs máx. a la estación (validación de remotos)
	Shop = table.freeze({
		Armor = table.freeze({ Name = "Blindaje del casco", Prices = { 150, 300, 500 }, PressureFactorPerLevel = 0.2 }),
		Oxygen = table.freeze({ Name = "Tanque de oxígeno", Prices = { 80, 160, 240 }, SecondsPerLevel = 60 }),
	}),
})

-- Dash (DashClient): impulso hacia donde mira la cámara, solo nadando.
local Dash = table.freeze({
	Key = Enum.KeyCode.Q,
	Cooldown = 15, -- segundos
	Speed = 100, -- velocidad inicial (baja linealmente a 0); ~30 studs de recorrido
	Duration = 0.6,
})

-- Prefijos de nombre (sin distinguir mayúsculas) de los sonidos en Workspace.sonidos. Ver Shared/Sfx.
local Sfx = table.freeze({
	Dash = "dash",
	Bubbles = "Bubbles Small", -- burbujas de la boca (se elige una variante al azar)
	Stroke = "Movimiento", -- brazada al nadar (SwimClient)
})

-- Fauna ambiental pacífica (solo cliente, AmbientFauna.client). Las plantillas están en ReplicatedStorage.AmbientFauna
-- y las rutas de los gigantes en Workspace.Maps.<Nivel>.AmbientRoutes.<Ruta> (puntos P01, P02... en orden).
-- Los gigantes cruzan lejos y por debajo de la zona jugable (casi siluetas en la niebla); los peces nadan en cardúmenes cerca del jugador.
local Ambient = table.freeze({
	Giants = table.freeze({
		Level_1 = table.freeze({
			-- FirstDelay: segundos desde que el jugador entra al nivel; Interval: pausa entre pasadas.
			table.freeze({ Template = "Manta_Abisal", Route = "Manta", Branching = true, Speed = 24, FirstDelay = 25, Interval = 170 }),
			table.freeze({ Template = "Nautilo_Colosal", Route = "Nautilo", Speed = 13, FirstDelay = 210, Interval = 320 }),
		}),
	}),
	-- Ruta ramificada (Branching): M-1 y el último M-n siempre; cada M intermedio se conserva con probabilidad Keep;
	-- sale por una Exit_n al azar; todos los puntos (menos el inicio) se desplazan hasta Jitter studs. Así cada pasada cambia.
	Branch = table.freeze({ Keep = 0.65, Jitter = 35 }),
	Fish = table.freeze({
		Species = table.freeze({ "Pez_Farol_Rojo", "Pez_Aguja_Espectral", "Pez_Cuchilla", "Pez_Mariposa" }),
		MaxFish = 18, -- tope de peces vivos a la vez
		SchoolMin = 3,
		SchoolMax = 5,
		SpawnMin = 30, -- distancia al jugador a la que aparecen un cardumen
		SpawnMax = 95,
		DespawnDistance = 150,
		Speed = table.freeze({ 5, 9 }),
	}),
})

return table.freeze({
	Ambient = Ambient,
	Dash = Dash,
	Sfx = Sfx,
	BaseOxygenSeconds = 360,
	SeaLevelY = 0, -- Y (studs) de la superficie del agua
	HudUpdateInterval = 0.25, -- 4 Hz, muy por debajo del límite de 20 Hz

	MinPlayers = 1, -- pruebas; GDD: 2-4
	MaxPlayers = 4,
	RoomCodeLength = 4,

	DayLengthSeconds = 600, -- un día completo dura 10 min reales
	StartClockTime = 14, -- hora inicial (0-24)
	LampRange = 130, -- alcance del cono (antes 60)
	LampAngle = 60, -- grados del cono (antes 45)
	LampBrightness = 6, -- antes 3
	LampFillAngle = 120, -- luz de relleno corta y suave para iluminar el suelo cercano (ponla en 0 brillo para quitarla)
	LampFillRange = 14,
	LampFillBrightness = 1.6,
	TreasureGlowRange = 18, -- luz propia de cada tesoro para localizarlo en la oscuridad
	TreasureGlowBrightness = 2,
	LampOriginOffset = 0.4, -- studs por delante de la cabeza donde nace la luz (antes 1.2)
	LampToggleCooldown = 0.25,

	Run = Run,
	Economy = Economy,
	Crab = Crab,
	Swim = Swim,
	Upgrades = Upgrades,
	Water = Water,
})
