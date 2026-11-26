--!strict
-- Constantes compartidas (ver game_designs/GDD.md).
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

-- Partida (T03). TODOS son valores de prueba a calibrar en T08.
-- Etapas en orden: Nivel 1 -> Parada -> Nivel 2 -> Parada -> Nivel 3 (final). Map = carpeta en Workspace.Maps.
-- Kind "Level": se sale a explorar (puerta abierta). Kind "Parada": nadie sale; se vende/compra desde dentro.
-- Beacon = true: el nivel tiene el objetivo final (victoria al activarlo). TODO(GDD): condición de victoria por definir.
-- Quota (opcional): valor de tesoros a depositar en ese nivel; el último nivel no tiene cuota.
local Run = table.freeze({
	StartMoney = 0,
	BeaconHoldSeconds = 5, -- mantener E para activar la baliza (ProximityPrompt.HoldDuration)
	EndScreenSeconds = 8, -- tiempo de la pantalla final antes de volver a la sala
	TravelSeconds = 20, -- duración del viaje entre etapas
	-- Temporizador de cada nivel (solo en Kind "Level"): al llegar a 0 el ascensor parte solo (la tripulación que sigue fuera es
	-- subida a bordo, se cierra la cuota como si hubieran pulsado Avanzar) y en el último nivel la partida se pierde por tiempo.
	LevelSeconds = 600, -- 10 minutos
	LevelWarnings = { 120, 60, 30, 10 }, -- avisos (segundos restantes)
	-- Al pulsar Avanzar con más de un jugador vivo, los demás tienen este tiempo para entrar; con todos dentro se parte antes.
	AdvanceCountdown = 60,
	Stages = table.freeze({
		table.freeze({ Kind = "Level", Map = "Level_1", Quota = 400 }),
		table.freeze({ Kind = "Parada", Map = "Parada" }),
		table.freeze({ Kind = "Level", Map = "Level_2", Quota = 200 }),
		table.freeze({ Kind = "Parada", Map = "Parada" }),
		table.freeze({ Kind = "Level", Map = "Level_3", Beacon = true }),
	}),
})

