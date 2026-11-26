--!strict
-- Animación 2.5D de criaturas (Sprite Sheets + balanceo + sombra en el suelo) y Screamer 2D multicapa (T05; ver docs/criaturas.md).
-- Todo corre en el cliente a 60 FPS sin tráfico de red extra: lee los modelos etiquetados con "ProcCreature" y su atributo `Estado`.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Sfx = require(Shared:WaitForChild("Sfx"))
local creatureScreamer = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("CreatureScreamer") :: RemoteEvent

local player = Players.LocalPlayer

-- ===== Animación 2.5D de criaturas en el mundo =====
type Track = {
	model: Model,
	root: BasePart,
	bodyBb: BillboardGui?,
	bodyImg: ImageLabel?,
	eyesBb: BillboardGui?,
	eyesImg: ImageLabel?,
	baseOffset: Vector3,
	baseEyesOffset: Vector3,
	cols: number,
	rows: number,
	fps: number,
	cellW: number,
	cellH: number,
	lastPos: Vector3,
	phase: number,
	shadow: Part?,
	whisper: Sound?,
}

local tracks: { [Model]: Track } = {}

-- Fila del sprite sheet (0-indexed) según el estado publicado por MonsterService.
local ROW_BY_STATE: { [string]: number } = {
	Idle = 0,
	StalkWatch = 0,
	AmbushWait = 0,
	Cooldown = 0,
	Patrol = 1,
	Search = 1,
	Investigate = 1,
	StalkMove = 1,
	AmbushMove = 1,
	Chase = 2,
	Flee = 2,
	Stare = 1, -- SujetoFeliz observando (fila de observación)
	Charge = 2, -- SujetoFeliz embistiendo (fila de avance)
	FinalChase = 2, -- Acosador del tramo final persiguiendo
	Windup = 3,
	Lunge = 3,
	Recover = 3,
	AmbushStrike = 3,
}

local function createFloorShadow(root: BasePart): Part
	local shadow = Instance.new("Part")
	shadow.Name = "CreatureFloorShadow"
	shadow.Shape = Enum.PartType.Cylinder
	shadow.Size = Vector3.new(0.08, 4.8, 4.8)
	shadow.Color = Color3.fromRGB(8, 8, 10)
	shadow.Material = Enum.Material.SmoothPlastic
	shadow.Transparency = 0.45
	shadow.Anchored = true
	shadow.CanCollide = false
	shadow.CanQuery = false
	shadow.CanTouch = false
	shadow.CastShadow = false
	shadow.Parent = root
	return shadow
end

local function setupTrack(model: Model)
	if tracks[model] then
		return
	end
	local root = model.PrimaryPart or model:FindFirstChild("Root")
	if not root or not root:IsA("BasePart") then
		return
	end
	local bodyBb = root:FindFirstChild("BodyBillboard")
	local bodyImg = bodyBb and bodyBb:FindFirstChild("Sprite")
	local eyesBb = root:FindFirstChild("EyesBillboard")
	local eyesImg = eyesBb and eyesBb:FindFirstChild("Eyes")

	local cols = math.max(1, tonumber(model:GetAttribute("SpriteCols")) or 4)
	local rows = math.max(1, tonumber(model:GetAttribute("SpriteRows")) or 4)
	local fps = math.max(1, tonumber(model:GetAttribute("AnimFps")) or 12)

	local cellW = math.floor(1024 / cols)
	local cellH = math.floor(1024 / rows)
	if bodyImg and bodyImg:IsA("ImageLabel") then
		if bodyImg.ImageRectSize.X > 0 then
			cellW = bodyImg.ImageRectSize.X
		end
		if bodyImg.ImageRectSize.Y > 0 then
			cellH = bodyImg.ImageRectSize.Y
		end
		bodyImg.ImageRectSize = Vector2.new(cellW, cellH)
	end
	if eyesImg and eyesImg:IsA("ImageLabel") then
		eyesImg.ImageRectSize = Vector2.new(cellW, cellH)
	end

	local shadow = createFloorShadow(root)

	-- Susurro 3D opcional para el Acechador al esperar escondido
	local whisper: Sound? = nil
	if model:GetAttribute("Category") == "Ambusher" then
		local tmpl = Sfx.Find(Config.Sfx.CreatureWhisper)
		if tmpl then
			local s = tmpl:Clone()
			s.Looped = true
			s.Volume = 0
			s.RollOffMode = Enum.RollOffMode.Linear
			s.RollOffMaxDistance = 26
			s.RollOffMinDistance = 4
			s.Parent = root
			s:Play()
			whisper = s
		end
	end

	tracks[model] = {
		model = model,
		root = root,
		bodyBb = if bodyBb and bodyBb:IsA("BillboardGui") then bodyBb else nil,
		bodyImg = if bodyImg and bodyImg:IsA("ImageLabel") then bodyImg else nil,
		eyesBb = if eyesBb and eyesBb:IsA("BillboardGui") then eyesBb else nil,
		eyesImg = if eyesImg and eyesImg:IsA("ImageLabel") then eyesImg else nil,
		baseOffset = if bodyBb and bodyBb:IsA("BillboardGui") then bodyBb.StudsOffset else Vector3.zero,
		baseEyesOffset = if eyesBb and eyesBb:IsA("BillboardGui") then eyesBb.StudsOffset else Vector3.zero,
		cols = cols,
		rows = rows,
		fps = fps,
		cellW = cellW,
		cellH = cellH,
		lastPos = root.Position,
		phase = math.random() * 10,
		shadow = shadow,
		whisper = whisper,
	}
