--[[
-- Abstraction over a server shard.
--]]
--
local Lambda = wickerrequire "paradigms.functional"
local Debuggable = wickerrequire "adjectives.debuggable"
local Pred = wickerrequire "lib.predicates"

local getmetatable = getmetatable

---

local SHARDID = assert( SHARDID )
local REMOTESHARDSTATE = assert( REMOTESHARDSTATE )

local function inv(t)
	local u = {}
	for k, v in pairs(t) do
		u[v] = k
	end
	return u
end

local SHARDID_NAME = inv(SHARDID)
local REMOTESHARDSTATE_NAME = inv(REMOTESHARDSTATE)

---

local Shard = Class(Debuggable, function(self, graph, id)
	Debuggable._ctor(self, self, false)

	assert( Pred.IsShardGraph(graph) )
	assert( type(id) == "string" )

	self.graph = graph
	self.id = id

	self.state = REMOTESHARDSTATE[id == GetShardId() and "READY" or "OFFLINE"]

	self.metadata = {}
end)

function Shard:__tostring()
	local str = ("Shard(%s)"):format(self.id)
	if self.state ~= REMOTESHARDSTATE.READY then
		str = str..(" (%s)"):format(REMOTESHARDSTATE_NAME[self.state])
	end
	return str
end

function Shard:GetDebugString()
	return tostring(self)..": metadata = "..table_dump(self.metadata)
end

function Shard:InDegree()
	return #self.inportals
end

function Shard:OutDegree()
	return #self.outportals
end

function Shard:UpdateWorldState(state, ...)
	self.state = state
	print "UpdateWorldState!"
	print(...)
	-- self.metadata = {...}
end

---

function Shard.NewShardStorage(graph, storage)
	assert( Pred.IsShardGraph(graph) )
	assert( Pred.IsTable(storage) )
	return function(id)
		if id == nil then return end

		if getmetatable(id) == Shard then
			return id
		end
		local sh = storage[id]
		if sh == nil then
			sh = Shard(graph, id)
			storage[id] = sh
		end
		return sh
	end
end

---

return Shard