-- Enemigos 2.5D del laberinto (MonsterService + CreatureFxClient; ver docs/criaturas.md).
-- Categorías: Aggressive (perseguidor letal), Stalker (observa desde lejos; huye si lo miras o delata si lo ignoras),
-- Ambusher (espera en esquinas/escondites, lanza screamer 2D, baja vida y huye).
-- Los jugadores caminan a Sprint.WalkSpeed (16) y corren a Sprint.Speed (34).
local Monster = table.freeze({
	Length = 8, -- alto de referencia del modelo 2.5D (Root 2x8x2)
	KeepModelScale = true, -- respeta la escala de las plantillas 2.5D de Codex
	BodyRadius = 2.0, -- radio de la esfera de colisión contra paredes y puertas
	HeadOffset = 0, -- desplazamiento de la vista desde Root (ya está centrado a mitad de altura)
	CenterHeight = 4, -- altura del centro de Root sobre el suelo
	NavGridSpacing = 10, -- separación (studs) de la malla de puntos de navegación que MapNav añade sobre el suelo
	WaypointRadius = 3, -- distancia a la que da por alcanzado un punto del camino
	PatrolSpeed = 14, -- studs/s patrullando
	ChaseSpeed = 27, -- persiguiendo (el sprint del jugador es 34, caminar 16)
	FrenzyBonus = 0.08, -- +8% de velocidad tras FrenzySeconds persiguiendo sin parar
	FrenzySeconds = 6,
	Accel = 55, -- studs/s² al acelerar
	Brake = 70, -- studs/s² al frenar
	TurnRate = 10, -- giro suave (mayor = gira más rápido)
	Carrot = 0.35, -- punto de mira del camino: velocidad x esto, en studs por delante
	-- Detección
	SightRange = 80, -- vista con línea de visión (la lámpara encendida lo multiplica)
	LampSightMultiplier = 1.5,
	HearRange = 14, -- te oye a esta distancia aunque no te vea (no si estás escondido)
	NoiseRange = 34, -- si vas corriendo (Sprint) haces ruido y te oye desde esta distancia
	HiddenRange = 5, -- escondido solo te encuentra si está pegado a tu caja...
	DiscoverSeconds = 2.5, -- ...y si se queda así este tiempo te descubre (te saca de la caja)
	HiddenLoseSeconds = 1.5,
	LoseSeconds = 4,
	SearchSeconds = 10,
	LingerRadius = 45,
	SearchSpeedMul = 1.2,
	AvoidRadius = 85,
	AlertRadius = 160,
	LeadSeconds = 0.45,
	-- Ataque del Agresivo (zarpazo letal en tres fases)
	AttackStart = 12,
	WindupSeconds = 0.28,
	LungeSpeed = 48,
	LungeSeconds = 0.38,
	HitRadius = 5.5,
	AttackDamage = 100, -- si atrapa al jugador lo mata
	RecoverSeconds = 0.7,
	AttackCooldown = 1.0,
	HitGap = 0.8,
	StuckSeconds = 1.5,
	FirstDelay = 8, -- segundos desde el inicio del nivel hasta el primer enemigo
	MinSpawnDistance = 65, -- aparece al menos a esta distancia del Ascensor
	-- Acosador (Stalker)
	StalkSpeed = 18,
	StalkMinDist = 32,
	StalkMaxDist = 85,
	StalkLookDot = 0.72, -- coseno del cono de mirada del jugador para considerarlo "visto"
	StalkBanishSeconds = 1.6, -- tiempo mirándolo/alumbrándolo para ahuyentarlo
	StalkAlertSeconds = 5.5, -- tiempo observándote sin que lo mires antes de delatar tu posición
	StalkTooClose = 20, -- si te acercas demasiado también huye
	StalkCooldown = 12,
	-- Acechador (Ambusher)
	AmbushMoveSpeed = 20,
	AmbushFleeSpeed = 30,
	AmbushRange = 10.5, -- distancia de emboscada en esquina o pasillo
	AmbushHideSpotRange = 8.5, -- distancia si está oculto junto a un HideSpot
	AmbushDamage = 30, -- baja vida sin matar directo (salvo vida crítica)
	AmbushScreamerSeconds = 0.95,
	AmbushCooldown = 16,
	AmbushRelocateSeconds = 35, -- si nadie pasa en este tiempo, cambia de esquina/escondite
	Debug = true,
	-- Cuántos enemigos salen por nivel (con 3 especies salen las 3 categorías para probar).
	PerLevel = 3,
	SpawnStagger = 8, -- segundos entre la aparición de un enemigo y el siguiente
	-- Especies 2.5D de Codex (assets_build/exports/creatures/ -> ServerStorage.GameAssets.Creatures).
	-- Si aún no se importan los .rbxmx en Studio, MonsterService construye el modelo 2.5D con estos mismos IDs.
	Species = table.freeze({
		table.freeze({
			Name = "Agresivo",
			TemplateName = "creature_agresivo_01",
			Category = "Aggressive",
			Weight = 1,
			AttackDamage = 100,
			BodyImage = "rbxassetid://125416395009712",
			EyesImage = "rbxassetid://92079012147493",
			SpriteCols = 4,
			SpriteRows = 4,
			AnimFps = 12,
			BillboardSize = Vector2.new(9.5, 9.5),
			StudsOffset = Vector3.new(0, 0.2, 0),
			LightColor = Color3.fromRGB(255, 110, 60),
		}),
		table.freeze({
			Name = "Acosador",
			TemplateName = "creature_acosador_01",
			Category = "Stalker",
			Weight = 1,
			BodyImage = "rbxassetid://72237757733107",
			EyesImage = "rbxassetid://85458595523316",
			SpriteCols = 4,
			SpriteRows = 4,
			AnimFps = 10,
			BillboardSize = Vector2.new(8.5, 8.5),
			StudsOffset = Vector3.new(0, -0.42, 0),
			LightColor = Color3.fromRGB(185, 225, 255),
		}),
		table.freeze({
			Name = "Acechador",
			TemplateName = "creature_acechador_01",
			Category = "Ambusher",
			Weight = 1,
			BodyImage = "rbxassetid://117589415294503",
			ScreamerImage = "rbxassetid://85806574415851",
			SpriteCols = 4,
			SpriteRows = 4,
			AnimFps = 12,
			ScreamerCols = 4,
			ScreamerRows = 4,
			ScreamerFrames = 12,
			BillboardSize = Vector2.new(7.5, 7.5),
			StudsOffset = Vector3.new(0, -1.05, 0),
			LightColor = Color3.fromRGB(220, 175, 85),
		}),
	}),
})