end

for _, inst in CollectionService:GetTagged("ProcCreature") do
	if inst:IsA("Model") then
		setupTrack(inst)
	end
end
CollectionService:GetInstanceAddedSignal("ProcCreature"):Connect(function(inst)
	if inst:IsA("Model") then
		setupTrack(inst)
	end
end)
CollectionService:GetInstanceRemovedSignal("ProcCreature"):Connect(function(inst)
	if inst:IsA("Model") then
		tracks[inst] = nil
	end
end)

local shadowParams = RaycastParams.new()
shadowParams.FilterType = Enum.RaycastFilterType.Exclude
shadowParams.RespectCanCollide = true

RunService.RenderStepped:Connect(function(dt)
	local now = os.clock()
	for model, t in tracks do
		if not model.Parent or not t.root.Parent then
			tracks[model] = nil
			continue
		end
		local state = (model:GetAttribute("Estado") :: string?) or "Idle"
		local hidden = state == "Hidden" or t.root.Position.Y < -500

		if t.shadow then
			if hidden then
				t.shadow.Transparency = 1
			else
				local excl: { Instance } = { model }
				if player.Character then
					table.insert(excl, player.Character)
				end
				shadowParams.FilterDescendantsInstances = excl
				local hit = workspace:Raycast(t.root.Position + Vector3.new(0, 1, 0), Vector3.new(0, -12, 0), shadowParams)
				if hit then
					t.shadow.Transparency = if state == "AmbushWait" then 0.65 else 0.42
					t.shadow.CFrame = CFrame.new(hit.Position + Vector3.new(0, 0.04, 0)) * CFrame.Angles(0, 0, math.pi / 2)
				else
					t.shadow.Transparency = 1
				end
			end
		end

		if t.whisper then
			t.whisper.Volume = if state == "AmbushWait" then 0.25 else 0
		end

		if hidden then
			continue
		end

		-- Velocidad horizontal para modular cabalgata y balanceo
		local pos = t.root.Position
		local speed = Vector3.new(pos.X - t.lastPos.X, 0, pos.Z - t.lastPos.Z).Magnitude / math.max(dt, 1e-3)
		t.lastPos = pos

		local row = math.min(t.rows - 1, ROW_BY_STATE[state] or 0)
		local speedMul = if state == "Chase" or state == "Flee" then 1.45
			elseif state == "Windup" or state == "Lunge" or state == "Charge" then 1.8
			else 0.85
		t.phase += dt * t.fps * speedMul
		local col = math.floor(t.phase) % t.cols
		local rectOffset = Vector2.new(col * t.cellW, row * t.cellH)

		local moveFactor = math.clamp(speed / 24, 0, 1.3)
		local bobY = math.abs(math.sin(now * (7 + moveFactor * 5))) * (0.06 + 0.35 * moveFactor)
		local swayX = math.sin(now * 5.5) * 0.14 * moveFactor
		local rotDeg = math.sin(now * 6) * (1.2 + 5.5 * moveFactor)
		if state == "Windup" or state == "Lunge" or state == "AmbushStrike" or state == "Charge" then
			swayX += (math.random() - 0.5) * 0.28
			bobY += (math.random() - 0.5) * 0.18
			rotDeg += (math.random() - 0.5) * 7
		end

		local dynOffset = Vector3.new(swayX, bobY, 0)
		if t.bodyBb and t.bodyImg then
			t.bodyBb.StudsOffset = t.baseOffset + dynOffset
			t.bodyImg.ImageRectOffset = rectOffset
			t.bodyImg.Rotation = rotDeg
		end
		if t.eyesBb and t.eyesImg then
			t.eyesBb.StudsOffset = t.baseEyesOffset + dynOffset
			t.eyesImg.ImageRectOffset = rectOffset
			t.eyesImg.Rotation = rotDeg
		end
	end
end)

