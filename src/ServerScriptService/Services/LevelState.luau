--!strict
-- Estado compartido de la red de navegación de criaturas (lo leen MonsterService y otros). Vacío hasta que los mapas fijos
-- publiquen su red de navegación (pendiente: criaturas, ver docs/plan.md T05).
local LevelState = {
	nav = nil :: any,
	container = nil :: Instance?, -- mapa activo
	entry = nil :: Vector3?,
}

return LevelState