-- Esconderse (Hiding + HidingHandlers): cada volumen `Escondite` del laberinto (la caja industrial de cada pieza) lleva un
-- ProximityPrompt. Pulsar E te mete en la caja (quedas quieto e invisible, atributo de jugador Hidden = true) y otra vez E sales
-- por donde entraste. Los enemigos ignoran a quien está escondido.
local Hiding = table.freeze({
	HoldSeconds = 0.4, -- tiempo que hay que mantener E
	Distance = 7, -- distancia máxima al centro de la caja para ver el aviso
	PromptText = "Esconderse / Salir",
	ObjectText = "Caja industrial",
	Cooldown = 0.6, -- segundos entre usos del mismo jugador (evita rebotes)
})

-- Preparación del mundo (LevelService). Los niveles son mapas fijos en Workspace.Maps (los carga Runs).
local Level = table.freeze({
	-- Carpetas de Workspace que se apartan a ServerStorage.Plantillas al arrancar (assets de pruebas, plantillas de criaturas...) para que
	-- no estorben ni se carguen en la partida.
	Stash = { "Assets", "Zona_Prueba", "LeadPipes", "Creatures" },
})

-- Objetivos del nivel (ObjectiveService): generadores que reparar y cajas fuertes que abrir. Valores de prueba (T08).
-- Generadores: van en los MachineSpawn del mapa. Repararlos = minijuego de calibración (fijar una aguja oscilante dentro de la franja,
-- Steps veces). Fallar suelta chispas, hace ruido y resta un paso. Hasta reparar Needed generadores el ascensor no puede bajar
-- (el temporizador del nivel sigue partiendo solo).
-- Cajas fuertes: van en los PuzzleSpawn cuyo Part padre empieza por "Cofre". Se abren con un dial de combinación (Steps números,
-- 0..Numbers-1): al pasar por el número correcto se oye un clic; se fija con Espacio. Dentro hay tesoros (Loot).
local Objectives = table.freeze({
	UseDistance = 10, -- studs máx. para abrir el minijuego; a más de UseDistance + 4 se cierra solo
	Generator = table.freeze({
		Template = "Generator", -- Model opcional en GameAssets (contrato: Body, PromptAttachment, Screen, StatusLight, Fan, ExhaustPoint, SparkPoint); sin él se construye uno de piezas (Props)
		Base = 2, -- generadores necesarios con 1 jugador
		PerExtraPlayers = 2, -- +1 necesario por cada 2 jugadores adicionales
		Spare = 1, -- generadores extra que aparecen (no hace falta repararlos todos)
		Steps = 3, -- calibraciones correctas para repararlo
		Period = { 1.25, 1.05, 0.9 }, -- segundos que tarda la aguja en cruzar el medidor, por paso
		ZoneWidth = { 0.24, 0.18, 0.13 }, -- ancho de la franja válida (fracción del medidor), por paso
		Tolerance = 0.03, -- margen extra al validar (latencia)
		MaxClockSkew = 0.6, -- segundos de desfase aceptados en la marca de tiempo del cliente
		HitCooldown = 0.25,
		MissPenalty = 1, -- pasos que se pierden al fallar
		NoiseRadius = 70, -- ruido al fallar (T05: lo oirán las criaturas)
		RepairedNoiseRadius = 110,
		HoldSeconds = 0.3,
	}),
	Safe = table.freeze({
		Template = "Safe", -- Model opcional en GameAssets (contrato: Body, Door [Model con Hinge], Dial, PromptAttachment, StatusLight, LootPoint)
		SpawnPrefix = "Cofre", -- PuzzleSpawn cuyo Part padre empieza por esto
		Numbers = 40,
		Steps = 3,
		MinGap = 6, -- distancia mínima entre números consecutivos de la combinación
		ProbesPerSecond = 14, -- límite de consultas del dial (cada número que se pasa)
		LockoutSeconds = 2.5, -- bloqueo tras fijar un número incorrecto
		NoiseRadius = 50,
		Loot = { "Large", "Medium" }, -- tesoros que aparecen dentro al abrirla
		OpenSeconds = 1.6, -- duración de la animación de la puerta
		HoldSeconds = 0.3,
	}),
	-- Puertas con puzzle (atajos): persiana en el vano de cada PuzzleSpawn cuyo Part padre empieza por SpawnPrefix. Se abre con un
	-- panel de interruptores (uno a cada lado): cada palanca invierte su luz y las vecinas; hay que encenderlas todas. El vano se mide
	-- con rayos (jambas y dintel); el Part del marcador puede fijarlo con los atributos Width / Height (studs).
	Door = table.freeze({
		SpawnPrefix = "Puerta",
		Levers = 5,
		Scramble = 3, -- pulsaciones al azar desde la solución (siempre tiene solución en <= Scramble pulsaciones)
		MinPresses = 2, -- se vuelve a mezclar si se resuelve con menos (no puede pasar de Scramble)
		Budget = 10, -- pulsaciones antes del cortocircuito (se vuelve a mezclar y bloquea el panel)
		LockoutSeconds = 3,
		PressCooldown = 0.18,
		PressNoiseRadius = 30, -- cada palanca hace ruido
		ShortNoiseRadius = 80, -- el cortocircuito, mucho más
		OpenSeconds = 2.2, -- la persiana sube
		DefaultWidth = 10,
		DefaultHeight = 9,
		MaxJamb = 9, -- studs máx. del marcador a cada jamba al medir el vano
		HoldSeconds = 0.3,
	}),
	-- Sonidos (ids de la Creator Store; cámbialos aquí). Volumen por sonido.
	Sounds = table.freeze({
		GeneratorHum = { Id = "rbxassetid://85901761858902", Volume = 0.55 },
		Spark = { Id = "rbxassetid://9116279339", Volume = 0.8 },
		DialClick = { Id = "rbxassetid://127004816100960", Volume = 0.9 },
		DialTick = { Id = "rbxassetid://9080070218", Volume = 0.25 },
		Lock = { Id = "rbxassetid://92873453090584", Volume = 0.8 },
		Wrong = { Id = "rbxassetid://134343807114403", Volume = 0.5 },
		SafeOpen = { Id = "rbxassetid://9118837996", Volume = 0.9 },
		Pickup = { Id = "rbxassetid://76809333017046", Volume = 0.7 },
		Lever = { Id = "rbxassetid://92873453090584", Volume = 0.6 }, -- provisional: el de Lock
		Shutter = { Id = "rbxassetid://9118837996", Volume = 1 }, -- provisional: el de SafeOpen
	}),
})

