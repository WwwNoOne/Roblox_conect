-- Reproducible, idempotent Studio installer. Preserves all user-supplied sounds.
local SS=game:GetService('SoundService')
local root=workspace:FindFirstChild('sonidos')
assert(root,'Workspace.sonidos missing')
local function folder(parent,name)
 local old=parent:FindFirstChild(name);if old then old:Destroy() end
 local f=Instance.new('Folder');f.Name=name;f.Parent=parent;return f
end
local bank=folder(root,'Audio_Analogico')
local music=root:FindFirstChild('Musica_background') or Instance.new('Folder');music.Name='Musica_background';music.Parent=root
local groups={}
for name,gain in {Threat=.55,Shock=.42,Environment=.18,Music=.8,Guide=1,Elevator=.65} do
 local n='Analog_'..name;local g=SS:FindFirstChild(n) or Instance.new('SoundGroup');g.Name=n;g.Volume=gain;g.Parent=SS;groups[name]=g
end
local function sound(parent,name,id,vol,group,loop)
 local old=parent:FindFirstChild(name);if old then old:Destroy() end
 local s=Instance.new('Sound');s.Name=name;s.SoundId='rbxassetid://'..id;s.Volume=vol;s.SoundGroup=groups[group];s.Looped=loop or false;s.RollOffMode=Enum.RollOffMode.InverseTapered;s.RollOffMinDistance=8;s.RollOffMaxDistance=90;s.Parent=parent;return s
end
local rows={
 {'Impacto','140635119444127',.4,'Threat'},
 {'Criatura_Rugido','100711897299907',.55,'Threat'},
 {'Criatura_Alerta','112937086115699',.45,'Threat'},
 {'Criatura_Screamer','136267238697021',.6,'Shock'},
 {'Criatura_Susurro','4860560167',.2,'Environment'},
 {'Ambiente_Instalacion','4860560167',.15,'Environment'},
 {'Tuberia_Gemido','92922627936971',.25,'Environment'},
 {'Generador_Pista','9116279339',.4,'Guide'},
 {'entrar','6431334087',.45,'Elevator'},
 {'Iniciar_partida','115781051350916',.45,'Elevator'},
 {'Avanzar_1','109924756554836',.35,'Elevator'},
 {'Avanzar_2','140635119444127',.4,'Elevator'},
 {'Alarma_perdieron','88983571552983',.45,'Shock'},
 {'Cuando_llega_al_siguiente_nivel','18192219147',.45,'Elevator'},
 {'Panel_Click','87437544236708',.35,'Elevator'},
}
for _,r in rows do sound(bank,r[1],r[2],r[3],r[4]) end
for _,name in {'Lobby','Nivel(1)','Nivel(2)','Pendiente(2)'} do
 local s=sound(music,name,'135975888586873',.22,'Music',true);s:SetAttribute('MixGain',if name=='Lobby' then .45 else .7)
end
sound(music,'Persecucion_Frenetica','88275367596456',.32,'Music',true)
local static=bank.Ambiente_Instalacion
local eq=Instance.new('EqualizerSoundEffect');eq.LowGain=-16;eq.MidGain=-8;eq.HighGain=-18;eq.Parent=static
local ids={'9112796599','9112810051','9125446564','9125446564','4860560167','9125446564'}
local emitters=0
for i=1,6 do
 local map=workspace.Maps:FindFirstChild('Level_'..i)
 if map then
  local f=folder(map,'AnalogAmbience');local points={}
  local markers={};for _,d in map:GetDescendants() do if d:IsA('Attachment') and string.match(d.Name,'^Patrol') then table.insert(markers,d) end end
  table.sort(markers,function(a,b)return a:GetFullName()<b:GetFullName()end)
  for _,p in markers do
   local pos=p.WorldPosition;local spaced=true
   for _,v in points do if (pos-v).Magnitude<100 then spaced=false;break end end
   if spaced then
    table.insert(points,pos)
    local part=Instance.new('Part');part.Name='AmbientEmitter';part.Anchored=true;part.Size=Vector3.one;part.Transparency=1;part.CanCollide=false;part.CanTouch=false;part.CanQuery=false;part.Position=pos+Vector3.new(0,4,0);part.Parent=f
    local s=sound(part,'RoomTone',ids[i],.12,'Environment',true);s.RollOffMaxDistance=80;s.Playing=true;emitters+=1
   end
   if #points>=4 then break end
  end
 end
end
local probe=game.ServerStorage:FindFirstChild('AudioProbe_Analog');if probe then probe:Destroy() end
return {aliases=#rows,music=5,emitters=emitters}
