--!strict
-- Construye el mundo al arrancar el servidor: genera el nivel con RoomGenerator (sala_0 fija arriba, sala grande debajo y las
-- salas pequeñas ramificadas), lo deja en Workspace.NivelGenerado y avisa con el atributo Workspace.WorldReady (la pantalla de
-- carga espera a ese atributo). Las plantillas (Workspace.Salas_grandes, Salas_normales y Pasillo) pasan a ServerStorage.Plantillas.
-- Parámetros: Config.Level. La semilla queda en el atributo Workspace.LevelSeed.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Generator = require(script.Parent:WaitForChild("RoomGenerator"))
local Maze = require(script.Parent:WaitForChild("MazeGenerator"))
local LevelState = require(script.Parent:WaitForChild("LevelState"))

local P = Config.Level
local M = Config.Maze

local function fail(message: string)
	warn("[Nivel] " .. message)
	workspace:SetAttribute("WorldReady", true) -- que la pantalla de carga no se quede esperando
end

-- Busca un Model por nombre (puede haber un Folder con el mismo nombre por el medio).
local function findModel(root: Instance?, name: string): Model?
	if not root then
		return nil
	end
	for _, d in root:GetDescendants() do
		if d.Name == name and d:IsA("Model") then
			return d
		end
	end
	return nil
end