local Economy = table.freeze({
	CarrySlots = 4, -- objetos que lleva cada jugador (1 por slot)
	-- Objetos de recolección (para la cuota). Kit = carpeta de GameAssets con los modelos de Codex; cada Model lleva el atributo
	-- ClaseSugerida ("Small" | "Medium" | "Large") que decide su valor. Scale: tamaño sobre el modelo del kit (miden 3-5 studs);
	-- Color: luz propia para localizarlos en la oscuridad. Sin modelos del kit se usa una pieza provisional.
	Kit = "Kit_Objetos_De_Recoleccion",
	-- Icono de la ranura del HUD según la carpeta del kit de la que sale el objeto; DefaultGlyph si no está.
	KitGlyphs = table.freeze({ Documentos = "report", Almacenamiento_De_Datos = "disk", Equipo_De_Fabrica = "gauge" }),
	DefaultGlyph = "gauge",
	Treasure = table.freeze({
		Small = table.freeze({ Value = 25, Size = Vector3.new(2, 1, 2), Color = Color3.fromRGB(240, 200, 80), Scale = 1.4 }),
		Medium = table.freeze({ Value = 75, Size = Vector3.new(3, 1.5, 3), Color = Color3.fromRGB(120, 220, 240), Scale = 1.4 }),
		Large = table.freeze({ Value = 200, Size = Vector3.new(4, 2.5, 4), Color = Color3.fromRGB(230, 90, 220), Scale = 1.4 }),
	}),
	-- Reparto por nivel (EconomyHandlers.spawnTreasure). Se buscan huecos en el suelo de las piezas del laberinto generado (más en las
	-- salas que en los pasillos) y cada TreasureSpawn (Attachment) colocado a mano en una pieza cuenta como hueco. Se llenan los
	-- necesarios para que el valor total sea >= cuota * margen (y no mucho más); las posiciones cambian en cada partida.
	Balance = table.freeze({
		Margin = 1.4, -- el valor repartido es la cuota x esto: la cuota y "un poco más" para cubrir pérdidas y comprar equipo
		PerUpgradeLevel = 0.05, -- +margen por cada nivel de mejora comprado (equipo más fuerte recoge más; el extra paga más mejoras)
		PerExtraPlayer = 0.08, -- +margen por jugador adicional a 1 (más manos, más tesoros)
		MaxMargin = 2.0,
		MaxOver = 1.6, -- el total repartido no pasa de cuota x margen x esto (evita niveles regalados)
		FillFraction = 0.35, -- fracción de huecos que se llenan (antes de ajustar al valor objetivo)
		MinCount = 10, -- mínimo de tesoros por nivel (si hay huecos)
	}),
	-- Cuota por nivel: se deposita en el ascensor durante el nivel y se cobra al cerrarlo.
	Quota = table.freeze({
		BonusFraction = 0.5, -- cuota cumplida: pago = depositado + cuota * BonusFraction (extra para equipamiento)
		ShortfallFactor = 0.75, -- cuota fallida: pago = depositado * ShortfallFactor y suma un fallo
		MaxFailures = 2, -- al llegar a este número de fallos se pierde (GDD: subir a 3 con más niveles)
	}),
	StationUseDistance = 14, -- studs máx. a la estación (validación de remotos)
	-- TODO(GDD): mejoras de la tienda por definir (hoy solo la linterna).
	Shop = table.freeze({ Lamp = Upgrades.Lamp }),
})