-- ===== Screamer 2D animado multicapa =====
local screamerGui = Instance.new("ScreenGui")
screamerGui.Name = "ScreamerFx"
screamerGui.ResetOnSpawn = false
screamerGui.IgnoreGuiInset = true
screamerGui.DisplayOrder = 65
screamerGui.Enabled = false
screamerGui.Parent = player:WaitForChild("PlayerGui")

local backdrop = Instance.new("Frame")
backdrop.Size = UDim2.fromScale(1, 1)
backdrop.BackgroundColor3 = Color3.fromRGB(10, 0, 0)
backdrop.BackgroundTransparency = 1
backdrop.BorderSizePixel = 0
backdrop.Parent = screamerGui

local flash = Instance.new("Frame")
flash.Size = UDim2.fromScale(1, 1)
flash.BackgroundColor3 = Color3.fromRGB(255, 235, 225)
flash.BackgroundTransparency = 1
flash.BorderSizePixel = 0
flash.ZIndex = 10
flash.Parent = screamerGui

local holder = Instance.new("Frame")
holder.AnchorPoint = Vector2.new(0.5, 0.5)
holder.Position = UDim2.fromScale(0.5, 0.5)
holder.Size = UDim2.fromScale(0.9, 0.9)
holder.BackgroundTransparency = 1
holder.ZIndex = 4
holder.Parent = screamerGui

local aspect = Instance.new("UIAspectRatioConstraint")
aspect.AspectRatio = 1
aspect.Parent = holder

local function makeLayer(z: number, color: Color3, alpha: number): ImageLabel
	local img = Instance.new("ImageLabel")
	img.AnchorPoint = Vector2.new(0.5, 0.5)
	img.Position = UDim2.fromScale(0.5, 0.5)
	img.Size = UDim2.fromScale(1, 1)
	img.BackgroundTransparency = 1
	img.ScaleType = Enum.ScaleType.Fit
	img.ImageColor3 = color
	img.ImageTransparency = alpha
	img.ZIndex = z
	img.Parent = holder
	return img
end

local glitchRed = makeLayer(2, Color3.fromRGB(255, 55, 55), 0.45)
local glitchCyan = makeLayer(3, Color3.fromRGB(70, 230, 255), 0.45)
local mainSprite = makeLayer(5, Color3.new(1, 1, 1), 0)

local scanBars: { Frame } = {}
for i = 1, 5 do
	local bar = Instance.new("Frame")
	bar.BorderSizePixel = 0
	bar.BackgroundColor3 = Color3.fromRGB(255, 240, 240)
	bar.BackgroundTransparency = 0.75
	bar.Size = UDim2.new(1, 0, 0.015, 0)
	bar.Position = UDim2.fromScale(0, i * 0.17)
	bar.ZIndex = 8
	bar.Parent = screamerGui
	table.insert(scanBars, bar)
end

