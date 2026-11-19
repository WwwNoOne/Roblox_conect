--!strict
-- Estamina y sprint autoritativos (sustituye al dash). El cliente solo avisa de si mantiene la tecla (SetSprint); el servidor decide
-- si corre, gasta y recupera la estamina, y lo publica en atributos del jugador (los lee SwimClient para la velocidad y SprintClient
-- para la barra): Stamina, StaminaMax, Sprinting, Exhausted. Parámetros: Config.Sprint.
-- Solo se corre en partida, fuera del submarino, vivo, escondido no y moviéndose. Al vaciarse queda agotado hasta recuperar
-- Config.Sprint.ExhaustedUntil. Fuera de partida la estamina está siempre llena. Los enemigos oyen a quien corre (MonsterService).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Runs = require(script.Parent:WaitForChild("Runs"))
local SafeZone = require(script.Parent:WaitForChild("SafeZone"))

local P = Config.Sprint
local setSprint = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("SetSprint") :: RemoteEvent

type State = {
	stamina: number,
	wants: boolean,
	sprinting: boolean,
	exhausted: boolean,
	lastSprintAt: number,
	lastRequest: number,
}

local states: { [Player]: State } = {}

local function stateOf(player: Player): State
	local s = states[player]
	if not s then
		s = { stamina = P.StaminaMax, wants = false, sprinting = false, exhausted = false, lastSprintAt = 0, lastRequest = 0 }
		states[player] = s
	end
	return s
end

local function publish(player: Player, s: State)
	player:SetAttribute("Stamina", math.floor(s.stamina * 10 + 0.5) / 10)
	player:SetAttribute("StaminaMax", P.StaminaMax)
	player:SetAttribute("Sprinting", s.sprinting)
	player:SetAttribute("Exhausted", s.exhausted)
end

setSprint.OnServerEvent:Connect(function(player: Player, held: unknown)
	if type(held) ~= "boolean" then
		return
	end
	local s = stateOf(player)
	local now = os.clock()
	if now - s.lastRequest < 0.05 then
		return -- como mucho 20 cambios por segundo
	end
	s.lastRequest = now
	s.wants = held
end)

Players.PlayerAdded:Connect(function(player)
	publish(player, stateOf(player))
end)
for _, p in Players:GetPlayers() do
	publish(p, stateOf(p))
end
Players.PlayerRemoving:Connect(function(player)
	states[player] = nil
end)

-- ¿Puede correr ahora mismo? (partida, vivo, fuera del submarino, sin esconderse, moviéndose)
local function canSprint(player: Player): boolean
	if Runs.GetByUser(player.UserId) == nil or Runs.IsUserInside(player.UserId) then
		return false
	end
	if player:GetAttribute("Hidden") == true then
		return false
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not humanoid or humanoid.Health <= 0 or not root then
		return false
	end
	if SafeZone.IsPlayerSafe(root.Position) then
		return false -- en la sala_0 no hace falta correr
	end
	return root.AssemblyLinearVelocity.Magnitude >= P.MinSpeed
end

while true do
	local dt = task.wait(P.StepSeconds)
	local now = os.clock()
	for player, s in states do
		if Runs.GetByUser(player.UserId) == nil then
			-- fuera de partida: siempre llena
			s.stamina, s.exhausted, s.sprinting, s.wants = P.StaminaMax, false, false, false
		else
			local running = s.wants and not s.exhausted and canSprint(player)
			if running then
				s.stamina = math.max(0, s.stamina - P.DrainPerSecond * dt)
				s.lastSprintAt = now
				if s.stamina <= 0 then
					s.exhausted = true
					running = false
				end
			elseif now - s.lastSprintAt >= P.RegenDelay then
				s.stamina = math.min(P.StaminaMax, s.stamina + P.RegenPerSecond * dt)
				if s.exhausted and s.stamina >= P.ExhaustedUntil then
					s.exhausted = false
				end
			end
			s.sprinting = running
		end
		publish(player, s)
	end
end