-- Sprint (SprintClient + StaminaService + MovementClient): mantener Shift (botón "Correr" en táctil) para correr gastando estamina.
-- La estamina es del servidor (atributos de jugador Stamina/StaminaMax/Sprinting/Exhausted). Si se vacía, no se puede correr hasta
-- recuperar ExhaustedUntil. Correr hace ruido: los enemigos te oyen desde Monster.NoiseRange. Sustituye al dash (eliminado).
-- Tensión buscada: correr (34) supera la persecución de los enemigos (26-29), pero solo ~7 s: hay que romper la línea de visión
-- y salir de su oído antes de quedarse sin estamina.
local Sprint = table.freeze({
	WalkSpeed = 16, -- velocidad al caminar (MovementController, ver Config.Movement)
	Key = Enum.KeyCode.LeftShift,
	PadKey = Enum.KeyCode.ButtonL3,
	Speed = 34, -- WalkSpeed al correr
	StaminaMax = 100,
	DrainPerSecond = 15, -- ~6,7 s de carrera continua
	RegenPerSecond = 12, -- recarga al no correr (~8 s de vacío a lleno)
	RegenDelay = 1.2, -- segundos sin correr antes de empezar a recuperar
	ExhaustedUntil = 30, -- tras vaciarse no se puede correr hasta llegar a esta estamina
	MinSpeed = 6, -- hay que moverse (studs/s) para gastar estamina
	StepSeconds = 0.1, -- paso de simulación del servidor
})


-- Primera persona fija (FirstPersonClient). Mira = puntito central; los paneles de ModalGuis liberan el cursor y CursorKey (mantener)
-- también (para clicar la interfaz en PC; en móvil se toca). CameraOffset empuja la cámara hacia delante del cuello (z negativo = delante).
local FirstPerson = table.freeze({
	CursorKey = Enum.KeyCode.LeftAlt,
	ModalGuis = table.freeze({ "Shop", "ElevatorPanel" }),
	DotSize = 4,
	DotColor = Color3.fromRGB(235, 245, 255),
	DotTransparency = 0.15,
	-- CameraMotion coloca la cámara a la altura de los ojos y por delante de la cara (el modo primera persona de Roblox la deja en
	-- el centro de la cabeza y el cuello tapa la vista). CameraOffset queda a cero: la posición es solo de CameraMotion.
	CameraOffset = Vector3.zero,
	EyeUp = 0.18, -- studs por encima del centro de la cabeza
	EyeForward = 0.32, -- studs por delante del centro de la cabeza (sin salir de la caja de colisión del cuerpo)
})

-- Escala única del avatar (AvatarService): todos los personajes R15 se normalizan a estas escalas al aparecer, para que la altura
-- de los ojos, las puertas y los escondites sean iguales para todos. Se conservan ropa, colores y accesorios.
local Avatar = table.freeze({
	HeightScale = 1,
	WidthScale = 1,
	DepthScale = 1,
	HeadScale = 1,
	BodyTypeScale = 0,
	ProportionScale = 0,
})

