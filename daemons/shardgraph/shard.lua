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

local function updateWorldData(self, data)
	if type(data) == "table" then
		self.world_data_str = _G.DataDumper(data, nil, false)
	elseif type(data) == "string" then
		self.world_data_str = data

		local success, real_data = _G.RunInSandboxSafe(data)
		if not success then
			data = nil
		else
			data = real_data
		end
	elseif data ~= nil then
		return error(self:Format("Invalid world data value: ", data))
	end
		
	if data == nil then
		self.world_data = {}
		self.world_data_str = "return {}"
	else
		assert( self.world_data_str )
		self.world_data = data
	end
end

local Shard = Class(Debuggable, function(self, graph, id)
	Debuggable._ctor(self, self, false)

	assert( Pred.IsShardGraph(graph) )
	assert( type(id) == "string" )

	self.graph = graph
	self.id = id

	self.name = SHARDID_NAME[id]

	self.state = REMOTESHARDSTATE.OFFLINE

	self.tags = {}

	if (id == GetShardId()) and id ~= SHARDID.INVALID then
		self.state = REMOTESHARDSTATE.READY

		if not IsDST() then
			-- FIXME
			return error "This code path only supports DST at the moment."
		end

		local sg = assert( GetSaveIndex() )

		updateWorldData(self, sg:GetSlotGenOptions())
	else
		updateWorldData(self, nil)
	end
end)

function Shard:__tostring()
	local str = "Shard"
	if self.name then
		str = str.." "..tostring(self.name)
	end
	str = str.."("..tostring(self.id)..")"
	if self.state ~= REMOTESHARDSTATE.READY then
		str = str..(" (%s)"):format(REMOTESHARDSTATE_NAME[self.state])
	end
	return str
end

function Shard:GetDebugString()
	local suffix = " "..self.world_data_str:gsub("^return%s*", "")
	return tostring(self)..suffix
end

function Shard:InDegree()
	return #self.inportals
end

function Shard:OutDegree()
	return #self.outportals
end

function Shard:UpdateWorldState(state, tags, world_data, ...)
	self.state = state
	self.tags = tags or {}
	updateWorldData(self, world_data)
	self:DebugSay("UpdateWorldState complete")
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
