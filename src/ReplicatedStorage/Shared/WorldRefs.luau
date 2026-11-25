--!strict
-- Localiza objetos del mundo sin depender de en qué carpeta del Workspace estén (p. ej. Workspace.Lobby.Elevator o
-- Workspace.Elevator). Así se puede reorganizar el Workspace en Studio sin romper los scripts.
local WorldRefs = {}

local cachedElevator: Model? = nil

-- El Model "Elevator" (búsqueda recursiva, con caché mientras siga en Workspace).
function WorldRefs.Elevator(): Model?
	local c = cachedElevator
	if c and c:IsDescendantOf(workspace) then
		return c
	end
	local found = workspace:FindFirstChild("Elevator", true)
	if found and found:IsA("Model") then
		cachedElevator = found
		return found
	end
	return nil
end

-- Espera (hasta `timeout` segundos) a que exista; devuelve nil si no aparece.
function WorldRefs.WaitElevator(timeout: number): Model?
	local deadline = os.clock() + timeout
	while os.clock() < deadline do
		local e = WorldRefs.Elevator()
		if e then
			return e
		end
		task.wait(0.25)
	end
	return WorldRefs.Elevator()
end

return table.freeze(WorldRefs)