-- Laberinto de piezas (pasillos, pozos verticales y salas): sala_0 arriba, el pozo baja a una red de piezas con extremos tapados.
local function generateMaze(dock: BasePart, stash: Instance)
	local folders: { Instance } = {}
	for _, name in { "Pasillo", "Salas" } do
		local f = workspace:FindFirstChild(name)
		if f then
			table.insert(folders, f)
		end
	end
	if #folders == 0 then
		return fail("Faltan Workspace.Pasillo / Workspace.Salas (piezas del laberinto)")
	end
	-- las plantillas salen del mundo (tambien las salas antiguas y las criaturas: MonsterService las busca en ServerStorage.Plantillas)
	for _, name in { "Salas_grandes", "Salas_normales", "Pasillo", "Salas", "Creatures" } do
		local f = workspace:FindFirstChild(name)
		if f then
			f.Parent = stash
		end
	end
	local templates: { [string]: Model } = {}
	local defs: { Maze.PieceDef } = {}
	for _, info in M.Pieces do
		local model: Model? = nil
		for _, folder in folders do
			model = model or findModel(folder, info.Name)
		end
		if model and model:FindFirstChild("Conexiones") then
			templates[info.Name] = model
			local def = Maze.ReadPiece(model, info.Kind)
			def.weight = info.Weight
			table.insert(defs, def)
		else
			warn("[Nivel] Falta la pieza " .. info.Name .. " (o no tiene Conexiones)")
		end
	end
	if #defs == 0 then
		return fail("No hay piezas de laberinto")
	end
	local ok, err = pcall(function()
		local seed = P.Seed or os.time()
		workspace:SetAttribute("LevelSeed", seed)
		local entry = dock.Position + P.Sala0Port
		local blockers = {
			{ center = dock.Position + M.Sala0BoxCenter, half = M.Sala0BoxHalf },
		}
		local plan = Maze.Plan(seed, defs, entry, {
			pieces = M.Count,
			maxLinearRun = M.MaxLinearRun,
			maxVertical = M.MaxVertical,
			maxRooms = M.MaxRooms,
			blockers = blockers,
		})
		for _, problem in Maze.Validate(plan, M.MaxLinearRun) do
			warn("[Nivel] " .. problem)
		end
		local old = workspace:FindFirstChild("NivelGenerado")
		if old then
			old:Destroy()
		end
		workspace.Terrain:Clear()
		local container = Instance.new("Folder")
		container.Name = "NivelGenerado"
		container.Parent = workspace
		local started = os.clock()
		local counts = Maze.Build(plan, templates, container, { water = true, inner = M.Inner, outer = M.Outer })
		LevelState.plan = plan
		LevelState.nav = Maze.NavGraph(plan)
		LevelState.container = container
		LevelState.entry = entry
		print(string.format("[Nivel] laberinto semilla %d: %d piezas, %d extremos tapados, %d vertices de navegacion, %.1fs", seed, counts.pieces, counts.caps, #LevelState.nav.points, os.clock() - started))
	end)
	if not ok then
		warn("[Nivel] Error al generar el laberinto: " .. tostring(err))
	end
	workspace:SetAttribute("WorldReady", true)
end

local function generate()
	-- Apartar lo que solo sirve para pruebas (Workspace.Assets, Zona_Prueba...): no debe cargarse ni interferir con el nivel.
	local stash = ServerStorage:FindFirstChild("Plantillas") or Instance.new("Folder")
	stash.Name = "Plantillas"
	stash.Parent = ServerStorage
	for _, name in P.Stash do
		local item = workspace:FindFirstChild(name)
		if item then
			item.Parent = stash
		end
	end
	local sala0 = workspace:FindFirstChild("Sala_0")
	local dock = sala0 and sala0:FindFirstChild("SubDock", true)
	if not dock or not dock:IsA("BasePart") then
		return fail("Falta Workspace.Sala_0.SubDock")
	end
	if P.Mode == "maze" then
		return generateMaze(dock, stash)
	end
	local bigFolder = workspace:FindFirstChild("Salas_grandes")
	local smallFolder = workspace:FindFirstChild("Salas_normales")
	local corridorFolder = workspace:FindFirstChild("Pasillo")
	local bigModel = findModel(bigFolder, P.BigName)
	local corridor = findModel(corridorFolder, "Pasillo")
	if not bigModel or not corridor or not bigFolder or not smallFolder or not corridorFolder then
		return fail("Faltan plantillas (Salas_grandes." .. P.BigName .. ", Salas_normales o Pasillo)")
	end

	-- Plantillas fuera del mundo: así no se ven ni estorban durante la partida.
	local store = ServerStorage:FindFirstChild("Plantillas") or Instance.new("Folder")
	store.Name = "Plantillas"
	store.Parent = ServerStorage
	for _, f in { bigFolder, smallFolder, corridorFolder } do
		f.Parent = store
	end

	local smallModels: { Model } = {}
	for _, c in smallFolder:GetChildren() do
		if c:IsA("Model") then
			table.insert(smallModels, c)
		end
	end
	if #smallModels == 0 then
		return fail("Salas_normales no tiene ninguna sala")
	end

	local ok, err = pcall(function()
		local origin = dock.Position
		local smallDefs: { Generator.RoomDef } = {}
		local rooms: { [string]: Model } = {}
		for _, m in smallModels do
			table.insert(smallDefs, Generator.ReadDef(m, "small", P.SmallWall, P.SmallWater, P.Scale))
			rooms[m.Name] = m
		end
		local bigDef = Generator.ReadDef(bigModel, "big", P.BigWall, P.BigWater, P.Scale)
		rooms[bigDef.name] = bigModel
		local sala0Def: Generator.RoomDef = {
			name = "Sala_0",
			kind = "sala0",
			ports = { ["Y-"] = P.Sala0Port },
			half = P.Sala0Half,
			wall = 0,
			water = nil,
			centerInPivot = Vector3.zero,
		}
		local seed = P.Seed or os.time()
		workspace:SetAttribute("LevelSeed", seed)
		local plan = Generator.Plan(seed, { sala0 = sala0Def, big = bigDef, smalls = smallDefs }, origin, {
			smalls = P.Smalls,
			corridor = P.Corridor * P.Scale,
			scale = P.Scale,
			bigDoors = P.BigDoors,
			verticalMax = P.VerticalMax,
		})
		local problems = Generator.Validate(plan)
		for _, problem in problems do
			warn("[Nivel] " .. problem)
		end
		local old = workspace:FindFirstChild("NivelGenerado")
		if old then
			old:Destroy()
		end
		workspace.Terrain:Clear()
		local container = Instance.new("Folder")
		container.Name = "NivelGenerado"
		container.Parent = workspace
		local started = os.clock()
		local counts = Generator.Build(plan, { rooms = rooms, corridor = corridor }, container, true)
		print(string.format("[Nivel] semilla %d: %d salas (%d pequeñas de %d), %d pasillos, %d tapones, %.1fs", seed, counts.rooms, plan.placedSmall, P.Smalls, counts.corridors, counts.plugs, os.clock() - started))
	end)
	if not ok then
		warn("[Nivel] Error al generar: " .. tostring(err))
	end
	workspace:SetAttribute("WorldReady", true)
end

generate()
