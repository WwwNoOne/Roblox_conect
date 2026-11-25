--!strict
-- Tipos compartidos Cliente/Servidor.

-- Forma de UpdateHUD. Dinero y progreso son datos de partida (compartidos).
-- Los campos de partida son nil fuera de una partida (lobby).
export type HudPayload = {
	money: number?,
	runState: RunState?,
	zone: number?, -- etapa actual/última alcanzada (0 = inicio)
	quota: number?, -- cuota del nivel actual (o del siguiente, en la Parada)
	deposited: number?, -- valor depositado en el nivel actual
	failures: number?, -- cuotas falladas
	levelLeft: number?, -- segundos que quedan del nivel (temporizador de 10 min); nil fuera de un nivel
	advanceIn: number?, -- segundos que faltan para partir (cuenta atrás de Avanzar); nil = no hay
}

-- Level = explorando (puerta abierta); Stopover = en la Parada (puerta cerrada); Descending = viaje sellado.
export type ShopItem = { id: string, name: string, level: number, maxLevel: number, price: number? }
export type ShopState = { money: number, items: { ShopItem } }

export type RunState = "Lobby" | "Descending" | "Level" | "Stopover" | "Won" | "Lost"

export type RoomState = {
	code: string,
	host: number, -- UserId
	members: { number },
	state: RunState,
}

return {}
