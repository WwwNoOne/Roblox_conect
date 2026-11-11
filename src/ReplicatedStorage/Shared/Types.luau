--!strict
-- Tipos compartidos Cliente/Servidor.

-- Forma de UpdateHUD. Casco, profundidad y dinero son datos de partida (compartidos);
-- el oxígeno es personal. Los campos de partida son nil fuera de una partida (lobby).
export type HudPayload = {
	oxygen: number,
	oxygenMax: number,
	hull: number?,
	hullMax: number?,
	depth: number?,
	money: number?,
	runState: RunState?,
	zone: number?, -- etapa actual/última alcanzada (0 = inicio)
}

-- Level = explorando (compuerta abierta); Stopover = en la Parada (compuerta cerrada); Descending = viaje sellado.
export type ShopItem = { id: string, name: string, level: number, maxLevel: number, price: number? }
export type ShopState = { money: number, items: { ShopItem }, hull: number, hullMax: number, repairCost: number }

export type RunState = "Lobby" | "Descending" | "Level" | "Stopover" | "Won" | "Lost"

export type RoomState = {
	code: string,
	host: number, -- UserId
	members: { number },
	state: RunState,
}

return {}
