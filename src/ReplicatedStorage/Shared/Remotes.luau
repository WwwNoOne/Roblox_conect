--!strict
-- Contrato de remotos (GDD §4). Bootstrap los crea a partir de esta lista.
-- Todos los remotos usan al jugador que origina la llamada; el servidor valida todo.
local Remotes = {}

export type Kind = "Event" | "Function"

Remotes.List = table.freeze({
	-- Lobby / sala (T02)
	CreateRoom = "Function", -- () -> { ok: boolean, code: string?, err: string? }
	JoinRoom = "Function", -- (code: string) -> { ok: boolean, code: string?, err: string? }
	StartRun = "Event", -- cliente -> servidor: el anfitrión inicia
	RoomUpdate = "Event", -- servidor -> cliente: RoomState
	-- Partida (T03-T06)
	RequestDescend = "Function", -- () -> { ok: boolean, err: string?, counting: boolean? }; cualquier miembro (solo: parte ya; si no, cuenta atrás)
	RequestExit = "Function", -- () -> { ok: boolean, err: string? }; sale por la puerta del ascensor (solo en niveles)
	UpdateHUD = "Event", -- servidor -> cliente: HudPayload
	RequestPurchase = "Function", -- (itemId: string) -> { ok: boolean, err: string? }
	ShopOpen = "Event", -- servidor -> cliente: ShopState (abrir panel de la tienda)
	DepositTreasure = "Function", -- () -> { ok: boolean, earned: number? (valor depositado), err: string? }
	DescentFx = "Event", -- servidor -> cliente: (phase: "Start" | "End") efecto de cabina sellada (ascensor)
	RunEnded = "Event", -- servidor -> cliente: (result: "Won" | "Lost", reason: string)
	PlayerHit = "Event", -- servidor -> cliente: (damage: number) un enemigo te golpeó (impacto y temblor de cámara)
	SetSprint = "Event", -- cliente -> servidor: (held: boolean) mantiene/suelta el sprint; la estamina es del servidor
	SetStance = "Event", -- cliente -> servidor: (crouching: boolean) se agacha/levanta; el servidor lo publica en el atributo Crouching
	-- Equipo (reutilizado del prototipo)
	ToggleLamp = "Event",
	AimLamp = "Event",
} :: { [string]: Kind })

return table.freeze(Remotes)
