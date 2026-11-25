--!strict
-- Animación del kraken (cliente): mueve con una onda los huesos de los tentáculos (Tentaculo_NN_k), las aletas (Aleta_*_k)
-- y las barbillas (Barbilla_NN_A/B) mediante Bone.Transform, que no se replica: cada cliente anima su copia.
-- La frecuencia sube con la velocidad (atributo KrakenSpeed del modelo, que pone KrakenService). Parámetros: Config.Kraken.Anim.
-- Los huesos siguen el eje Y del hueso (a lo largo del tentáculo); se balancea en X y Z con 90° de desfase para un movimiento circular.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local A = Config.Kraken.Anim

type Part = { bone: Bone, index: number, count: number, group: number, kind: string }

local model: Model? = nil
local parts: { Part } = {}
local speed = 0
local phase = 0

local function collect(m: Model)
	parts = {}
	local groups: { [string]: { [number]: Bone } } = {}
	local kinds: { [string]: string } = {}
	for _, d in m:GetDescendants() do
		if d:IsA("Bone") then
			local tent, tk = string.match(d.Name, "^Tentaculo_(%d+)_(%d+)$")
			local fin, fk = string.match(d.Name, "^Aleta_(%a_%d)_(%d+)$")
			local beard, bk = string.match(d.Name, "^Barbilla_(%d+)_(%a)$")
			if tent then
				local g = "T" .. tent
				groups[g] = groups[g] or {}
				groups[g][tonumber(tk) :: number] = d
				kinds[g] = "tentacle"
			elseif fin then
				local g = "F" .. fin
				groups[g] = groups[g] or {}
				groups[g][tonumber(fk) :: number] = d
				kinds[g] = "fin"
			elseif beard then
				local g = "B" .. beard
				groups[g] = groups[g] or {}
				groups[g][if bk == "A" then 1 else 2] = d
				kinds[g] = "beard"
			end
		end
	end
	local n = 0
	for g, list in groups do
		n += 1
		local count = 0
		for _ in list do
			count += 1
		end
		for index, bone in list do
			table.insert(parts, { bone = bone, index = index, count = count, group = n, kind = kinds[g] })
		end
	end
end

RunService.Heartbeat:Connect(function(dt)
	local current = workspace:FindFirstChild("KrakenAbisal")
	if not current or not current:IsA("Model") then
		model = nil
		return
	end
	if current ~= model then
		model = current
		speed = 0
		collect(current)
	end
	local camera = workspace.CurrentCamera
	if #parts == 0 or (camera and (camera.CFrame.Position - current:GetPivot().Position).Magnitude > A.MaxDistance) then
		return
	end
	local target = (current:GetAttribute("KrakenSpeed") :: number?) or 0
	speed += (target - speed) * (1 - math.exp(-A.Smoothing * dt))
	phase += 2 * math.pi * math.min(A.MaxHz, A.BaseHz + A.HzPerSpeed * speed) * dt

	for _, p in parts do
		local t = if p.count > 1 then (p.index - 1) / (p.count - 1) else 0
		local deg, step = A.TentacleDeg * (1 + (A.TentacleTip - 1) * t), A.TentaclePhase
		if p.kind == "fin" then
			deg, step = A.FinDeg, A.FinPhase
		elseif p.kind == "beard" then
			deg, step = A.BeardDeg, 0.5
		end
		local ph = phase - step * (p.index - 1) + p.group * 1.7 -- cada tentáculo con su propio desfase
		local amp = math.rad(deg)
		p.bone.Transform = CFrame.Angles(amp * math.sin(ph), 0, amp * math.cos(ph))
	end
end)
