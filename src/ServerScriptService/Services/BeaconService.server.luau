--!strict
-- Baliza del último nivel (T06): mantener E con el ProximityPrompt activa la victoria.
-- Soltar el control o alejarse interrumpe la activación (lo gestiona el propio prompt).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Types = require(Shared:WaitForChild("Types"))
local Runs = require(script.Parent:WaitForChild("Runs"))
local Assets = require(script.Parent:WaitForChild("Assets"))

local current: Instance? = nil -- baliza provisional creada por este script
local currentLight: BasePart? = nil

local function clear()
	if current then
		current:Destroy()
		current = nil
		currentLight = nil
	end
end

local function build(code: string, map: Instance)
	clear()
	local site = map:FindFirstChild("BeaconSite")
	if not site or not site:IsA("BasePart") then
		warn("[Beacon] Falta BeaconSite en " .. map.Name)
		return
	end
	-- Si Codex entrega Maps.<nivel>.Beacon (Model con Light y PromptAttachment) se usa; si no, una baliza provisional.
	local model = map:FindFirstChild("Beacon")
	if not model then
		-- Plantilla de Codex en ServerStorage.GameAssets (cualquier subcarpeta).
		local template = Assets.Find("Beacon")
		if template and template:IsA("Model") then
			local clone = template:Clone()
			local _, bounds = clone:GetBoundingBox()
			clone:PivotTo(CFrame.new(site.Position + Vector3.new(0, site.Size.Y / 2 + bounds.Y / 2, 0)))
			for _, d in clone:GetDescendants() do
				if d:IsA("BasePart") then
					d.Anchored = true
				end
			end
			clone.Parent = workspace
			model = clone
		end
	end
	local host: Instance
	local light: BasePart? = nil
	local attachment: Attachment
	if model and model:IsA("Model") then
		host = model
		light = model:FindFirstChild("Light", true) :: BasePart?
		attachment = model:FindFirstChild("PromptAttachment", true) :: Attachment
	else
		local part = Instance.new("Part")
		part.Name = "BeaconProvisional"
		part.Shape = Enum.PartType.Cylinder
		part.Size = Vector3.new(6, 2.5, 2.5)
		part.Orientation = Vector3.new(0, 0, 90)
		part.Position = site.Position + Vector3.new(0, site.Size.Y / 2 + 3, 0)
		part.Anchored = true
		part.Material = Enum.Material.Neon
		part.Color = Color3.fromRGB(255, 60, 60)
		part.Parent = workspace
		local att = Instance.new("Attachment")
		att.Parent = part
		attachment = att
		host = part
		light = part
	end
	current = if host.Parent == workspace then host else nil -- lo clonado/provisional se destruye al salir del nivel -- solo se destruye lo provisional
	currentLight = light

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Activar baliza"
	prompt.ObjectText = "Baliza"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = Config.Run.BeaconHoldSeconds
	prompt.MaxActivationDistance = 8
	prompt.RequiresLineOfSight = false
	prompt.Parent = attachment
	prompt.Triggered:Connect(function(player: Player)
		local run = Runs.GetByUser(player.UserId)
		local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if not run or run.code ~= code or run.state ~= "Level" or not humanoid or humanoid.Health <= 0 then
			return
		end
		Runs.Finish(code, "Won", "Beacon")
	end)
	if not current then
		-- Baliza de Codex: el prompt cuelga de su Attachment; se limpia al salir del nivel.
		current = prompt
	end
end

Runs.StateChanged:Connect(function(code: string, state: Types.RunState)
	local run = Runs.Get(code)
	if not run then
		return
	end
	if state == "Level" then
		local def = Config.Run.Stages[run.zone]
		if def and def.Beacon then
			local maps = workspace:FindFirstChild("Maps")
			local map = maps and maps:FindFirstChild(def.Map)
			if map then
				build(code, map)
			end
		end
	elseif state == "Won" then
		if currentLight then
			currentLight.Color = Color3.fromRGB(60, 255, 120)
		end
	elseif state == "Descending" or state == "Lost" then
		clear()
	end
end)
