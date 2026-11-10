--!strict
-- Constantes compartidas (GDD: 6 minutos de oxígeno inicial).
-- Valores de pesca/inventario: propuesta de prueba, no están en el GDD.
local Values: { [string]: number } = table.freeze({
	Fish = 10,
	Treasure = 50,
})

-- Criaturas hostiles (valores de Speed < velocidad de nado del jugador, 16, para poder huir).
-- Behavior: "Bite" = daño por golpe; "GrabHalf" = agarra y suelta dejando la vida en LeaveHealthPct;
-- "GrabKill" = agarra y mata.
local Creatures = table.freeze({
	Small = table.freeze({
		Count = 4, Size = Vector3.new(1.5, 1, 3), Color = Color3.fromRGB(60, 190, 170),
		Speed = 14, Detect = 35, Reach = 3.5, Patrol = "Random",
		Behavior = "Bite", DamagePct = 0.05, HitCooldown = 1.5,
		Killable = true, Respawn = 20, -- el arpón las mata de 1 golpe
	}),
	Medium = table.freeze({
		Count = 2, Size = Vector3.new(3, 2.5, 8), Color = Color3.fromRGB(130, 80, 190),
		Speed = 12, Detect = 40, Reach = 5, Patrol = "Random",
		Behavior = "GrabHalf", GrabSeconds = 3, LeaveHealthPct = 0.5,
	}),
	Large = table.freeze({
		Count = 1, Size = Vector3.new(8, 5, 20), Color = Color3.fromRGB(110, 20, 30),
		Speed = 10, Detect = 50, Reach = 8, Patrol = "Markers",
		Behavior = "GrabKill", GrabSeconds = 2,
	}),
})

-- Mejoras de la tienda (precios por nivel). Valores de prueba aprobados, no están en el GDD.
local Upgrades = table.freeze({
	OxygenTank = table.freeze({ Name = "Tanque de oxígeno", Order = 1, Prices = { 100, 250, 500 }, PerLevel = 60 }),
	Lamp = table.freeze({ Name = "Luz potente", Order = 2, Prices = { 150 }, RangeBonus = 30 }),
	Harpoon = table.freeze({ Name = "Arpón largo", Order = 3, Prices = { 200 }, RangeBonus = 30 }),
	PressureSuit = table.freeze({ Name = "Traje de presión", Order = 4, Prices = { 300 } }),
})

return table.freeze({
	BaseOxygenSeconds = 360,
	SeaLevelY = 0, -- Y (studs) de la superficie del agua
	HudUpdateInterval = 0.25, -- 4 Hz, muy por debajo del límite de 20 Hz
	SaveKey = "PlayerSave_v1",

	InventoryCapacity = 10,
	Values = Values, -- monedas por objeto al vender
	HarpoonRange = 60, -- studs
	HarpoonCooldown = 0.8, -- segundos
	FishRespawn = 15,
	TreasureRespawn = 60,

	Creatures = Creatures,
	BiteIFrames = 1, -- segundos de invulnerabilidad a mordiscos tras recibir uno
	GrabImmunity = 6, -- segundos sin ser agarrado tras ser soltado

	DayLengthSeconds = 600, -- un día completo dura 10 min reales
	StartClockTime = 14, -- hora inicial (0-24)
	LampRange = 60,
	LampToggleCooldown = 0.25,

	Upgrades = Upgrades,
	DeepZoneDepth = 35, -- metros; por debajo hace falta el traje de presión
	PressureDamagePerSecond = 8,
	ShopUseDistance = 20, -- studs máx. a la tienda para comprar
	PurchaseCooldown = 0.3,
})
