-- Geometry probes, Edit or Server. Caller supplies mapName; no runtime scripts changed.
local map=workspace.Maps:FindFirstChild(mapName)
assert(map,'Map missing from Workspace.Maps')
local walls=map:FindFirstChild('ContencionExterior');assert(walls,'No containment')
local params=RaycastParams.new();params.FilterType=Enum.RaycastFilterType.Include
params.FilterDescendantsInstances={walls};params.RespectCanCollide=true
local count,failures=0,{}
for wi,p in walls:GetChildren() do
    local alongX=p.Size.X>p.Size.Z
    local along=alongX and p.CFrame.RightVector or p.CFrame.ZVector
    local normal=alongX and p.CFrame.ZVector or p.CFrame.RightVector
    local length=alongX and p.Size.X or p.Size.Z
    -- Both directions, seams, avatar chest height and jump/top envelope.
    local n=math.max(1,math.ceil(length/4))
    for j=0,n do
        local offset=-length/2+.31+(length-.62)*j/n
        for _,height in {p.Position.Y-p.Size.Y/2+1,p.Position.Y,p.Position.Y+p.Size.Y/2-1} do
            local center=p.Position+along*offset+Vector3.new(0,height-p.Position.Y,0)
            for _,sign in {-1,1} do
                local hit=workspace:Blockcast(CFrame.new(center+normal*4*sign),Vector3.new(1.8,2,1.8),normal*(-8*sign),params)
                count+=1
                if not hit then table.insert(failures,{wall=p.Name,offset=offset,height=height}) end
            end
        end
    end
    if wi%10==0 then task.wait() end
end
local markerCounts={}
for _,p in map:GetDescendants() do
    if p:IsA('Attachment') or p.Name=='Escondite' then markerCounts[p.Name]=(markerCounts[p.Name] or 0)+1 end
end
return {map=mapName,casts=count,leaks=#failures,examples={table.unpack(failures,1,math.min(5,#failures))},markers=markerCounts}