-- Movimiento en tierra (MovementController + CameraMotion). Un solo dueño de WalkSpeed, del FOV y del CameraOffset.
-- Velocidades en studs/s: andar y correr salen de Config.Sprint (equilibrio con Monster.ChaseSpeed: te alcanzan andando, no corriendo).
local Movement = table.freeze({
	WalkSpeed = Sprint.WalkSpeed,
	SprintSpeed = Sprint.Speed,
	CrouchSpeed = 8,
	StartSpeedFactor = 0.45, -- al arrancar desde parado se parte de esta fracción de la velocidad objetivo (inercia)
	Accel = 45, -- studs/s² al ganar velocidad (de andar a correr en ~0,4 s)
	Decel = 60, -- studs/s² al perderla (soltar Shift, agacharse)
	BackwardFactor = 0.75, -- andar hacia atrás es más lento
	StrafeFactor = 0.9, -- y de lado
	SprintMinForward = 0.35, -- solo se corre hacia delante (producto escalar con la mirada)
	CarryPenaltyPerItem = 0.04, -- -4 % de velocidad por objeto cargado (GDD: el botín pesa)
	ExhaustedFactor = 0.85, -- agotado: se camina más lento
	LowHealthFraction = 0.25, -- por debajo de esta vida se cojea...
	LowHealthFactor = 0.88, -- ...a esta fracción de la velocidad
	SprintGrace = 0.4, -- s que el cliente corre antes de que el servidor confirme Sprinting (oculta la latencia)
	-- Agacharse (C / B del mando / botón táctil): más lento, cámara más baja y los enemigos te oyen a menos distancia.
	CrouchKey = Enum.KeyCode.C,
	CrouchPadKey = Enum.KeyCode.ButtonB,
	CrouchCameraDrop = 1.6, -- studs que baja la cámara
	CrouchHearFactor = 0.5, -- multiplica el HearRange de los enemigos (MonsterService)
	CrouchHeadroom = 2.2, -- studs libres sobre la cabeza necesarios para levantarse
	CrouchIdleAnim = "", -- [PENDIENTE] animación propia de agachado en reposo (la del pack es de otro creador y Roblox la bloquea)
	CrouchWalkAnim = "", -- [PENDIENTE] andar agachado; vacío = se usa la de reposo
	-- Caídas: impacto = velocidad vertical al tocar suelo (studs/s).
	SoftLandSpeed = 22, -- por debajo no hay efecto de aterrizaje
	HardLandSpeed = 55, -- por encima: golpe seco, ralentización y animación de aterrizaje
	HardLandSlowSeconds = 0.7,
	HardLandSlowFactor = 0.45,
	LandAnim = "", -- [PENDIENTE] animación propia de aterrizaje fuerte (la del pack está bloqueada)
	-- Cámara (CameraMotion). Amplitudes en studs y grados; las zancadas marcan el ritmo del balanceo.
	FieldOfView = 70,
	SprintFovBonus = 7, -- proporcional a la velocidad real por encima de andar
	CrouchFovBonus = -4,
	BobVertical = 0.11, -- bajada de la cabeza en cada pisada (andando)
	BobLateral = 0.06, -- vaivén hacia la pierna de apoyo
	BobRoll = 0.55, -- grados
	BobPitch = 0.35, -- grados
	GaitBobScale = table.freeze({ Crouch = 0.6, Walk = 1, Sprint = 1.9 }),
	StrafeRoll = 1.6, -- grados de inclinación al moverse de lado
	LookRoll = 2.2, -- grados máx. de inclinación al girar rápido
	LandDip = 0.55, -- studs máx. que baja la cámara al aterrizar
	BreathAmplitude = 0.015, -- respiración en reposo
	BreathAmplitudeTired = 0.06, -- jadeo con la estamina baja
})

-- Sonido de movimiento (FootstepAudio). IDs verificados en Studio (2026-11-25). Cada superficie tiene variantes: nunca suena la
-- misma dos veces seguidas y cada pisada varía tono y volumen. Un BasePart puede forzar su superficie con el atributo
-- "Superficie" (p. ej. "Carpet" para una moqueta hecha con Fabric). Metal: SCP:CB, licencia CC BY-SA 3.0 (atribuir en créditos).
local function ids(...: number): { string }
	local list = {}
	for _, id in { ... } do
		table.insert(list, "rbxassetid://" .. id)
	end
	return table.freeze(list)
