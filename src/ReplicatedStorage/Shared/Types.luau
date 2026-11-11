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
}

export type RunState = "Lobby" | "Descending" | "Stopover" | "Won" | "Lost"

export type RoomState = {
	code: string,
	host: number, -- UserId
	members: { number },
	state: RunState,
}

return {}
