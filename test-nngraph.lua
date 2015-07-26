require 'graph'
require 'nngraph'

x = nn.Identity()()
n1 = nn.Reshape(2,1)(x)
n2 = nn.SplitTable(2)(n1)
n3, n4 = n2:split(2)
n5 = nn.Tanh()(n4)
n6 = nn.CAddTable()({n3, n5})
n7 = nn.Sigmoid()(n6)
g = nn.gModule({x}, {n7})

x.data.annotations.name = 'x'
n1.data.annotations.name = 'n1'
n2.data.annotations.name = 'n2'
n3.data.annotations.name = 'n3'
n4.data.annotations.name = 'n4'
n5.data.annotations.name = 'n5'
n6.data.annotations.name = 'n6'
n7.data.annotations.name = 'n7'

function walkGraph(g)
  for i,node in ipairs(g.nodes) do
    children = ''
    for j,child in ipairs(node.children) do
--      children = children .. child.data .. ' '
    end
    print(i, node.data, ':', children)
  end
end

function removeNodeByWalk(node, data)
  print('removeNodeByWalk', node.data.annotations.name)
  for i, child in ipairs(node.children) do
    if child.data == data then
      print('remove child', i, child.data.annotations)
      table.remove(node.children, i)
      node.children[child] = nil
      for j, childchild in ipairs(child.children) do
        if node.children[childchild] == nil then
          table.insert(node.children, childchild)
          node.children[childchild] = #node.children
        end
      end
      -- child.children = {}
--      return
    end
  end
  for i, child in ipairs(node.children) do
    removeNodeByWalk(child, data)
  end
end

function walkNodes(prefix, node)
  print(prefix, node.data.module)
  for i, child in ipairs(node.children) do
    walkNodes(prefix .. '  ', child)
  end
end

--g = n1:graph()

graph.dot(g.fg, '', 'base.fg') 
graph.dot(g.bg, '', 'base.bg') 

function walkAddParents(node)
  for i, child in ipairs(node.children) do
    child.parents = child.parents or {}
    child.parents[#child.parents + 1] = node
  end
  for i, child in ipairs(node.children) do
    walkAddParents(child)
  end
end

g2 = g:clone()

-- x3 is last but one node
-- just walk, and choose last but one...

newbg = g2.bg.nodes[2]
thisnode = newbg
x3 = newbg
while #thisnode.children > 0 do
  x3 = thisnode
  thisnode = thisnode.children[1]
end
print('x3', x3.data.annotations.name)

thisnode = newbg
while thisnode.data ~= x3.data do
  thisnode = thisnode.children[1]
end
thisnode.children = {}

if os.getenv('NODE') ~= nil then
  local nodenum = os.getenv('NODE')
  local targetname = 'n' .. nodenum
  local targetdata = nil
  for i, node in ipairs(newbg:graph().nodes) do
    if node.data.annotations.name == targetname then
      targetdata = node.data
      print('got targetdata')
    end
  end
--  local targetnode = loadstring('return n' .. nodenum)()
--  print('targetnode', targetnode.data.annotations.name)
  removeNodeByWalk(newbg, targetdata)
  --removeNodeFromGraph(g, targetnode.data)
end

--graph.dot(newbg:graph(), '', 'nt')

g3 = nn.gModule({x3}, {newbg})

for i, node in ipairs(newbg) do
  node.data.mapindex = nil
end

graph.dot(g3.fg, '', 'n')
