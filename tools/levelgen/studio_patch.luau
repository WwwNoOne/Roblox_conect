-- Geometry-only edit tool, never installed under src/ or executed at runtime.
-- Caller prepends local mapName = 'Level_N'; local apply = false/true.
local Http = game:GetService('HttpService')
local patch = Http:JSONDecode(Http:GetAsync('http://127.0.0.1:8791/' .. mapName .. '.json'))
local map = workspace.Maps:FindFirstChild(mapName)
assert(map and map:IsA('Model'), 'Map not found')
assert(not map:FindFirstChild('ContencionExterior'), 'Map already patched')
local dock = map:FindFirstChild('ElevatorDock')
local transform = dock.CFrame * CFrame.new(-Vector3.new(table.unpack(patch.dock)))
local function cf(g)
    return CFrame.new(g.pos[1],g.pos[2],g.pos[3],table.unpack(g.rot))
end
local function cell(v)
    return math.floor(v.X/2), math.floor(v.Y/2), math.floor(v.Z/2)
end
local function key(name,x,y,z) return name..':'..x..':'..y..':'..z end
local buckets={}
for i,p in map:GetDescendants() do
    if p:IsA('BasePart') then
        local localPos=transform:PointToObjectSpace(p.Position)
        local x,y,z=cell(localPos)
        local k=key(p.Name,x,y,z)
        buckets[k]=buckets[k] or {}
        table.insert(buckets[k],p)
    end
    if i%1000==0 then task.wait() end
end
local used, matched, missing = {},{},{}
for i,op in patch.ops do
    local g=op.old
    local pos=Vector3.new(table.unpack(g.pos))
    local targetCF=transform*cf(g)
    local size=Vector3.new(table.unpack(g.size))
    local x,y,z=cell(pos)
    local best,bestScore=nil,math.huge
    for dx=-1,1 do for dy=-1,1 do for dz=-1,1 do
        for _,p in buckets[key(g.name,x+dx,y+dy,z+dz)] or {} do
            local positionError=(p.Position-targetCF.Position).Magnitude
            local sizeError=(p.Size-size).Magnitude
            if not used[p] and positionError<0.035 and sizeError<0.035
                and p.CFrame.LookVector:Dot(targetCF.LookVector)>0.99999
                and p.CFrame.UpVector:Dot(targetCF.UpVector)>0.99999 then
                local score=positionError+sizeError
                if score<bestScore then best,bestScore=p,score end
            end
        end
    end end end
    if best then used[best]=true;matched[i]=best
    else table.insert(missing,{index=i,name=g.name,pos=g.pos}) end
    if i%500==0 then task.wait() end
end
if #missing>0 then return {map=mapName,missing=#missing,examples={table.unpack(missing,1,math.min(8,#missing))},applied=false} end
if not apply then return {map=mapName,matched=#patch.ops,boundaries=#patch.barriers,applied=false} end
local storage=game:GetService('ServerStorage')
local backupRoot=storage:FindFirstChild('MapsBackup')
if not backupRoot then backupRoot=Instance.new('Folder');backupRoot.Name='MapsBackup';backupRoot.Parent=storage end
local backup=backupRoot:FindFirstChild('BeforePolish_20261126')
if not backup then backup=Instance.new('Folder');backup.Name='BeforePolish_20261126';backup.Parent=backupRoot end
assert(not backup:FindFirstChild(mapName),'Backup exists: inspect before reapplying')
local saved=map:Clone();saved.Parent=backup;task.wait()
for i,op in patch.ops do
    local p=matched[i]
    if op.delete then p:Destroy()
    else
        p.Size=Vector3.new(table.unpack(op.new.size))
        p.CFrame=transform*cf(op.new)
    end
    if i%500==0 then task.wait() end
end
local boundary=Instance.new('Folder');boundary.Name='ContencionExterior'
for i,g in patch.barriers do
    local p=Instance.new('Part');p.Name=g.name
    p.Size=Vector3.new(table.unpack(g.size));p.CFrame=transform*cf(g)
    p.Anchored=true;p.CanCollide=true;p.CanQuery=true;p.CanTouch=false
    p.Transparency=1;p.CastShadow=false;p:SetAttribute('MapBoundary',true)
    p.Parent=boundary
end
for k,v in patch.boundaryAttrs do boundary:SetAttribute(k,v) end
boundary.Parent=map
map:SetAttribute('GeometryPolish','2026-11-26')
return {map=mapName,applied=true,operations=#patch.ops,boundaries=#patch.barriers,backup=saved:GetFullName()}
