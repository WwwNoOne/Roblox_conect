--!strict
-- Primera persona realista, fija. Parámetros: Config.FirstPerson.
--   * Cámara bloqueada en primera persona (sin zoom).
--   * Se ve el cuerpo del personaje (brazos, manos, torso y piernas al mirar abajo) pero no la cabeza, el pelo, los sombreros ni lo que
--     lleve en la cara o el cuello, que taparían la vista. Las manos salen al sostener cosas.
--   * El cursor está oculto y bloqueado en el centro; en su lugar hay un puntito. Se libera solo (con el cursor visible y el puntito
--     oculto) mientras haya un panel que lo necesite (Shop, ElevatorPanel) o se mantenga Alt izquierdo. En móvil no hay cursor: los paneles
--     se tocan y el puntito marca el centro.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local F = Config.FirstPerson

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- ===== Modo de cámara =====
local function lockFirstPerson()
	player.CameraMode = Enum.CameraMode.LockFirstPerson
	player.CameraMinZoomDistance = 0.5
	player.CameraMaxZoomDistance = 0.5
end
lockFirstPerson()

-- ===== Puntito central =====
local reticle = Instance.new("ScreenGui")
reticle.Name = "Mira"
reticle.ResetOnSpawn = false
reticle.IgnoreGuiInset = true
reticle.DisplayOrder = 40
reticle.Parent = playerGui
local dot = Instance.new("Frame")
dot.AnchorPoint = Vector2.new(0.5, 0.5)
dot.Position = UDim2.fromScale(0.5, 0.5)
dot.Size = UDim2.fromOffset(F.DotSize, F.DotSize)
dot.BackgroundColor3 = F.DotColor
dot.BackgroundTransparency = F.DotTransparency
dot.BorderSizePixel = 0
dot.Parent = reticle
local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(1, 0)
corner.Parent = dot
local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(10, 20, 30)
stroke.Thickness = 1
stroke.Transparency = 0.35
stroke.Parent = dot

-- ===== Cursor libre =====
-- Un TextButton Modal libera el ratón mientras es visible (truco estándar de Roblox para primera persona).
local cursorGui = Instance.new("ScreenGui")
cursorGui.Name = "CursorLibre"
cursorGui.ResetOnSpawn = false
cursorGui.Enabled = false
cursorGui.DisplayOrder = -10
cursorGui.Parent = playerGui
local modal = Instance.new("TextButton")
modal.Size = UDim2.fromOffset(1, 1)
modal.BackgroundTransparency = 1
modal.Text = ""
modal.Modal = true
modal.Parent = cursorGui

local freed = false

local function wantCursor(): boolean
	if UserInputService:IsKeyDown(F.CursorKey) then
		return true
	end
	for _, name in F.ModalGuis do
		local g = playerGui:FindFirstChild(name)
		if g and g:IsA("ScreenGui") and g.Enabled then
			return true
		end
	end
	return false
end

RunService:BindToRenderStep("FirstPersonCursor", Enum.RenderPriority.Camera.Value + 2, function()
	local want = wantCursor()
	if want ~= freed then
		freed = want
		cursorGui.Enabled = want
		dot.Visible = not want
		-- Classic con zoom fijo en 0,5 sigue siendo primera persona, pero no fuerza el ratón al centro
		player.CameraMode = if want then Enum.CameraMode.Classic else Enum.CameraMode.LockFirstPerson
	end
	if freed then
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		UserInputService.MouseIconEnabled = true
	end
end)

-- ===== Cuerpo visible, sin cabeza ni accesorios de la cara =====
local HIDE_ACCESSORY_PARTS = { "Hat", "Hair", "Face", "Neck" } -- si el Attachment de su Handle contiene alguno, se oculta
local tracked: { [Instance]: boolean } = {} -- Instance -> true = ocultar (LocalTransparencyModifier 1), false = mostrar

local function shouldHide(inst: Instance): boolean?
	if inst:IsA("BasePart") then
		if inst.Name == "Head" then
			return true
		end
		local accessory = inst:FindFirstAncestorWhichIsA("Accessory")
		if accessory then
			for _, a in inst:GetChildren() do
				if a:IsA("Attachment") then
					for _, key in HIDE_ACCESSORY_PARTS do
						if string.find(a.Name, key, 1, true) then
							return true
						end
					end
				end
			end
			return false
		end
		if inst.Name == "HumanoidRootPart" then
			return nil
		end
		return false
	elseif (inst:IsA("Decal") or inst:IsA("Texture")) and inst.Parent and inst.Parent.Name == "Head" then
		return true
	end
	return nil
end

local function track(inst: Instance)
	local hide = shouldHide(inst)
	if hide ~= nil then
		tracked[inst] = hide
	end
end

local characterConnections: { RBXScriptConnection } = {}
local function watchCharacter(character: Model)
	lockFirstPerson()
	for _, c in characterConnections do
		c:Disconnect()
	end
	table.clear(characterConnections)
	table.clear(tracked)
	for _, d in character:GetDescendants() do
		track(d)
	end
	table.insert(characterConnections, character.DescendantAdded:Connect(function(d)
		task.defer(track, d) -- el Attachment del accesorio puede llegar después del Handle
	end))
	table.insert(characterConnections, character.DescendantRemoving:Connect(function(d)
		tracked[d] = nil
	end))
	local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	if humanoid then
		humanoid.CameraOffset = F.CameraOffset
	end
end
if player.Character then
	task.spawn(watchCharacter, player.Character)
end
player.CharacterAdded:Connect(watchCharacter)

RunService:BindToRenderStep("FirstPersonBody", Enum.RenderPriority.Camera.Value + 1, function()
	for inst, hide in tracked do
		local target = if hide then 1 else 0
		if inst:IsA("BasePart") then
			if inst.LocalTransparencyModifier ~= target then
				inst.LocalTransparencyModifier = target
			end
		elseif inst:IsA("Decal") or inst:IsA("Texture") then
			if inst.LocalTransparencyModifier ~= target then
				inst.LocalTransparencyModifier = target
			end
		end
	end
end)
