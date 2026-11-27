local storage=game:GetService('ServerStorage')
local maps=workspace.Maps
local m=storage.MapStorage:FindFirstChild(mapName) or maps:FindFirstChild(mapName)
assert(m,'Missing map')
for _,other in maps:GetChildren() do if other~=m then other.Parent=storage.MapStorage end end
m.Parent=maps;task.wait(.1)
local player=game:GetService('Players'):GetPlayers()[1]
local character=player.Character;local hrp=character:FindFirstChild('HumanoidRootPart');local humanoid=character:FindFirstChildOfClass('Humanoid')
local boundaries=m.ContencionExterior:GetChildren()
table.sort(boundaries,function(a,b)return math.max(a.Size.X,a.Size.Z)>math.max(b.Size.X,b.Size.Z)end)
local params=RaycastParams.new();params.FilterType=Enum.RaycastFilterType.Include;params.FilterDescendantsInstances={m};params.RespectCanCollide=true
local chosen
for _,wall in boundaries do
 local normal=wall.Size.X>wall.Size.Z and wall.CFrame.ZVector or wall.CFrame.RightVector
 for _,sign in {-1,1} do
  local pos=wall.Position+normal*5*sign
  local hit=workspace:Raycast(Vector3.new(pos.X,wall.Position.Y+wall.Size.Y/2+1,pos.Z),Vector3.new(0,-wall.Size.Y-10,0),params)
  if hit and hit.Normal.Y>.9 and hit.Instance.Transparency<1 and hit.Instance.CanCollide then
   chosen={wall=wall,normal=normal,sign=sign,hit=hit};break
  end
 end
 if chosen then break end
end
assert(chosen,'No accessible edge found')
local wall,normal,sign=chosen.wall,chosen.normal,chosen.sign
local start=chosen.hit.Position+Vector3.new(0,4,0)
hrp.AssemblyLinearVelocity=Vector3.zero
character:PivotTo(CFrame.lookAt(start,start-normal*sign))
task.wait(.5)
local before=hrp.Position;local maxOutside=-math.huge;local maxHeight=hrp.Position.Y
for i=1,35 do
 humanoid:MoveTo(start-normal*sign*24)
 if i==1 or i==18 then humanoid.Jump=true end
 task.wait(.06)
 local signed=(hrp.Position-wall.Position):Dot(normal)*sign
 maxOutside=math.max(maxOutside,-signed)
 maxHeight=math.max(maxHeight,hrp.Position.Y)
end
humanoid:MoveTo(hrp.Position)
local result={map=mapName,wall=wall.Name,start=tostring(before),finish=tostring(hrp.Position),maxOutside=maxOutside,maxHeight=maxHeight,boundaryTop=wall.Position.Y+wall.Size.Y/2,escaped=maxOutside>.3}
return result
