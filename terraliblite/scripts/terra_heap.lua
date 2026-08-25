-- TODO: Strict Fibonacci Heap
-- https://en.wikipedia.org/wiki/Strict_Fibonacci_heap#Implementation

-- for now just a binary heap
MinHeap = {}
function MinHeap.new()
    local h = {
        nodes={n=0}
    }
    setmetatable(h,{__index=MinHeap})
    return h
end

local function treeParent(index)
    return math.floor(index/2)
end
local function treeChild(index,ci)
    return index*2+ci
end
function MinHeap.add(self,el,prior)
    local node = {
        value=el,
        priority=prior
    }
    self.nodes.n = self.nodes.n + 1
    self.nodes[self.nodes.n] = node
    local i = self.nodes.n
    local pi = treeParent(i)
    -- bubble
    while pi >= 1 and self.nodes[pi].priority > node.priority do
        local p = self.nodes[pi]
        self.nodes[i] = p
        self.nodes[pi] = node
        i = pi
        pi = treeParent(i)
    end
end
function MinHeap.getMin(self)
    return self.nodes[1] and self.nodes[1].value
end
function MinHeap.deleteMin(self)
    if self.nodes.n <= 0 then
        return
    end
    -- replace first with last
    self.nodes[1] = self.nodes[self.nodes.n]
    self.nodes[self.nodes.n] = nil
    self.nodes.n = self.nodes.n - 1
    -- bubble down
    if self.nodes.n == 0 then
        return
    end
    local i = 1
    local p = self.nodes[i]
    local cia = treeChild(i,0)
    local cib = treeChild(i,1)
    local ca = self.nodes[cia]
    local cb = self.nodes[cib]
    while (ca and ca.priority < p.priority) or (cb and cb.priority < p.priority) do
        if ca and ca.priority < p.priority and not (cb and cb.priority < ca.priority) then
            self.nodes[i] = ca
            self.nodes[cia] = p
            i = cia
        else
            self.nodes[i] = cb
            self.nodes[cib] = p
            i = cib
        end
        p = self.nodes[i]
        cia = treeChild(i,0)
        cib = treeChild(i,1)
        ca = self.nodes[cia]
        cb = self.nodes[cib]
    end
end
function MinHeap.extractMin(self)
    -- remove and return first
    local out = self:getMin()
    self:deleteMin()
    return out
end
function MinHeap.empty(self)
    return self.nodes.n == 0
end
