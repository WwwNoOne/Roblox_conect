--!strict
-- Constantes compartidas (GDD: 6 minutos de oxígeno inicial).
-- Mejoras de la tienda (precios por nivel). Valores de prueba aprobados, no están en el GDD.
local Upgrades = table.freeze({
	Lamp = table.freeze({ Name = "Luz potente", Order = 2, Prices = { 150 }, RangeBonus = 30 }),
})

-- Aspecto del agua. Se usa Atmosphere (Lighting.Fog NO se aplica dentro de agua de Terrain).
-- Todos son valores de partida a ajustar jugando; Density/Haze no equivalen a studs exactos.
local Water = table.freeze({
	SurfaceDensity = 0.35, -- densidad justo bajo la superficie
	DeepDensity = 0.9, -- densidad a DeepDepth
	SurfaceHaze = 2,
	DeepHaze = 8,
	DeepDepth = 60, -- metros a los que se alcanza lo más oscuro/denso
	SurfaceColor = Color3.fromRGB(30, 140, 170),
	DeepColor = Color3.fromRGB(3, 12, 30),
	NightDarkness = 0.85, -- cuánto oscurece de noche el color del agua
	DarkenAtDepth = 0.25, -- oscurecimiento máximo de la imagen a DeepDepth
	LampDensityReduction = 0.1, -- cuánto baja la densidad con la lámpara encendida
	LampDensityPerLevel = 0.07, -- reducción extra por nivel de "Luz potente"
	MinDensity = 0.12,
	TransitionSpeed = 4, -- suavizado al cruzar la superficie
})

return table.freeze({
	BaseOxygenSeconds = 360,
	SeaLevelY = 0, -- Y (studs) de la superficie del agua
	HudUpdateInterval = 0.25, -- 4 Hz, muy por debajo del límite de 20 Hz

	MinPlayers = 1, -- pruebas; GDD: 2-4
	MaxPlayers = 4,
	RoomCodeLength = 4,

	DayLengthSeconds = 600, -- un día completo dura 10 min reales
	StartClockTime = 14, -- hora inicial (0-24)
	LampRange = 60,
	LampAngle = 45, -- grados del cono (antes 70, demasiado ancho para una linterna)
	LampFillAngle = 120, -- luz de relleno corta y suave para iluminar el suelo cercano (ponla en 0 brillo para quitarla)
	LampFillRange = 14,
	LampFillBrightness = 1.2,
	LampOriginOffset = 0.4, -- studs por delante de la cabeza donde nace la luz (antes 1.2)
	LampToggleCooldown = 0.25,

	Upgrades = Upgrades,
	Water = Water,
})
