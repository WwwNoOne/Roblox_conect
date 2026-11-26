--!strict
-- Ruidos del mundo (generadores, cajas fuertes...) que atraen a las criaturas. Quien emite llama a Noise.Emit; MonsterService (T05)
-- se suscribirá a Noise.Emitted cuando las criaturas vuelvan a moverse sobre los mapas fijos.
local Noise = {}

local emitted = Instance.new("BindableEvent")
Noise.Emitted = emitted.Event -- (position: Vector3, radius: number, source: string)

function Noise.Emit(position: Vector3, radius: number, source: string)
	emitted:Fire(position, radius, source)
end

return Noise
