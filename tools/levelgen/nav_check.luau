local storage=game:GetService('ServerStorage')
local maps=workspace.Maps
for _,m in maps:GetChildren() do m.Parent=storage.MapStorage end
local old=storage.MapsBackup.BeforePolish_20261126:FindFirstChild(mapName)
local new=storage.MapStorage:FindFirstChild(mapName)
local MapNav=require(game.ServerScriptService.Services.MapNav)
local function measure(m)
 local parent=m.Parent;m.Parent=maps;task.wait(.05)
 local started=os.clock();local nav=MapNav.Build(m)
 local visited={};local largest=0;local components=0
 for i=1,#nav.points do
  if not visited[i] then
   components+=1;visited[i]=true;local stack={i};local count=0
   while #stack>0 do
    local n=table.remove(stack);count+=1
    for _,edge in nav.adj[n] or {} do if not visited[edge.to] then visited[edge.to]=true;table.insert(stack,edge.to) end end
   end
   largest=math.max(largest,count)
  end
 end
 m.Parent=parent
 return {nodes=#nav.points,largest=largest,components=components,seconds=os.clock()-started}
end
local result={map=mapName,before=measure(old),after=measure(new)}
return result
