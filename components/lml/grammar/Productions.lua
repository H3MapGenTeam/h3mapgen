local GL = require'grammar/GrammarLib'
local Zone = require'graph/Zone'
local RNG = require'Random'

local Productions = {}

local rand = RNG.Random


--- For the first non-final node divides it content using random pivot and push out new node containing greater elements
-- @param graph LML graph (modifying)
-- @param state H3pgm state 
-- @return true iff productions succeed (it properly divided first nonfinal node)
function Productions.PushOutGreaterThenPivot (graph, state) 
  local nfids = graph:NonfinalIds()
  local id = nfids[1] -- RNG.Choice(nfids)
  local zone = graph[id]
  
  local smaller_c, greatereq_c
  if zone.classes[1].type=='LOCAL' then
    smaller_c, greatereq_c = GL.SplitInto2ByDeltaBasedPivot(zone.classes, state.config.PushOutDistantPivotRatio[state.paramsDetailed.focus])
  else
    smaller_c, greatereq_c = GL.SplitInto2ByRandomPivotUniformly(zone.classes)
  end
  if #smaller_c==0 or #greatereq_c==0 then
    return false
  end
  
  local smaller_f, greatereq_f = {}, {}
  for _, f in ipairs(zone.features) do
    if f:IsConsistentWith(greatereq_c) then
      table.insert(greatereq_f, f)
    else
      table.insert(smaller_f, f)
    end
  end
  
  for _, c in ipairs(smaller_c) do -- we need to prevent onoutered buffers after locals
    if c.type=='LOCAL' then -- need additional check
      if not GL.CheckForBufferWithOuter(smaller_c, smaller_f) or not GL.CheckForBufferWithOuter(greatereq_c, greatereq_f) then
        return false
      end
    end
  end
  
  
  graph[id] = Zone.New{classes=smaller_c, features=smaller_f}
  local nid, nzone = graph:AddZone{classes=greatereq_c, features=greatereq_f}
  graph:AddEdge(id, nid)
  return true
end
-- Productions.PushOutGreaterThenPivot


--- For the first non-final node, if it contains only one-class zones, divides it content into new final nodes and put them horizontally (edges copying depends on 'branching' value)
-- @param graph LML graph (modifying)
-- @param state H3pgm state 
-- @return true iff productions succeed (it properly divided first nonfinal node, which contain only one-class zones)
function Productions.DivideEqualHorizontally (graph, state) 
  local nfids = graph:NonfinalIds()
  local id = nfids[1] -- RNG.Choice(nfids)
  local zone = graph[id]
  local class = zone.classes[1]
  for _, c in ipairs(zone.classes) do
    if c ~= class then return false end
  end
  
  local nzones 
  if class.type=='LOCAL' then
    nzones = GL.FeatureDistributionStrategyLocal(zone.features, #zone.classes, state.config)
  else
    nzones = GL.FeatureDistributionStrategyBuffer(zone.features, #zone.classes, state.config)
  end
  for i=1,#zone.classes do
    nzones[i].classes[1] = class
  end
  
  local copy = 1
  for i=1,#nzones do
    if rand() < state.config.DivideEqualCopyConnectionsChance[state.paramsDetailed.branching] then
      copy = copy + 1
    end
  end
  if id==1 then -- safeguard: if this is initian node branching we need them fully connected
    copy=#nzones
  end
  
  graph[id] = nzones[1]
  for i=2,#nzones do
    local nid, nzone = graph:AddZone(nzones[i])
    for id2, k in pairs(graph.edges[id]) do
      if graph[id2].classes[1] < class or i<=copy then -- copy edges to lower zones only or copy all of them for 
        for i=1,k do graph:AddEdge(nid, id2) end
      end
    end
  end

  return true
end
-- Productions.DivideEqualHorizontally


--- Duplicates random edge (if there is only one edge between the nodes)
-- @param graph LML graph (modifying)
-- @param state H3pgm state 
-- @return true iff productions succeed (there is no duplicate for the edge we try to duplicate)
function Productions.DuplicateEdge (graph, state) 
  local edges = graph:EdgesList()
  if #edges < 1 then 
    return false 
  end
  local edge = RNG.Choice(edges)
  if graph.edges[edge[1]][edge[2]] > 1 then
    return false
  else
    graph:AddEdge(edge[1], edge[2])
    return true
  end
end
-- Productions.DuplicateEdge


--- Adds edge between two random previously not connected nodes (only local-local or nonlocal-nonlocal)
-- @param graph LML graph (modifying)
-- @param state H3pgm state 
-- @return true iff productions succeed (there is a valid matching for the randomly chosen node)
function Productions.ConnectDistantNodes (graph, state)
  local id1 = rand(#graph)
  local islocal = graph[id1].classes[1].type == 'LOCAL'
  local ids2 = {}
  for i, z in ipairs(graph) do
    if i ~= id1 and (z.classes[1].type == 'LOCAL') == islocal and graph.edges[id1][i] == nil then
      table.insert(ids2, i)
    end
  end
  if #ids2 == 0 then return false end
  graph:AddEdge(id1, RNG.Choice(ids2))
  return true
end
-- Productions.ConnectDistantNodes


function Productions.AlwaysFail (graph, state) 
  --print ('inside AlwaysFail')
  return false
end


return  Productions