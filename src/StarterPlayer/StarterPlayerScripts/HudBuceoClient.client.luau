--!strict
-- Conecta la interfaz que diseñó Codex (StarterGui.Abismo_HUD_Buceo, que solo existe en Studio) con los datos reales:
--   * Vida: Humanoid.Health del jugador (en %).
--   * Oxígeno: atributos de jugador Oxygen / OxygenMax (OxygenService), en % con el umbral crítico del atributo
--     UmbralOxigenoCritico (25 %) en rojo.
--   * Objetos recolectados: CarryCount / CarryCapacity y CarryGlyphs (iconos por objeto, ver Config.Economy.KitGlyphs).
-- La interfaz trae dos diseños, `PC` y `Movil`; se muestra el que toca según el dispositivo. Los iconos salen de una hoja de sprites
-- (ImageRectOffset); la correspondencia glifo -> recorte se lee de los propios iconos de ejemplo (atributo `Glifo`), así que si
-- Codex cambia la hoja basta con que mantenga ese atributo. Sin la interfaz, DiveHud dibuja el HUD antiguo (respaldo).
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local gui = playerGui:WaitForChild("Abismo_HUD_Buceo", 8) :: ScreenGui?
if not gui then
	return -- DiveHud se encarga del respaldo
end
local root = gui :: ScreenGui
root.Enabled = true -- Codex la deja desactivada en StarterGui para no taparla en Studio

local CRITICAL_FALLBACK = 25
local LOW_LIFE = 30
local RED = Color3.fromRGB(255, 80, 80)

-- ===== Hoja de iconos: glifo -> (offset, size) =====
local glyphs: { [string]: { offset: Vector2, size: Vector2 } } = {}
for _, d in root:GetDescendants() do
	local g = d:GetAttribute("Glifo")
	if type(g) == "string" and d:IsA("ImageLabel") and glyphs[g] == nil then
		glyphs[g] = { offset = d.ImageRectOffset, size = d.ImageRectSize }
	end
end

local function setIcon(icon: ImageLabel, glyph: string)
	local g = glyphs[glyph] or glyphs.empty
	if g then
		icon.ImageRectOffset = g.offset
		icon.ImageRectSize = g.size
	end
	icon:SetAttribute("Glifo", glyph)
end

-- ===== Elementos de cada diseño =====
type Meter = { fill: Frame, text: TextLabel, color: Color3 }
type Layout = {
	frame: Frame,
	life: Meter?,
	oxygen: Meter?,
	count: TextLabel?,
	slots: { Frame },
}

-- Busca un descendiente siguiendo una ruta de nombres (nil si falta alguno).
local function path(from: Instance?, ...: string): Instance?
	local current = from
	for _, name in { ... } do
		current = current and current:FindFirstChild(name)
	end
	return current
end

local function findMeter(panel: Instance?, name: string): Meter?
	local fill = path(panel, name, "Medidor", "Relleno")
	local text = path(panel, name, "EtiquetaYValor", "Porcentaje")
	if fill and fill:IsA("Frame") and text and text:IsA("TextLabel") then
		return { fill = fill, text = text, color = fill.BackgroundColor3 }
	end
	return nil
end

local function buildLayout(name: string): Layout?
	local frame = root:FindFirstChild(name)
	if not frame or not frame:IsA("Frame") then
		return nil
	end
	local state = frame:FindFirstChild("EstadoDelBuzo")
	local objects = frame:FindFirstChild("ObjetosRecolectados")
	local slots: { Frame } = {}
	local holder = objects and objects:FindFirstChild("Ranuras")
	if holder then
		for i = 1, 16 do
			local s = holder:FindFirstChild("Ranura_" .. i)
			if s and s:IsA("Frame") then
				table.insert(slots, s)
			end
		end
	end
	local count = path(objects, "EtiquetaYCapacidad", "Ocupacion")
	return {
		frame = frame,
		life = findMeter(state, "Vida"),
		oxygen = findMeter(state, "Oxigeno"),
		count = if count and count:IsA("TextLabel") then count else nil,
		slots = slots,
	}
end

local layouts: { Layout } = {}
for _, name in { "PC", "Movil" } do
	local l = buildLayout(name)
	if l then
		table.insert(layouts, l)
	end
end

-- Qué diseño se ve: táctil sin teclado = móvil.
local function applyDevice()
	local mobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	for _, l in layouts do
		l.frame.Visible = (l.frame.Name == "Movil") == mobile
	end
end
applyDevice()
UserInputService:GetPropertyChangedSignal("KeyboardEnabled"):Connect(applyDevice)
UserInputService.LastInputTypeChanged:Connect(applyDevice)

-- ===== Actualización =====
local function setMeter(m: Meter?, ratio: number, critical: boolean)
	if not m then
		return
	end
	ratio = math.clamp(ratio, 0, 1)
	m.fill.Size = UDim2.new(ratio, 0, m.fill.Size.Y.Scale, m.fill.Size.Y.Offset)
	m.text.Text = string.format("%d %%", math.floor(ratio * 100 + 0.5))
	m.fill.BackgroundColor3 = if critical then RED else m.color
end

local function refresh()
	-- vida
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	local life = if humanoid and humanoid.MaxHealth > 0 then humanoid.Health / humanoid.MaxHealth else 1
	-- oxígeno
	local o2, o2Max = player:GetAttribute("Oxygen"), player:GetAttribute("OxygenMax")
	local oxy = if type(o2) == "number" and type(o2Max) == "number" and o2Max > 0 then o2 / o2Max else 1
	local threshold = root:GetAttribute("UmbralOxigenoCritico")
	local criticalAt = (if type(threshold) == "number" then threshold else CRITICAL_FALLBACK) / 100
	-- objetos
	local carry = player:GetAttribute("CarryCount")
	local capacity = player:GetAttribute("CarryCapacity")
	local n = if type(carry) == "number" then carry else 0
	local cap = if type(capacity) == "number" and capacity > 0 then capacity else (root:GetAttribute("CapacidadBase") :: number? or 4)
	local glyphAttr = player:GetAttribute("CarryGlyphs")
	local list = if type(glyphAttr) == "string" and glyphAttr ~= "" then string.split(glyphAttr, ",") else {}

	for _, l in layouts do
		setMeter(l.life, life, life <= LOW_LIFE / 100)
		setMeter(l.oxygen, oxy, oxy <= criticalAt)
		if l.count then
			l.count.Text = string.format("%d / %d", n, cap)
		end
		for i, slot in l.slots do
			slot.Visible = i <= cap
			local occupied = i <= n
			slot:SetAttribute("Ocupada", occupied)
			local icon = slot:FindFirstChild("Icono")
			if icon and icon:IsA("ImageLabel") then
				setIcon(icon, if occupied then (list[i] or "gauge") else "empty")
				icon.ImageTransparency = if occupied then 0 else 0.55
			end
		end
	end
end

refresh()
for _, attr in { "Oxygen", "OxygenMax", "CarryCount", "CarryCapacity", "CarryGlyphs" } do
	player:GetAttributeChangedSignal(attr):Connect(refresh)
end

local healthConnection: RBXScriptConnection? = nil
local function watchCharacter(character: Model)
	if healthConnection then
		healthConnection:Disconnect()
	end
	local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	if humanoid then
		healthConnection = humanoid.HealthChanged:Connect(refresh)
		refresh()
	end
end
if player.Character then
	task.spawn(watchCharacter, player.Character)
end
player.CharacterAdded:Connect(watchCharacter)
