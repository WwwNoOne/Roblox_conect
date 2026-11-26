--!strict
-- Crea los tesoros recogibles (Workspace.RunTreasure): modelo del kit de Codex (GameAssets.<Config.Economy.Kit>) según su clase, luz
-- propia y ProximityPrompt "Recoger". Lo usan EconomyHandlers (tesoros del mapa) y ObjectiveService (botín de las cajas fuertes).
-- Al recogerlo el objeto queda marcado con el atributo CollectedBy (UserId) y se borra tras Config.Objectives.PickupFxSeconds: en ese
-- tiempo ObjectiveFx (cliente) lo hace volar hacia quien lo recogió.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Economy = require(script.Parent:WaitForChild("Economy"))
local Assets = require(script.Parent:WaitForChild("Assets"))

local TreasureSpawner = {}

local PICKUP_FX_SECONDS = 0.45

local folder = Instance.new("Folder")
folder.Name = "RunTreasure"
folder.Parent = workspace
TreasureSpawner.Folder = folder

local MESSAGES: { [string]: string } = {
	INVENTORY_FULL = "Inventario lleno (4/4)",
}

local rng = Random.new()

-- Objetos del kit de recolección por clase, según su atributo ClaseSugerida.
local function kitModels(tier: string): { Model }
	local kit = Assets.Find(Config.Economy.Kit)
	local list: { Model } = {}
	if kit then
		for _, d in kit:GetDescendants() do
			if d:IsA("Model") and d:GetAttribute("ClaseSugerida") == tier then
				table.insert(list, d)
			end
		end
	end
	return list
end

local function prettyName(name: string): string
	return (string.gsub(name, "_", " "))
end

export type Options = {
	maxSize: Vector3?, -- no pasar de este tamaño (p. ej. dentro de una caja fuerte)
	yaw: number?, -- giro fijo (radianes); por defecto al azar
}

function TreasureSpawner.Clear()
	folder:ClearAllChildren()
end

-- `ground`: punto de apoyo en el suelo. El objeto se coloca encima. Devuelve el objeto creado.
function TreasureSpawner.Spawn(ground: Vector3, tier: string, opts: Options?): Instance?
	local def = (Config.Economy.Treasure :: any)[tier]
	if not def then
		return nil
	end
	local list = kitModels(tier)
	local template = if #list > 0 then list[rng:NextInteger(1, #list)] else nil
	local rootOrNil: BasePart? = nil
	local objectOrNil: Instance? = nil
	local label = "Objeto " .. tier
	local glyph: string = Config.Economy.DefaultGlyph
	if template then
		local clone = template:Clone()
		local handle = clone.PrimaryPart or clone:FindFirstChild("Handle") or clone:FindFirstChildWhichIsA("BasePart", true)
		if handle and handle:IsA("BasePart") then
			if def.Scale and def.Scale ~= 1 then
				clone:ScaleTo(clone:GetScale() * def.Scale)
			end
			local maxSize = opts and opts.maxSize
			if maxSize then
				local _, sz = clone:GetBoundingBox()
				local k = math.min(1, maxSize.X / sz.X, maxSize.Y / sz.Y, maxSize.Z / sz.Z)
				if k < 1 then
					clone:ScaleTo(clone:GetScale() * k)
				end
			end
			for _, d in clone:GetDescendants() do
				if d:IsA("BasePart") then
					d.Anchored = true
					d.CanCollide = false
				end
			end
			local box, size = clone:GetBoundingBox()
			local target = ground + Vector3.new(0, size.Y / 2 + 0.05, 0)
			clone:PivotTo(clone:GetPivot() + (target - box.Position)) -- el centro de la caja queda en el punto objetivo
			local yaw = CFrame.Angles(0, (opts and opts.yaw) or rng:NextNumber(0, math.pi * 2), 0)
			clone:PivotTo(CFrame.new(target) * yaw * CFrame.new(-target) * clone:GetPivot())
			objectOrNil = clone
			rootOrNil = handle
			label = prettyName(template.Name)
			local group = template.Parent
			glyph = (group and (Config.Economy.KitGlyphs :: any)[group.Name]) or glyph
		else
			clone:Destroy()
		end
	end
	if not rootOrNil or not objectOrNil then
		local part = Instance.new("Part") -- provisional (sin kit)
		part.Name = "Objeto_" .. tier
		part.Size = def.Size
		part.Color = def.Color
		part.Material = Enum.Material.Neon
		part.CFrame = CFrame.new(ground + Vector3.new(0, def.Size.Y / 2 + 0.2, 0))
		objectOrNil = part
		rootOrNil = part
	end
	local object = objectOrNil :: Instance
	local root = rootOrNil :: BasePart
	root.Anchored = true
	root.CanCollide = false
	object:SetAttribute("Size", tier)
	object:SetAttribute("Value", def.Value)

	-- Luz propia: sin ella el objeto es casi invisible en la oscuridad (ObjectiveFx la hace latir).
	local glow = Instance.new("PointLight")
	glow.Name = "TreasureGlow"
	glow.Color = def.Color
	glow.Range = Config.TreasureGlowRange
	glow.Brightness = Config.TreasureGlowBrightness
	glow.Shadows = false
	glow.Parent = root

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Recoger"
	prompt.ObjectText = string.format("%s  ($%d)", label, def.Value)
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0.4
	prompt.MaxActivationDistance = 8
	prompt.RequiresLineOfSight = false
	prompt.Parent = root
	prompt.Triggered:Connect(function(player: Player)
		if not object.Parent or object:GetAttribute("CollectedBy") then
			return -- ya recogido por otro jugador
		end
		local result = Economy.Pickup(player, tier, glyph)
		if result.ok then
			prompt.Enabled = false
			glow.Enabled = false
			object:SetAttribute("CollectedBy", player.UserId)
			task.delay(PICKUP_FX_SECONDS, function()
				object:Destroy()
			end)
		elseif result.err and MESSAGES[result.err] then
			player:SetAttribute("HudNotice", MESSAGES[result.err] .. "|" .. tostring(os.clock()))
		end
	end)
	object.Parent = folder
	return object
end

return TreasureSpawner
