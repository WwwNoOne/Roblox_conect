--!strict
-- Contrato de remotos de Abismo (GDD §4). Bootstrap los crea a partir de esta lista.
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
	RequestDescend = "Function", -- () -> { ok: boolean, err: string? }; solo el anfitrión, parada actual
	UpdateHUD = "Event", -- servidor -> cliente: HudPayload
	RequestPurchase = "Function", -- (itemId: string) -> { ok: boolean, err: string? }
	SellTreasure = "Function", -- () -> { ok: boolean, earned: number?, err: string? }
	PlaceBeacon = "Event", -- cliente -> servidor: (active: boolean) mantener/soltar
	RunEnded = "Event", -- servidor -> cliente: (result: "Won" | "Lost", reason: string)
	-- Equipo (reutilizado del prototipo)
	ToggleLamp = "Event",
	AimLamp = "Event",
} :: { [string]: Kind })

return table.freeze(Remotes)
