--!strict
-- Conecta Rooms con Runs, RequestDescend, RunEnded y envía UpdateHUD (única fuente del HUD).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Types = require(Shared:WaitForChild("Types"))
local Rooms = require(script.Parent:WaitForChild("Rooms"))
local Runs = require(script.Parent:WaitForChild("Runs"))

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local updateHud = remotes:WaitForChild("UpdateHUD") :: RemoteEvent
local requestDescend = remotes:WaitForChild("RequestDescend") :: RemoteFunction
local runEnded = remotes:WaitForChild("RunEnded") :: RemoteEvent

Rooms.Started:Connect(function(code: string)
	local room = Rooms.Get(code)
	if room then
		Runs.Start(code, room.members)
	end
end)

Runs.StateChanged:Connect(function(code: string, state: Types.RunState)
	Rooms.SetState(code, state)
end)

Runs.Ended:Connect(function(code: string, result: string, reason: string)
	local run = Runs.Get(code)
	if not run then
		return
	end
	for _, userId in run.members do
		local p = Players:GetPlayerByUserId(userId)
		if p then
			runEnded:FireClient(p, result, reason)
		end
	end
	-- Pantalla final y vuelta a la sala (T06): los muertos reaparecen y se puede iniciar otra partida.
	task.delay(Config.Run.EndScreenSeconds, function()
		local ended = Runs.Get(code)
		if not ended then
			return
		end
		local ids = table.clone(ended.members)
		Runs.Close(code)
		Rooms.SetState(code, "Lobby")
		for _, userId in ids do
			local p = Players:GetPlayerByUserId(userId)
			local humanoid = p and p.Character and p.Character:FindFirstChildOfClass("Humanoid")
			if p and (not humanoid or humanoid.Health <= 0) then
				p:LoadCharacter()
			end
		end
	end)
end)

local lastDescend: { [Player]: number } = {}
requestDescend.OnServerInvoke = function(player: Player)
	local now = os.clock()
	if now - (lastDescend[player] or 0) < 0.5 then
		return { ok = false, err = "TOO_FAST" }
	end
	lastDescend[player] = now
	local result = Runs.RequestDescend(player.UserId)
	if result.ok and result.counting then
		local run = Runs.GetByUser(player.UserId)
		local members = if run then run.members else {}
		for _, userId in members do
			local p = Players:GetPlayerByUserId(userId)
			if p and p ~= player then
				p:SetAttribute("HudNotice", string.format("%s quiere avanzar: entren al ascensor (%d s)|%f", player.DisplayName, Config.Run.AdvanceCountdown, os.clock()))
			end
		end
	end
	return result
end
Players.PlayerRemoving:Connect(function(player)
	lastDescend[player] = nil
end)

-- Avisos del temporizador del nivel (Config.Run.LevelWarnings): una vez por umbral y nivel, a todos los miembros.
local warned: { [string]: boolean } = {}
local function warnTimer(run: Runs.Run, left: number)
	for _, threshold in Config.Run.LevelWarnings do
		local key = string.format("%s:%d:%d", run.code, run.zone, threshold)
		if left <= threshold and not warned[key] then
			warned[key] = true
			local text = if threshold >= 60
				then string.format("Quedan %d min para que el ascensor parta", threshold // 60)
				else string.format("¡Quedan %d s! Vuelvan al ascensor", threshold)
			for _, userId in run.members do
				local p = Players:GetPlayerByUserId(userId)
				if p then
					p:SetAttribute("HudNotice", string.format("%s|%f", text, os.clock()))
				end
			end
		end
	end
end

-- Bucle de simulación + HUD (4 Hz, límite del proyecto 20 Hz).
while true do
	local dt = task.wait(Config.HudUpdateInterval)
	Runs.Step(dt)
	for _, player in Players:GetPlayers() do
		local payload: Types.HudPayload = {}
		local run = Runs.GetByUser(player.UserId)
		if run then
			payload.money = run.money
			payload.runState = run.state
			payload.zone = run.zone
			local stage = Config.Run.Stages[if run.state == "Level" then run.zone else run.zone + 1]
			payload.quota = stage and stage.Quota
			payload.deposited = run.deposited
			payload.failures = run.failures
			payload.powerDone = run.powerDone
			payload.powerNeeded = run.powerNeeded
			local deadline = run.advanceDeadline
			payload.advanceIn = if deadline then math.max(0, math.ceil(deadline - os.clock())) else nil
			local left = Runs.LevelTimeLeft(run)
			payload.levelLeft = if left then math.ceil(left) else nil
			if left then
				warnTimer(run, left)
			end
		end
		updateHud:FireClient(player, payload)
	end
end