end
local Footsteps = table.freeze({
	Surfaces = table.freeze({
		Concrete = table.freeze({ Volume = 0.55, Sounds = ids(104345504554799, 70639393862430, 108290664490396, 96955798612091, 120195545352847, 78982375383648, 112000835797556, 106961831442199) }),
		Carpet = table.freeze({ Volume = 0.6, Sounds = ids(91882016473062, 111131620367547, 73343053773763, 123224557798023, 92103616531947, 73871404556766, 77619756895899, 131412978408311, 83766009140419, 114768473003662) }),
		Metal = table.freeze({ Volume = 0.5, Sounds = ids(139723537411614, 135890657963973, 134846179256941) }),
		Wood = table.freeze({ Volume = 0.6, Sounds = ids(116028889166618, 75982487060381, 92705710431057, 76286399907074) }),
		Water = table.freeze({ Volume = 0.5, Sounds = ids(9120582975, 9113361614) }),
		Grass = table.freeze({ Volume = 0.55, Sounds = ids(116195990169547, 134875177651982) }),
	}),
	Default = "Concrete",
	Materials = table.freeze({
		[Enum.Material.Fabric] = "Carpet",
		[Enum.Material.Carpet] = "Carpet",
		[Enum.Material.Metal] = "Metal",
		[Enum.Material.DiamondPlate] = "Metal",
		[Enum.Material.CorrodedMetal] = "Metal",
		[Enum.Material.Foil] = "Metal",
		[Enum.Material.Wood] = "Wood",
		[Enum.Material.WoodPlanks] = "Wood",
		[Enum.Material.Water] = "Water",
		[Enum.Material.Grass] = "Grass",
		[Enum.Material.LeafyGrass] = "Grass",
		[Enum.Material.Ground] = "Grass",
		[Enum.Material.Mud] = "Grass",
		[Enum.Material.Sand] = "Grass",
	} :: { [Enum.Material]: string }),
	-- Zancada (studs por pisada) y volumen/alcance según la forma de moverse.
	Gaits = table.freeze({
		Crouch = table.freeze({ Stride = 4, Volume = 0.3, Range = 22, Pitch = 0.95 }),
		Walk = table.freeze({ Stride = 7.5, Volume = 0.7, Range = 55, Pitch = 1 }),
		Sprint = table.freeze({ Stride = 11, Volume = 1, Range = 110, Pitch = 1.06 }),
	}),
	PitchJitter = 0.07,
	VolumeJitter = 0.12,
	MinSpeed = 1.5, -- por debajo no hay pasos
	OthersSprintRatio = 1.35, -- otro jugador corre si va a más de WalkSpeed x esto
	-- Oclusión: los pasos de otros tras una pared suenan apagados.
	OccludedVolume = 0.55,
	OccludedHighGain = -24,
	OccludedMidGain = -8,
	-- Otros sonidos
	Cloth = ids(9113468907, 9113534108), -- ropa al saltar, agacharse y levantarse
	BodyFall = ids(122835002033356), -- golpe del cuerpo en un aterrizaje fuerte
	Breathing = "rbxassetid://123035842146872", -- bucle de jadeo (volumen según el esfuerzo)
	BreathingMaxVolume = 0.45,
	Heartbeat = "rbxassetid://6202853067", -- bucle de latido con poca vida
	HeartbeatMaxVolume = 0.6,
	HeartbeatBelow = 0.35, -- fracción de vida a partir de la cual se oye
	-- Reverberación del espacio (solo pasos y ropa, no la música): se mide con rayos alrededor de la cámara.
	ReverbProbeSeconds = 0.4,
	ReverbProbeRange = 70,
})

-- Interfaz de supervivencia (SurvivalHud): vida, estamina, cuota y ranuras.
local Hud = table.freeze({
	LowHealth = 0.3, -- fracción: barra en rojo y viñeta
	StaminaHideAfter = 1.8, -- s con la estamina llena antes de ocultar su barra
	DamageTrailDelay = 0.45, -- s que espera el rastro blanco del daño antes de encogerse
	Glyphs = table.freeze({ report = "DOC", disk = "DAT", gauge = "EQP" }), -- respaldo en texto si no está la hoja de iconos de Codex
})

-- Zona segura (SafeZone.luau): el interior del Ascensor. Dentro no hay enemigos ni ataques y no se corre.
local SafeZone = table.freeze({
	PlanePad = 6, -- margen alrededor del interior del Ascensor vetado a los enemigos
})

