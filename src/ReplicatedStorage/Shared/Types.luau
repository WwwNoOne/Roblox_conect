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
	powerDone: number?, -- generadores reparados en el nivel actual
	powerNeeded: number?, -- generadores necesarios para poder bajar (0/nil = sin requisito)
}

-- Minijuego de un generador: la aguja va de 0 a 1 y vuelve en `period` segundos por tramo, desde la hora de servidor `t0`.
export type GeneratorChallenge = { t0: number, period: number, center: number, width: number }
export type GeneratorOpen = { label: string, steps: number, done: number, challenge: GeneratorChallenge }
export type SafeOpen = { label: string, numbers: number, steps: number, step: number, lockedUntil: number }
-- Puerta con panel de interruptores: lights[i] encendida; presses usadas de budget antes del cortocircuito.
export type DoorOpen = { label: string, lights: { boolean }, presses: number, budget: number, lockedUntil: number }

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
