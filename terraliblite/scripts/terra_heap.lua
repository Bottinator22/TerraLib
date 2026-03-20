-- TODO: Strict Fibonacci Heap
-- https://en.wikipedia.org/wiki/Strict_Fibonacci_heap#Implementation

-- for now just a binary heap
local MinHeap = {}
function MinHeap.new()
    local h = {
        root=nil
    }
    setmetatable(h,{__index=MinHeap})
    return h
end
function MinHeap.add(self,el,prior)
    -- TODO
end
function MinHeap.deleteMin(self)
    -- TODO
end
function MinHeap.getMin(self)
    -- TODO
end