-- Impacto y temblor de cámara (CameraFxClient). Impacto: sacudida corta + destello rojo cuando un enemigo te golpea (remoto PlayerHit).
-- Tensión: temblor leve y continuo que crece cuando un enemigo te persigue o te rastrea cerca, y un pulso al empezar su zarpazo.
-- Los ángulos son radianes de giro de la cámara (0,01 rad ~ 0,6 grados).
local CameraFx = table.freeze({
	ImpactSeconds = 0.55,
	ImpactAngle = 0.075, -- para un golpe de ImpactRefDamage; se escala con el daño recibido (0,6x a 1,5x)
	ImpactRefDamage = 50,
	ImpactFrequency = 24, -- oscilaciones/s
	FlashColor = Color3.fromRGB(190, 20, 20),
	FlashTransparency = 0.55, -- transparencia inicial del destello (0 = opaco); se desvanece sola
	FlashSeconds = 0.45,
	TensionRange = 70, -- studs: un enemigo agresivo más cerca que esto empieza a hacer temblar la cámara
	TensionAngle = 0.0045, -- temblor máximo continuo (enemigo pegado a ti en persecución)
	TensionFrequency = 7,
	TensionSmoothing = 3, -- suavizado al subir/bajar la tensión
	SearchWeight = 0.5, -- peso de un enemigo que rastrea (Search/Investigate) respecto a uno que persigue
	PatrolWeight = 0.2, -- y de uno que patrulla a menos de PatrolRange
	PatrolRange = 28,
	WindupPulseAngle = 0.014, -- pulso al empezar su zarpazo (Windup)
	WindupPulseSeconds = 0.3,
})

-- Indicador del ascensor (ElevatorMarker.client): rombo con la distancia, o flecha al borde de la pantalla si está fuera de vista.
local ElevatorMarker = table.freeze({
	Color = Color3.fromRGB(255, 220, 120),
	HideWithin = 30, -- studs: se oculta al estar cerca del ascensor
	HeightOffset = 8, -- el rombo se dibuja unos studs por encima del centro del ascensor
	Margin = 48, -- píxeles de separación respecto al borde de la pantalla
})

-- Prefijos de nombre (sin distinguir mayúsculas) de los sonidos en Workspace.sonidos. Ver Shared/Sfx.
local Sfx = table.freeze({
	Impact = "Impacto", -- sonido del golpe de un enemigo (añadir un Sound cuyo nombre empiece por esto a Workspace.sonidos; opcional)
	CreatureRoar = "Criatura_Rugido",
	CreatureAlert = "Criatura_Alerta",
	CreatureWhisper = "Criatura_Susurro",
	CreatureScreamer = "Criatura_Screamer",
	-- Ascensor. Prefijos completos para no mezclar p. ej. Avanzar_1 con otros.
	ElevatorEnter = "entrar", -- un jugador entra por la puerta
	ElevatorExit = "Salir", -- un jugador sale por la puerta
	ElevatorStart = "Iniciar_partida", -- todos a bordo: parte hacia el primer nivel
	ElevatorAdvance = table.freeze({ "Avanzar_1", "Avanzar_2" }), -- viaje entre nivel y Parada (al azar)
	ElevatorDefeat = "Alarma_perdieron", -- cualquier derrota
	ElevatorArrive = "Cuando_llega_al_siguiente_nivel", -- el ascensor llega a un nivel o a la Parada
	PanelClick = "Panel_Click", -- botón del panel del ascensor
	-- Ambiente de las salas de la instalación; los usa FacilityAmbience.client.
	FacilityAmbience = "Ambiente_Instalacion",
	PipeGroan = "Tuberia_Gemido",
})

-- Audio de partida: música por contexto (Workspace.sonidos.Musica_background, por nombre) y mezcla de los efectos del ascensor.
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
	ElevatorVolume = 0.6,
	ElevatorRollOff = 160, -- studs: los efectos del ascensor se oyen dentro y cerca, no en todo el mapa
})

return table.freeze({
	Sprint = Sprint,
	ElevatorMarker = ElevatorMarker,
	CameraFx = CameraFx,
	SafeZone = SafeZone,
	FirstPerson = FirstPerson,
	Avatar = Avatar,
	Movement = Movement,
	Footsteps = Footsteps,
	Hud = Hud,
	Sfx = Sfx,
	Audio = Audio,
	HudUpdateInterval = 0.25, -- 4 Hz, muy por debajo del límite de 20 Hz

	MinPlayers = 1, -- pruebas; GDD: 2-4
	MaxPlayers = 4,
	RoomCodeLength = 4,

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
	PlayerGlowColor = Color3.fromRGB(235, 225, 190),

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
	Level = Level,
	Objectives = Objectives,
	Hiding = Hiding,
	Monster = Monster,
	Upgrades = Upgrades,
})
