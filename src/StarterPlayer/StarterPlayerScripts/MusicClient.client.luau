--!strict
-- Analog exploration bed + a single pursuit layer; client presentation only.
local CollectionService = game:GetService('CollectionService')
local Players = game:GetService('Players')
local ReplicatedStorage = game:GetService('ReplicatedStorage')
local RunService = game:GetService('RunService')
local SoundService = game:GetService('SoundService')
local TweenService = game:GetService('TweenService')
local Config = require(ReplicatedStorage:WaitForChild('Shared'):WaitForChild('Config'))
local WorldRefs = require(ReplicatedStorage.Shared:WaitForChild('WorldRefs'))
local Rules = require(script.Parent:WaitForChild('AudioCueRules'))
local M = Config.Audio.Music
local updateHud = ReplicatedStorage:WaitForChild('Remotes'):WaitForChild('UpdateHUD') :: RemoteEvent
local player = Players.LocalPlayer
local function findTrack(name: string): Sound?
	local root = workspace:FindFirstChild('sonidos')
	if not root then return nil end
	for _, d in root:GetDescendants() do
		if d:IsA('Sound') and string.lower(d.Name) == string.lower(name) then return d end
	end
	return nil
end
local current: Sound? = nil
local currentName: string? = nil
local currentGain = 1
local chase: Sound? = nil
local chaseVolume = 0.32
local state: string? = nil
local zone = 0
local lastThreat = -math.huge
local wantedChase = false
local function fadeOut(sound: Sound)
	local tween = TweenService:Create(sound,TweenInfo.new(M.FadeSeconds),{Volume=0})
	tween.Completed:Once(function() sound:Destroy() end)
	tween:Play()
end
local function setTrack(name: string?)
	if name == currentName and (name == nil or current ~= nil) then return end
	currentName = name
	if current then fadeOut(current);current=nil end
	if not name then return end
	local template = findTrack(name)
	if not template then return end -- Retry on refresh if assets replicate late.
	local sound = template:Clone()
	sound.Name='Music_'..name;sound.Looped=true;sound.Volume=0;sound.Parent=SoundService
	currentGain=tonumber(template:GetAttribute('MixGain')) or 1
	sound:Play();current=sound
end
local function refresh()
	if player:GetAttribute('InRun') ~= true then setTrack(M.Lobby)
	elseif state == 'Level' then
		local stage=(Config.Run.Stages :: any)[zone]
		setTrack(stage and (M.Levels :: any)[stage.Map])
	else setTrack(nil) end
end
updateHud.OnClientEvent:Connect(function(payload: any)
	state=payload.runState;zone=payload.zone or 0;refresh()
end)
player:GetAttributeChangedSignal('InRun'):Connect(function()
	if player:GetAttribute('InRun') ~= true then state=nil;zone=0;lastThreat=-math.huge;wantedChase=false end
	refresh()
end)
local function safeAt(pos: Vector3): boolean
	local elevator=WorldRefs.Elevator()
	local interior=elevator and elevator:FindFirstChild('InteriorZone',true)
	if not interior or not interior:IsA('BasePart') then return false end
	local rel=interior.CFrame:PointToObjectSpace(pos);local h=interior.Size/2
	return math.abs(rel.X)<=h.X and math.abs(rel.Y)<=h.Y and math.abs(rel.Z)<=h.Z
end
local function threatNow(): boolean
	local character=player.Character
	local root=character and character:FindFirstChild('HumanoidRootPart')
	local humanoid=character and character:FindFirstChildOfClass('Humanoid')
	if not root or not root:IsA('BasePart') then lastThreat=-math.huge;return false end
	local canUse=Rules.CanUse(player:GetAttribute('InRun')==true and state=='Level',
		humanoid~=nil and humanoid.Health>0,player:GetAttribute('Hidden')==true,safeAt(root.Position))
	if not canUse then lastThreat=-math.huge;return false end
	local params=RaycastParams.new();params.FilterType=Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances={character :: Model};params.RespectCanCollide=true
	for _,model in CollectionService:GetTagged('ProcCreature') do
		if model:IsA('Model') and model:IsDescendantOf(workspace) then
			local s=model:GetAttribute('Estado')
			local target=model:GetAttribute('Target')
			local delta=model:GetPivot().Position-root.Position
			if type(s)=='string' and delta.Magnitude<=95 then
				local hit=workspace:Raycast(root.Position,delta,params)
				local visible=not hit or hit.Instance:IsDescendantOf(model)
				if Rules.CanHearChase(s,delta.Magnitude,if type(target)=='string' then target else nil,player.Name,visible) then
					lastThreat=os.clock();return true
				end
			end
		end
	end
	return os.clock()-lastThreat<2.5 -- brief release avoids musical flicker at corners
end
local elapsed=0
RunService.Heartbeat:Connect(function(dt)
	elapsed+=dt
	if elapsed>=0.2 then
		elapsed=0;wantedChase=threatNow();refresh()
		if wantedChase and not chase then
			local template=findTrack('Persecucion_Frenetica')
			if template then
				chase=template:Clone();chase.Name='Music_Pursuit';chaseVolume=template.Volume
				chase.Looped=true;chase.Volume=0;chase.Parent=SoundService
			end
		end
	end
	local pursuing=chase~=nil and wantedChase
	if current then
		local target=M.Volume*currentGain*(if pursuing then 0.18 else 1)
		current.Volume+=(target-current.Volume)*(1-math.exp(-dt/(if pursuing then .3 else M.FadeSeconds)))
	end
	if chase then
		if wantedChase and not chase.IsPlaying then chase:Play() end
		local target=if wantedChase then chaseVolume else 0
		chase.Volume+=(target-chase.Volume)*(1-math.exp(-dt/(if wantedChase then .35 else .65)))
		if not wantedChase and chase.Volume<.003 then chase.Volume=0;chase:Stop() end
	end
end)
task.spawn(function()
	workspace:WaitForChild('sonidos',10);refresh()
end)
