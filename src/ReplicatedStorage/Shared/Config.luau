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
		Behavior = "Bite", DamagePct = 0.25, HitCooldown = 1.5,
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
})
