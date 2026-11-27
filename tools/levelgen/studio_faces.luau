local map=workspace.Maps:FindFirstChild(mapName)
local buckets={};local count,blocks=0,0;local examples={}
for idx,p in map:GetDescendants() do
 if p:IsA('Part') and p.Shape==Enum.PartType.Block and p.Transparency<1 and not p:FindFirstChildOfClass('SpecialMesh') then
  local r={p.CFrame:GetComponents()};local axisAligned=true
  for i=4,12 do if math.min(math.abs(r[i]),math.abs(math.abs(r[i])-1))>0.00001 then axisAligned=false;break end end
  if axisAligned then
   blocks+=1
   local half=Vector3.new(math.abs(r[4])*p.Size.X+math.abs(r[5])*p.Size.Y+math.abs(r[6])*p.Size.Z,
    math.abs(r[7])*p.Size.X+math.abs(r[8])*p.Size.Y+math.abs(r[9])*p.Size.Z,
    math.abs(r[10])*p.Size.X+math.abs(r[11])*p.Size.Y+math.abs(r[12])*p.Size.Z)*.5
   local lo,hi=p.Position-half,p.Position+half
   local b={{lo.X,lo.Y,lo.Z},{hi.X,hi.Y,hi.Z},p}
   for ax=1,3 do for side=1,2 do
    local k=ax..':'..side..':'..math.floor(b[side][ax]*1000+.5)
    local bucket=buckets[k] or {};buckets[k]=bucket
    for _,q in bucket do
     local hit=true
     for j=1,3 do if j~=ax and math.min(b[2][j],q[2][j])-math.max(b[1][j],q[1][j])<=.001 then hit=false;break end end
     if hit then count+=1;if #examples<8 then table.insert(examples,{part=p:GetFullName(),other=q[3]:GetFullName(),axis=ax}) end end
    end
    table.insert(bucket,b)
   end end
  end
 end
 if idx%500==0 then task.wait() end
end
return {map=mapName,blocks=blocks,coplanarFaces=count,examples=examples}