local function playScreamerAudio()
	-- Si Workspace.sonidos tiene Criatura_Screamer lo reproduce; además agrega impacto/zumbido de respaldo para nunca quedar mudo
	local custom = Sfx.Play(Config.Sfx.CreatureScreamer, SoundService, 1)
	if not custom then
		local punch = Instance.new("Sound")
		punch.SoundId = Config.Objectives.Sounds.Wrong.Id
		punch.Volume = 1
		punch.PlaybackSpeed = 0.42
		punch.Parent = SoundService
		punch.Ended:Once(function()
			punch:Destroy()
		end)
		punch:Play()

		local shriek = Instance.new("Sound")
		shriek.SoundId = Config.Objectives.Sounds.Spark.Id
		shriek.Volume = 0.9
		shriek.PlaybackSpeed = 1.45
		shriek.Parent = SoundService
		shriek.Ended:Once(function()
			shriek:Destroy()
		end)
		shriek:Play()
	end
end

local activeScreamerId = 0

creatureScreamer.OnClientEvent:Connect(function(payload: any)
	if type(payload) ~= "table" or type(payload.image) ~= "string" or payload.image == "" then
		return
	end
	activeScreamerId += 1
	local myId = activeScreamerId

	local cols = math.max(1, tonumber(payload.cols) or 4)
	local rows = math.max(1, tonumber(payload.rows) or 4)
	local frames = math.max(1, tonumber(payload.frames) or 12)
	local duration = math.clamp(tonumber(payload.duration) or 0.95, 0.4, 2.5)

	local cellW = math.floor(1024 / cols)
	local cellH = math.floor(1024 / rows)
	for _, img in { mainSprite, glitchRed, glitchCyan } do
		img.Image = payload.image
		img.ImageRectSize = Vector2.new(cellW, cellH)
		img.ImageRectOffset = Vector2.zero
	end

	screamerGui.Enabled = true
	backdrop.BackgroundTransparency = 0.35
	flash.BackgroundTransparency = 0.15
	mainSprite.ImageTransparency = 0
	glitchRed.ImageTransparency = 0.42
	glitchCyan.ImageTransparency = 0.42

	holder.Size = UDim2.fromScale(0.35, 0.35)
	TweenService:Create(holder, TweenInfo.new(0.08, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Size = UDim2.fromScale(1.28, 1.28),
	}):Play()
	TweenService:Create(flash, TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		BackgroundTransparency = 1,
	}):Play()

	playScreamerAudio()

	local t0 = os.clock()
	local conn: RBXScriptConnection
	conn = RunService.RenderStepped:Connect(function()
		if myId ~= activeScreamerId then
			conn:Disconnect()
			return
		end
		local elapsed = os.clock() - t0
		local alpha = math.clamp(elapsed / duration, 0, 1)

		local frameIdx = math.min(frames - 1, math.floor(alpha * frames * 1.15))
		local col = frameIdx % cols
		local row = math.floor(frameIdx / cols) % rows
		local rect = Vector2.new(col * cellW, row * cellH)
		mainSprite.ImageRectOffset = rect
		glitchRed.ImageRectOffset = rect
		glitchCyan.ImageRectOffset = rect

		local shake = (1 - alpha * 0.45)
		holder.Position = UDim2.fromScale(0.5 + (math.random() - 0.5) * 0.07 * shake, 0.5 + (math.random() - 0.5) * 0.07 * shake)
		holder.Rotation = (math.random() - 0.5) * 14 * shake
		glitchRed.Position = UDim2.fromScale(0.5 + (math.random() - 0.5) * 0.04, 0.5 + (math.random() - 0.5) * 0.025)
		glitchCyan.Position = UDim2.fromScale(0.5 + (math.random() - 0.5) * 0.04, 0.5 + (math.random() - 0.5) * 0.025)

		for _, bar in scanBars do
			bar.Visible = math.random() < 0.7
			bar.Position = UDim2.fromScale(0, math.random())
			bar.Size = UDim2.fromScale(1, 0.008 + math.random() * 0.03)
		end

		if alpha > 0.72 then
			local fade = (alpha - 0.72) / 0.28
			mainSprite.ImageTransparency = fade
			glitchRed.ImageTransparency = 0.42 + fade * 0.58
			glitchCyan.ImageTransparency = 0.42 + fade * 0.58
			backdrop.BackgroundTransparency = 0.35 + fade * 0.65
		end

		if alpha >= 1 then
			conn:Disconnect()
			screamerGui.Enabled = false
		end
	end)
end)
