--[[
-- Abstraction over a server shard.
--]]
--
local Lambda = wickerrequire "paradigms.functional"
local Debuggable = wickerrequire "adjectives.debuggable"
local Pred = wickerrequire "lib.predicates"

local getmetatable = getmetatable

---

local SHARDID
local REMOTESHARDSTATE
if IsDST() then
	SHARDID = assert( _G.SHARDID )
	REMOTESHARDSTATE = assert( _G.REMOTESHARDSTATE )
 else
	SHARDID = {
		INVALID = "0", 
		MASTER = "1",
	}
	REMOTESHARDSTATE = {
		OFFLINE = 0, 
		READY = 1, 
	}
end

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

local Shard = Class(Debuggable, function(self, id)
	Debuggable._ctor(self, self, false)

	assert( type(id) == "string" )

	self.id = id
	self.state = REMOTESHARDSTATE[id == GetShardId() and "READY" or "OFFLINE"]

	self.metadata = {}
end)

function Shard:__tostring()
	local str = ("Shard %s"):format(self.id)
	if self.state ~= REMOTESHARDSTATE.READY then
		str = str..(" (%s)"):format(REMOTESHARDSTATE_NAME[self.state])
	end
	return str
end

function Shard:InDegree()
	return #self.inportals
end

function Shard:OutDegree()
	return #self.outportals
end

function Shard:UpdateWorldState(state, ...)
	self.state = state
	self.metadata = {...}
end

---

function Shard.NewShardStorage(storage)
	return function(id)
		if getmetatable(id) == Shard then
			return id
		end
		local sh = storage[id]
		if sh == nil then
			sh = Shard(id)
			storage[id] = sh
		end
		return sh
	end
end

---

return Shard
