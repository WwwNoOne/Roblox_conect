--!strict
-- Apaga (en todas las calidades; más cerca en la baja) las luces locales (PointLight/SpotLight) a más de Config.LowQualityLightCullDistance de la cámara
-- y las restaura al volver a media/alta. Reduce la carga de luces dinámicas en móvil sin tocar el mapa.
-- Ignora el rig de linterna y las luces del personaje propio.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local QualityTier = require(script.Parent:WaitForChild("QualityTier"))

local lights: { [Light]: boolean } = {} -- luz -> true si la apagamos nosotros
local accum = 0

local function track(inst: Instance)
	if (inst:IsA("PointLight") or inst:IsA("SpotLight")) and not lights[inst] then
		lights[inst] = false
	end
end

local function untrack(inst: Instance)
	if inst:IsA("Light") then
		lights[inst] = nil
	end
end

for _, d in workspace:GetDescendants() do
	track(d)
end
workspace.DescendantAdded:Connect(track)
workspace.DescendantRemoving:Connect(untrack)

local function ignored(light: Light): boolean
	if light:FindFirstAncestor("LampRigs") then
		return true
	end
	local character = Players.LocalPlayer.Character
	return character ~= nil and light:IsDescendantOf(character)
end

local function restoreAll()
	for light, culled in lights do
		if culled then
			light.Enabled = true
			lights[light] = false
		end
	end
end

QualityTier.Changed:Connect(restoreAll) -- el siguiente barrido vuelve a apagar según la distancia del nuevo nivel

game:GetService("RunService").Heartbeat:Connect(function(dt)
	accum += dt
	if accum < Config.LowQualityLightCullInterval then
		return
	end
	accum = 0
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local camPos = camera.CFrame.Position
	local maxDist = if QualityTier.IsLow then Config.LowQualityLightCullDistance else Config.LightCullDistance
	for light, culled in lights do
		local parent = light.Parent
		if parent and parent:IsA("BasePart") and not ignored(light) then
			local far = (parent.Position - camPos).Magnitude > maxDist
			if far and light.Enabled then
				light.Enabled = false
				lights[light] = true
			elseif not far and culled then
				light.Enabled = true
				lights[light] = false
			end
		end
	end
end)
