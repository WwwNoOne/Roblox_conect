--!strict
-- Estado compartido del nivel generado (lo escribe LevelService, lo leen MonsterService y otros): plan, red de navegación y contenedor.
local LevelState = {
	plan = nil :: any,
	nav = nil :: any,
	container = nil :: Instance?,
	entry = nil :: Vector3?, -- puerto del pozo de la sala_0
}

return LevelState
