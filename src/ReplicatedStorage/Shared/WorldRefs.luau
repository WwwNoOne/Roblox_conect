--!strict
-- Localiza objetos del mundo sin depender de en qué carpeta del Workspace estén (p. ej. Workspace.Lobby.Submarine o
-- Workspace.Submarine). Así se puede reorganizar el Workspace en Studio sin romper los scripts.
local WorldRefs = {}

local cachedSub: Model? = nil

-- El Model "Submarine" (búsqueda recursiva, con caché mientras siga en Workspace).
function WorldRefs.Submarine(): Model?
	local c = cachedSub
	if c and c:IsDescendantOf(workspace) then
		return c
	end
	local found = workspace:FindFirstChild("Submarine", true)
	if found and found:IsA("Model") then
		cachedSub = found
		return found
	end
	return nil
end

-- Espera (hasta `timeout` segundos) a que exista; devuelve nil si no aparece.
function WorldRefs.WaitSubmarine(timeout: number): Model?
	local deadline = os.clock() + timeout
	while os.clock() < deadline do
		local s = WorldRefs.Submarine()
		if s then
			return s
		end
		task.wait(0.25)
	end
	return WorldRefs.Submarine()
end

return table.freeze(WorldRefs)
