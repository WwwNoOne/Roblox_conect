--!strict
-- Constantes compartidas (GDD: 6 minutos de oxígeno inicial).
-- Mejoras de la tienda (precios por nivel). Valores de prueba aprobados, no están en el GDD.
local Upgrades = table.freeze({
	Lamp = table.freeze({
		Name = "Luz potente",
		Order = 2,
		Prices = { 150 },
		-- Por nivel. No sube el alcance: SpotLight.Range tiene tope real de 120, así que sería invisible.
		BrightnessBonus = 1.5, -- sumado a LampBrightness
		AngleBonus = 5, -- grados sumados al cono
		HotspotScaleBonus = 0.2, -- fracción extra del radio del círculo
		HotspotBrightnessBonus = 0.5, -- sumado a LampHotspotBrightness
	}),
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
-- Kraken = true: el nivel tiene al kraken enemigo (KrakenService).
-- Beacon = true: el nivel tiene la baliza (victoria al activarla).
-- Quota (opcional): valor de tesoros a depositar en ese nivel; el último nivel (baliza) no tiene cuota.
-- Depth en metros (HUD); PressureDps ya no se aplica (el casco pierde Run.DescentDamage al llegar a cada etapa).
local Run = table.freeze({
	HullMax = 100,
	StartMoney = 0,
	BeaconHoldSeconds = 5, -- mantener E para activar la baliza (ProximityPrompt.HoldDuration)
	EndScreenSeconds = 8, -- tiempo de la pantalla final antes de volver a la sala
	TravelSeconds = 20, -- duración del viaje entre etapas
	-- El casco ya no se desgasta con el tiempo: pierde DescentDamage HP al llegar a cada etapa (se reduce con el blindaje).
	DescentDamage = 20,
	-- Al pulsar Avanzar con más de un jugador vivo, los demás tienen este tiempo para entrar; con todos dentro se parte antes.
	AdvanceCountdown = 60,
	-- Clock (opcional): el reloj del nivel va de Start a End (horas) en Seconds y se queda en End (19 h = atardecer).
	-- Sin Clock el ciclo día/noche corre libre (Config.DayLengthSeconds).
	Stages = table.freeze({
		table.freeze({ Kind = "Level", Map = "Level_1", Depth = 200, PressureDps = 0.1, Quota = 400, Clock = table.freeze({ Start = 14, End = 19, Seconds = 480 }) }),
		table.freeze({ Kind = "Parada", Map = "Parada", Depth = 300, PressureDps = 0 }),
		table.freeze({ Kind = "Level", Map = "Level_2", Depth = 400, PressureDps = 0.5, Quota = 200, Kraken = true, Clock = table.freeze({ Start = 19.3, End = 19.3, Seconds = 1 }) }),
		table.freeze({ Kind = "Parada", Map = "Parada", Depth = 500, PressureDps = 0 }),
		table.freeze({ Kind = "Level", Map = "Level_3", Depth = 600, PressureDps = 1.2, Beacon = true }),
	}),
})

-- Economía de partida (T05). Valores de prueba a calibrar en T08.
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

-- Kraken abisal (KrakenService): enemigo que ronda libre por el nivel; persigue a quien vea fuera del submarino, lo agarra con un tentáculo y lo mata.
-- Plantilla: AbismoAssets.Creatures.Kraken_Abisal (eje Y del modelo = cuerpo, manto arriba; avanza con los tentáculos por delante).
-- Los jugadores nadan a 20: la persecución es más lenta para poder esquivarlo (y el dash lo deja atrás).
local Kraken = table.freeze({
	Length = 42, -- alto del modelo en studs (el original mide ~100; 0 = tamaño original). Escala 0,6 de los 70 anteriores
	RoamSpeed = 9, -- studs/s patrullando
	ChaseSpeed = 16, -- persiguiendo
	RecoverSpeed = 12, -- alejándose tras golpear
	TurnRate = 0.9, -- giro suave (mayor = gira más rápido); es una criatura enorme
	DetectRange = 160, -- studs; con la lámpara encendida se multiplica
	LampDetectMultiplier = 1.3,
	LoseRangeMultiplier = 1.5, -- pierde al objetivo más allá de DetectRange * esto
	GrabReach = 9, -- distancia de la punta (o mitad final) de un tentáculo a la que agarra al jugador
	GrabSeconds = 2.5, -- tiempo que sostiene al jugador antes de matarlo (se queda quieto mientras tanto)
	-- Postura (solo visual; se mueve por donde nada): casi siempre erguido con los tentáculos colgando hacia abajo, y de vez en
	-- cuando horizontal. Nunca con los tentáculos hacia arriba. Inclinación = 0 erguido, 90 horizontal.
	UprightLeanDeg = 12, -- inclinación hacia delante al patrullar erguido
	ChaseLeanDeg = 40, -- al perseguir se inclina más hacia su presa
	HorizontalDeg = 80, -- inclinación en la postura horizontal
	HorizontalChance = 0.25, -- probabilidad de que la siguiente postura al patrullar sea horizontal
	PoseMin = 12, -- segundos que dura cada postura
	PoseMax = 30,
	TiltSmoothing = 0.7, -- suavizado del cambio de postura (mayor = más rápido)
	RecoverSeconds = 5, -- se aleja de su presa tras un golpe antes de volver a patrullar
	ProbeRadius = 15, -- radio de cada esfera de colisión del cuerpo (hay 3 a lo largo del eje: manto, centro y tentáculos)
	ProbeSpread = 0.35, -- separación de las esferas laterales respecto al centro, como fracción de Length
	ProbeDistance = 36,
	ReachDistance = 24, -- distancia para dar un punto de patrulla por alcanzado
	StuckSeconds = 10, -- sin acercarse al punto este tiempo = elige otro
	RoamMargin = 40, -- los puntos de patrulla quedan al menos a esto del borde de Bounds
	FirstDelay = 40, -- segundos desde el inicio del nivel hasta que aparece en Spawn_leviatan
	-- Animación (cliente, KrakenClient): ondulación de tentáculos, aletas y barbillas con huesos (Bone.Transform).
	Anim = table.freeze({
		TentacleDeg = 7, -- giro por hueso de tentáculo (la curva total suma los 8)
		TentacleTip = 1.6, -- la punta se mueve hasta este tanto más que la base
		TentaclePhase = 0.7, -- desfase entre huesos (rad)
		FinDeg = 10,
		FinPhase = 0.6,
		BeardDeg = 12,
		BaseHz = 0.35,
		HzPerSpeed = 0.03, -- se suma por cada stud/s de velocidad
		MaxHz = 1.2,
		Smoothing = 3,
		MaxDistance = 1500, -- más lejos que esto de la cámara no se anima
	}),
	Debug = true, -- imprime los cambios de estado y pone atributos de depuración en el modelo
})

-- Laberinto (MazeGenerator, Level.Mode = "maze"): piezas de pasillo en Workspace.Pasillo.Pasillos (cada una con Conexiones y Escondites).
local Maze = table.freeze({
	Count = 28, -- piezas por nivel (sin contar el marco del pozo)
	MaxLinearRun = 2, -- tramos rectos seguidos (pasillo lineal o pozo recto): el recto y 1 más
	MaxVertical = 5, -- pozos verticales por nivel (incluida la pieza bajo la sala_0)
	MaxRooms = 3, -- salas por nivel
	-- Piezas: Name = Model dentro de Workspace.Pasillo (Pasillos, Pasillos_V) o Workspace.Salas (salas agrupadas por bioma: Salas/Bioma(frabrica)); Kind agrupa las reglas
	-- ("linear"/"shaft" = rectos, "room" = sala); Weight = probabilidad relativa al elegir.
	Pieces = table.freeze({
		table.freeze({ Name = "Pasillo_Lineal", Kind = "linear", Weight = 3 }),
		table.freeze({ Name = "Pasillo_L", Kind = "elbow", Weight = 3 }),
		table.freeze({ Name = "Pasillo_T", Kind = "tee", Weight = 2 }),
		table.freeze({ Name = "Pasillo_Cruz_4", Kind = "cross", Weight = 1 }),
		table.freeze({ Name = "Pozo_Recto_48", Kind = "shaft", Weight = 1 }),
		table.freeze({ Name = "Pozo_L", Kind = "shaftL", Weight = 1 }),
		table.freeze({ Name = "Pozo_T", Kind = "shaftT", Weight = 1 }),
		table.freeze({ Name = "Pozo_Cruz_4", Kind = "shaftCross", Weight = 1 }),
		table.freeze({ Name = "Sala_01_70x70x70", Kind = "room", Weight = 1 }),
		table.freeze({ Name = "Sala_02_84x72x132", Kind = "room", Weight = 1 }),
		table.freeze({ Name = "Sala_03_110x76x90", Kind = "room", Weight = 1 }),
		table.freeze({ Name = "Sala_04_92x128x76", Kind = "room", Weight = 1 }),
		table.freeze({ Name = "Sala_05_74x170x106", Kind = "room", Weight = 1 }),
		table.freeze({ Name = "Sala_06_132x96x148", Kind = "room", Weight = 1 }),
		table.freeze({ Name = "Sala_07_156x110x82", Kind = "room", Weight = 1 }),
		table.freeze({ Name = "Sala_08_104x145x174", Kind = "room", Weight = 1 }),
		table.freeze({ Name = "Sala_09_176x90x200", Kind = "room", Weight = 1 }),
		table.freeze({ Name = "Sala_10_200x200x158", Kind = "room", Weight = 1 }),
	}),
	Inner = 16, -- sección interior libre del pasillo
	Outer = 20, -- sección exterior (con paredes)
	-- Pit (opcional): lado de un pozo más ancho que el pasillo; la sala_0 actual tiene un agujero de 16 × 16 y no lo necesita
	-- Caja de la sala_0 respecto a su SubDock (por encima del suelo del pozo): las piezas no pueden entrar
	Sala0BoxCenter = Vector3.new(5.4, 18.2, 48.9),
	Sala0BoxHalf = Vector3.new(41, 18.2, 55),
})

-- Enemigos agresivos del laberinto (MonsterService). Patrullan por la red de pasillos; al detectarte te persiguen (anticipándose a tu
-- movimiento), te encaran (Windup), se lanzan (Lunge, daña a quien toque su cuerpo) y se recuperan (Recover). Si te pierden rastrean
-- la zona (Search) y avisan a los demás. Los valores de abajo son los de partida; cada especie sobrescribe los suyos.
-- Los jugadores nadan a 20 (dash más): ChaseSpeed ~24-28 los alcanza en recto, pero el zarpazo se esquiva girando o escondiéndose.
local Monster = table.freeze({
	Length = 24, -- largo del modelo en studs (cabe en pasillos de 16 de ancho)
	BodyRadius = 3, -- radio de la esfera de colisión contra paredes (pasillo interior 16)
	WaypointRadius = 3, -- distancia a la que da por alcanzado un punto del camino
	PatrolSpeed = 10, -- studs/s patrullando
	ChaseSpeed = 24, -- persiguiendo
	Accel = 30, -- studs/s² al acelerar
	Brake = 45, -- studs/s² al frenar
	TurnRate = 7, -- giro suave (mayor = gira más rápido)
	-- Detección
	SightRange = 80, -- vista con línea de visión (la lámpara encendida lo multiplica)
	LampSightMultiplier = 1.5,
	HearRange = 14, -- te oye a esta distancia aunque no te vea (no si estás escondido)
	NoiseSpeed = 26, -- si vas más rápido que esto (dash) haces ruido...
	NoiseRange = 40, -- ...y te oye desde esta distancia
	HiddenRange = 5, -- escondido solo te encuentra si está muy cerca
	LoseSeconds = 4, -- tras perderte de vista sigue persiguiendo tu rastro este tiempo antes de rastrear
	SearchSeconds = 10, -- rastrea la zona del último punto visto este tiempo antes de volver a patrullar
	LingerRadius = 45, -- radio de esa zona
	AlertRadius = 160, -- avisa de dónde te vio a los demás enemigos a esta distancia
	LeadSeconds = 0.45, -- anticipación máxima sobre tu velocidad
	-- Ataque (zarpazo en tres fases)
	AttackStart = 16, -- empieza el zarpazo cuando tu distancia a su cabeza baja de esto (y te ve)
	WindupSeconds = 0.35, -- te encara y se frena: tu aviso para esquivar
	LungeSpeed = 48, -- velocidad de la embestida
	LungeSeconds = 0.4, -- duración máxima de la embestida
	HitRadius = 7, -- distancia de su cuerpo (cola-cabeza) a tu centro a la que te daña durante la embestida
	AttackDamage = 50, -- daño por golpe
	RecoverSeconds = 0.9, -- queda lento tras la embestida
	AttackCooldown = 1.2, -- mínimo entre zarpazos
	HitGap = 0.8, -- un jugador no recibe daño de enemigos más seguido que esto
	StuckSeconds = 1.5, -- sin avanzar este tiempo = recalcula el camino
	FirstDelay = 15, -- segundos desde el inicio del nivel hasta que aparece
	MinSpawnDistance = 90, -- aparece al menos a esta distancia del pozo de la sala_0
	Debug = true,
	-- Cuántos enemigos salen por nivel (especies distintas al azar, según Weight) y con qué separación entre apariciones.
	PerLevel = 2,
	SpawnStagger = 25, -- segundos entre la aparición de un enemigo y el siguiente
	-- Especies (generadas con ForgeGUI: un solo MeshPart, cabeza hacia -Z). Llevan ProcAnim = perfil de CreatureAnim: el cliente las
	-- anima cortadas en trozos (CreatureAnimator). Plantillas en ServerStorage.AbismoAssets.Creatures (o Workspace.Creatures).
	Species = table.freeze({
		table.freeze({ Name = "Anguila", TemplateName = "Anguila_Abisal", ProcAnim = "Anguila", Weight = 1,
			Length = 30, PatrolSpeed = 12, ChaseSpeed = 26, TurnRate = 8, AttackDamage = 40, AttackStart = 18, LungeSpeed = 52,
			HeadOffset = 13, Roar = "Abismo_Anguila" }),
		table.freeze({ Name = "Rape", TemplateName = "Rape_Abisal", ProcAnim = "Rape", Weight = 1,
			Length = 20, PatrolSpeed = 7, ChaseSpeed = 22, TurnRate = 5, SightRange = 110, HearRange = 10, AttackDamage = 60,
			AttackStart = 14, WindupSeconds = 0.5, LungeSpeed = 44, HeadOffset = 8, Roar = "Abismo_Rape" }),
		table.freeze({ Name = "Medusa", TemplateName = "Medusa_Abisal", ProcAnim = "Medusa", Weight = 0.8,
			Length = 22, PatrolSpeed = 5, ChaseSpeed = 15, TurnRate = 3, SightRange = 50, HearRange = 18, AttackStart = 14,
			WindupSeconds = 0.4, LungeSpeed = 30, AttackDamage = 35, AttackCooldown = 1.0, HitRadius = 9, HeadOffset = 0,
			Upright = true, Roar = "Abismo_Medusa" }),
		table.freeze({ Name = "Isopodo", TemplateName = "Isopodo_Gigante", ProcAnim = "Isopodo", Weight = 1,
			Length = 16, PatrolSpeed = 9, ChaseSpeed = 23, TurnRate = 8, Accel = 40, SightRange = 60, HearRange = 22,
			AttackDamage = 45, AttackStart = 12, WindupSeconds = 0.25, LungeSpeed = 46, LungeSeconds = 0.35, HeadOffset = 7,
			Roar = "Abismo_Isopodo" }),
		table.freeze({ Name = "Tiburon", TemplateName = "Tiburon_Duende", ProcAnim = "Tiburon", Weight = 1,
			Length = 26, PatrolSpeed = 13, ChaseSpeed = 28, TurnRate = 6, AttackDamage = 55, AttackStart = 18, LungeSpeed = 56,
			AttackCooldown = 1.6, HeadOffset = 11, Roar = "Abismo_Tiburon" }),
	}),
})

-- Perfiles de animación procedural (CreatureAnimator.client). Axis/HeadSign: eje largo de la malla y lado de la cabeza;
-- Amplitude: fracción del largo; Frequency: ciclos/s en reposo (sube al correr); Wavelength: ondas a lo largo del cuerpo;
-- Power: cuánto se concentra hacia la cola; Rigid: fracción del cuerpo desde la cabeza que no se dobla.
local CreatureAnim = table.freeze({
	Anguila = table.freeze({ Axis = "Z", HeadSign = -1, Segments = 6, Mode = "swim", Amplitude = 0.07, Frequency = 0.7, Wavelength = 1.1, Power = 1.2, Rigid = 0.12 }),
	Rape = table.freeze({ Axis = "Z", HeadSign = -1, Segments = 5, Mode = "swim", Amplitude = 0.06, Frequency = 0.6, Wavelength = 0.6, Power = 2.2, Rigid = 0.4 }),
	Medusa = table.freeze({ Axis = "Y", HeadSign = 1, Segments = 7, Mode = "jelly", Amplitude = 0.05, Frequency = 0.35, Wavelength = 0.7, Power = 1.5, Rigid = 0.3 }),
	Isopodo = table.freeze({ Axis = "Z", HeadSign = -1, Segments = 7, Mode = "crawl", Amplitude = 0.012, Frequency = 1.4, Wavelength = 1.5, Power = 1, Rigid = 0 }),
	Tiburon = table.freeze({ Axis = "Z", HeadSign = -1, Segments = 7, Mode = "swim", Amplitude = 0.05, Frequency = 0.8, Wavelength = 0.8, Power = 2, Rigid = 0.3 }),
})


-- Esconderse (Hiding + HidingHandlers): cada volumen `Escondite` del laberinto (la caja industrial de cada pieza) lleva un
-- ProximityPrompt. Pulsar E te mete en la caja (quedas quieto e invisible, atributo de jugador Hidden = true) y otra vez E sales
-- por donde entraste. Los enemigos ignoran a quien está escondido. El oxígeno sigue bajando mientras tanto.
local Hiding = table.freeze({
	HoldSeconds = 0.4, -- tiempo que hay que mantener E
	Distance = 7, -- distancia máxima al centro de la caja para ver el aviso
	PromptText = "Esconderse / Salir",
	ObjectText = "Caja industrial",
	Cooldown = 0.6, -- segundos entre usos del mismo jugador (evita rebotes)
})

-- Generación del mundo (LevelService + RoomGenerator, ver game_designs/Generacion_Cuevas.md).
-- Las plantillas están en Workspace (Salas_grandes, Salas_normales, Pasillo) y LevelService las mueve a ServerStorage al arrancar.
local Level = table.freeze({
	Mode = "maze", -- "maze" = laberinto de pasillos (MazeGenerator); "rooms" = salas grandes unidas por pasillos largos (RoomGenerator, versión anterior)
	Seed = nil :: number?, -- nil = aleatoria en cada servidor (se publica en el atributo de Workspace LevelSeed)
	Smalls = 10, -- salas pequeñas además de la grande
	Scale = 0.6, -- escala con la que se instancian salas y pasillo (las plantillas no se tocan); 1 = tamaño modelado
	Corridor = 140, -- largo del pasillo modelado (de puerta a puerta), antes de aplicar Scale
	BigDoors = 3, -- las primeras salas pequeñas se pegan a la grande
	VerticalMax = 2, -- pasillos verticales extra (además del de la sala_0)
	BigName = "Kraken_map", -- plantilla de la sala grande
	-- Carpetas de Workspace que se apartan a ServerStorage.Plantillas al arrancar (assets de pruebas, suelo de pruebas...) para que no
	-- estorben ni se carguen en la partida.
	Stash = { "Assets", "Zona_Prueba", "LeadPipes" },
	-- Sala_0 (relativo a su SubDock): puerto del pozo y caja aproximada
	-- medido con rayos (2026-11-18): agujero de ~17 × 16 en el suelo (Y = 14), centro (563,5, 36,9); el puerto queda en la cara inferior del suelo
	Sala0Port = Vector3.new(2.5, -9, 72.9),
	Sala0Half = Vector3.new(47, 28, 104),
	-- Grosor de pared y volumen de agua interior de cada tipo de sala
	BigWall = 8,
	BigWater = Vector3.new(270, 272, 264),
	SmallWall = 7,
	SmallWater = Vector3.new(160, 160, 160),
})

local Economy = table.freeze({
	CarrySlots = 4, -- objetos que lleva cada jugador (1 por slot)
	-- Tipos de tesoro. Models: modelos del Museum Treasures Pack (ServerStorage.AbismoAssets.Treasures.Museum); si no se
	-- encuentra ninguno se usa Treasure_<Tipo> y, por último, una pieza provisional. Scale: tamaño sobre el modelo original (miden 1-2 studs).
	Treasure = table.freeze({
		Small = table.freeze({
			Value = 25, Size = Vector3.new(1, 1, 1), Color = Color3.fromRGB(240, 200, 80), Scale = 2.4,
			Models = table.freeze({ "sh_tresors_Seashell", "sh_tresors_Amber", "sh_tresors_Ammonite", "sh_tresors_Anchor", "sh_tresors_Compass", "sh_tresors_Spyglass", "sh_tresors_Vase", "sh_tresors_Meteorite", "sh_tresors_MoonRock", "sh_tresors_Painting", "sh_tresors_Palette", "sh_tresors_Shield", "sh_tresors_Satellite", "sh_tresors_Rocket", "sh_tresors_Seahorse", "sh_coffre_Coffre_Bronze" }),
		}),
		Medium = table.freeze({
			Value = 75, Size = Vector3.new(1.6, 1.6, 1.6), Color = Color3.fromRGB(120, 220, 240), Scale = 2.6,
			Models = table.freeze({ "sh_tresors_JadeSerpent", "sh_tresors_JewelBox", "sh_tresors_Scarab", "sh_tresors_Ankh", "sh_tresors_CatIdol", "sh_tresors_Goblet", "sh_tresors_RaptorClaw", "sh_tresors_DinoEgg", "sh_tresors_FrostCrystal", "sh_tresors_SnowflakeGem", "sh_tresors_Trident", "sh_tresors_KnightSword", "sh_tresors_Orb", "sh_tresors_RingedPlanet", "sh_coffre_Coffre_Argent" }),
		}),
		Large = table.freeze({
			Value = 200, Size = Vector3.new(2.4, 2.4, 2.4), Color = Color3.fromRGB(230, 90, 220), Scale = 2.8,
			Models = table.freeze({ "sh_tresors_GoldenClock", "sh_tresors_GoldenDino", "sh_tresors_GoldenHelm", "sh_tresors_GoldenPyramid", "sh_tresors_Crown", "sh_tresors_Scepter", "sh_tresors_JewelEgg", "sh_tresors_SunDisc", "sh_tresors_DoubloonChest", "sh_coffre_Coffre_Or" }),
		}),
		-- Premio gordo: como mucho uno por nivel (Balance.EpicChance).
		Epic = table.freeze({
			Value = 500, Size = Vector3.new(3, 3, 3), Color = Color3.fromRGB(150, 255, 210), Scale = 1.8,
			Models = table.freeze({ "sh_finale_Diamond" }),
		}),
	}),
	-- Reparto de tesoros por nivel (EconomyHandlers.spawnTreasure). Cada TreasureZone (parte plana oculta) ofrece huecos
	-- (1 por ZoneAreaPerSlot studs²) y cada TreasureSpawn suelto es un hueco. Se llenan los necesarios para que el valor total
	-- sea siempre >= cuota * margen (y no mucho más), con tipos al azar, y las posiciones cambian en cada partida.
	Balance = table.freeze({
		Margin = 1.4, -- el valor repartido es la cuota x esto: la cuota y "un poco más" para cubrir pérdidas y comprar equipo
		PerUpgradeLevel = 0.05, -- +margen por cada nivel de mejora comprado (equipo más fuerte recoge más; el extra paga más mejoras)
		PerExtraPlayer = 0.08, -- +margen por jugador adicional a 1 (más manos, más tesoros)
		MaxMargin = 2.0,
		MaxOver = 1.6, -- el total repartido no pasa de cuota x margen x esto (evita niveles regalados)
		FillFraction = 0.35, -- fracción de huecos que se llenan (antes de ajustar al valor objetivo)
		MinCount = 10, -- mínimo de tesoros por nivel (si hay huecos)
		ZoneAreaPerSlot = 180, -- studs² de zona por hueco
		EpicChance = 0.3, -- probabilidad de que un nivel incluya el premio gordo
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
	-- Submarino (Workspace.sonidos.Efectos_submarino). Prefijos completos para no mezclar p. ej. Avanzar_1 con Avanzar_nivel_...
	SubEnter = "entrar", -- un jugador entra por la compuerta
	SubExit = "Salir", -- un jugador sale por la compuerta
	SubStart = "Iniciar_partida", -- todos a bordo: parte hacia el primer nivel
	SubAdvance = table.freeze({ "Avanzar_1", "Avanzar_2" }), -- viaje entre nivel y Parada (al azar)
	SubAdvanceDamaged = "Avanzar_nivel_submarino_muy_danado", -- ese viaje con el casco por debajo de DamagedHullFraction
	SubImplode = "submarino_implosiona",
	SubDefeatAlarm = "Alarm_cuando_pierden", -- derrota por implosión (junto con SubImplode)
	SubDefeatShort = "Alarma_perdieron", -- cualquier otra derrota
	SubLowHullSiren = "Submarine Alarm Casualty", -- una vez al bajar de LowHullFraction
	SubArrive = "Cuando_llega_al_siguiente_nivel", -- el submarino llega a un nivel o a la Parada
	PanelClick = "Abismo_Panel_Click", -- botón del panel del submarino (ForgeGUI)
	-- Ambiente de las salas de la instalación (ForgeGUI); los usa RoomAmbience.client.
	FacilityAmbience = "Abismo_Ambiente_Instalacion",
	PipeGroan = "Abismo_Tuberia_Gemido",
	-- Sin conectar todavía: adicional_1.
})

-- Audio de partida: música por contexto (Workspace.sonidos.Musica_background, por nombre) y mezcla de los efectos del submarino.
local Audio = table.freeze({
	Music = table.freeze({
		Lobby = "Lobby", -- fuera de partida
		Levels = table.freeze({
			Level_1 = "Nivel(1)",
			Level_2 = "Nivel(2)",
			Level_3 = "Pendiente(2)",
		}),
		Volume = 0.35,
		FadeSeconds = 2.5, -- cruce entre pistas; en la Parada y los viajes la música se desvanece
	}),
	SubVolume = 0.6,
	SubRollOff = 160, -- studs: los efectos del submarino se oyen dentro y cerca, no en todo el mapa
	DamagedHullFraction = 0.3, -- casco <= 30 % usa Avanzar_nivel_submarino_muy_danado
	LowHullFraction = 0.25, -- casco <= 25 % dispara la sirena
})

-- Fauna ambiental pacífica (solo cliente, AmbientFauna.client). Las plantillas están en ReplicatedStorage.AmbientFauna
-- y las rutas de los gigantes en Workspace.Maps.<Nivel>.AmbientRoutes.<Ruta> (puntos P01, P02... en orden).
-- Los gigantes cruzan lejos y por debajo de la zona jugable (casi siluetas en la niebla); los peces nadan en cardúmenes cerca del jugador.
local Ambient = table.freeze({
	Giants = table.freeze({
		Level_1 = table.freeze({
			-- FirstDelay: segundos desde que el jugador entra al nivel; Interval: pausa entre pasadas.
			table.freeze({ Template = "Manta_Abisal", Route = "Manta", Branching = true, Speed = 24, FirstDelay = 20, Interval = 170 }),
			table.freeze({ Template = "Nautilo_Colosal", Route = "Nautilo", Speed = 13, FirstDelay = 20, Interval = 320 }),
			-- Ruta compartida A-1..A-n: cada Interval s se tira un dado (Chance); si sale, la recorre una criatura del Pool al azar
			-- (salvo que esa criatura ya esté nadando por su ruta).
			table.freeze({
				Route = "A",
				Chance = 0.5,
				FirstDelay = 40,
				Interval = 60,
				Pool = table.freeze({
					table.freeze({ Template = "Manta_Abisal", Speed = 24 }),
					table.freeze({ Template = "Nautilo_Colosal", Speed = 13 }),
				}),
			}),
		}),
		Level_2 = table.freeze({}),
	}),
	-- Level_2: sin manta ni nautilo (solo peces). Los peces salen en cualquier mapa que tenga Bounds; no hace falta AmbientRoutes.
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
	Audio = Audio,
	BaseOxygenSeconds = 360,
	SeaLevelY = 0, -- Y (studs) de la superficie del agua
	HudUpdateInterval = 0.25, -- 4 Hz, muy por debajo del límite de 20 Hz

	MinPlayers = 1, -- pruebas; GDD: 2-4
	MaxPlayers = 4,
	RoomCodeLength = 4,

	DayLengthSeconds = 600, -- un día completo dura 10 min reales
	StartClockTime = 14, -- hora inicial (0-24)
	LampRange = 110, -- alcance del cono; SpotLight.Range tiene tope real de 120
	LampAngle = 32, -- grados del cono; más cerrado que el círculo para que su borde duro quede tapado por el hotspot
	LampBrightness = 4,
	-- Hotspot: círculo de luz proyectado en la superficie iluminada (solo el jugador local, D3 simplificada).
	LampHotspotImage = "rbxassetid://114691884914775", -- gradiente radial; "" = respaldo de discos Neon
	LampHotspotHalfAngle = 17, -- grados; radio = distancia * tan(ángulo)
	LampHotspotMinRadius = 1.5,
	LampHotspotMaxRadius = 28,
	LampHotspotFlatTolerance = 0.6, -- studs de desvío tolerado en el borde del círculo antes de reducir su radio
	LampHotspotFlatToleranceScale = 0.18, -- la tolerancia crece con el radio (radio * esto)
	LampHotspotFitMinScale = 0.55, -- el ajuste nunca baja del 55 % del radio ideal
	LampHotspotFitSteps = 5, -- reducciones máximas (x0.8 cada una)
	LampHotspotOffset = 0.08, -- studs a lo largo de la normal del impacto
	LampHotspotBrightness = 2,
	LampHotspotColor = Color3.fromRGB(235, 245, 255),
	LampHotspotSmoothing = 18, -- mayor = sigue más rápido
	-- Solo calidad media/alta (QualityTier.Tier >= 2): rebote de luz en el impacto y haz volumétrico con motas.
	LampBounceRangeScale = 1.4, -- alcance del rebote = radio del círculo * esto
	LampBounceBrightness = 0.8,
	-- El haz (Beam) se veía como un rectángulo/trapecio plano al mirar a lo largo del cono: desactivado. Las motas se quedan.
	LampShaftEnabled = false,
	LampShaftTransparency = 0.9,
	LampShaftStartWidth = 0.4,
	LampMoteRate = 18, -- motas/s en el cono (0 = sin motas)
	LampHotspotSnapDistance = 25, -- salto mayor que esto = teletransporte, sin suavizar
	LampFillAngle = 120, -- luz de relleno corta y suave para iluminar el suelo cercano (ponla en 0 brillo para quitarla)
	LampFillRange = 14,
	LampFillBrightness = 1.6,
	-- Calidad baja (QualityTier.IsLow): se apagan las luces locales a más de esta distancia de la cámara y el aura del jugador.
	LightCullDistance = 170, -- calidad media/alta: luces locales más lejos que esto se apagan (el Nivel 2 tiene ~160 luces)
	LowQualityLightCullDistance = 100,
	LowQualityLightCullInterval = 0.5,
	TreasureGlowRange = 18, -- luz propia de cada tesoro para localizarlo en la oscuridad
	TreasureGlowBrightness = 2,
	LampOriginOffset = 0.4, -- studs por delante de la cabeza donde nace la luz (antes 1.2)
	LampToggleCooldown = 0.25,
	-- Aura tenue alrededor del jugador (solo la ve su cliente), para no quedar en negro total. Brillo 0 = desactivada.
	PlayerGlowRange = 16,
	PlayerGlowBrightness = 0.9,
	PlayerGlowColor = Color3.fromRGB(110, 170, 220),

	-- Nivel de calidad de efectos visuales (QualityTier, solo cliente). Niveles de Roblox 1-10 -> Tier 1 baja, 2 media, 3 alta.
	Quality = table.freeze({
		MediumFrom = 4, -- nivel >= 4 -> media
		HighFrom = 8, -- nivel >= 8 -> alta
		TouchMaxLevel = 5, -- en táctil nunca pasa de media
		AutoStartLevel = 7, -- nivel inicial cuando la calidad gráfica está en Automático
		SampleSeconds = 3, -- ventana de medición de FPS
		LowerBelowFps = 40, -- si el FPS medio baja de esto, baja un nivel
		RaiseAboveFps = 57, -- si se mantiene por encima durante RaiseHoldSeconds, sube un nivel
		RaiseHoldSeconds = 12,
		LowerHoldSeconds = 4,
	}),

	-- Pantalla de carga inicial (ReplicatedFirst/LoadingScreen): negra con un engranaje girando hasta precargar sonidos y mallas.
	Loading = table.freeze({
		MinSeconds = 1.5, -- tiempo mínimo en pantalla, para que no parpadee
		MaxSeconds = 90, -- tope: si algo no carga, se entra igual (incluye la generación del mundo)
		WorldText = "Generando el mundo...", -- texto mientras el servidor construye el nivel (atributo Workspace.WorldReady)
		FadeSeconds = 0.6,
		Text = "Cargando...",
		TravelText = "Viajando...", -- texto bajo el engranaje durante los viajes entre niveles (DescentFx)
	}),

	Run = Run,
	Economy = Economy,
	Kraken = Kraken,
	Level = Level,
	Hiding = Hiding,
	Maze = Maze,
	Monster = Monster,
	CreatureAnim = CreatureAnim,
	Swim = Swim,
	Upgrades = Upgrades,
	Water = Water,
})
