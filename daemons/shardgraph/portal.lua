--[[
-- Abstraction over a shard migration portal.
--]]

local Lambda = wickerrequire "paradigms.functional"
local Debuggable = wickerrequire "adjectives.debuggable"
local Pred = wickerrequire "lib.predicates"

local getmetatable = getmetatable

---

local Shard = wickerrequire "gadgets.shard"

---

local function default_shard_storage(shid)
	return Shard(shid)
end

local Portal = Class(Debuggable, function(self, id)
	Debuggable._ctor(self, self, true)

	assert( type(id) == "number" )

	self.id = id

	self.startpoint = Shard( GetShardId() )
	self.endpoint = nil

	self.inst = nil

	self.shard_storage = default_shard_storage
end)

function Portal:__tostring()
	return ("Portal %d (%s -> %s)"):format(self.id, tostring(self.startpoint), tostring(self.endpoint))
end

function Portal:SetStartPoint(sp)
	self.startpoint = self.shard_storage(sp)
end

function Portal:SetEndPoint(ep)
	self.endpoint = self.shard_storage(ep)
end

function Portal:set(sp, ep)
	self:SetStartPoint(sp)
	self:SetEndPoint(ep)
end

function Portal:GetStartPoint()
	return self.startpoint
end
Portal.fst = Portal.GetStartPoint

function Portal:GetEndPoint()
	return self.endpoint
end
Portal.snd = Portal.GetEndPoint

function Portal:get()
	return self.startpoint, self.endpoint
end

function Portal:SetEntity(inst)
	self.inst = inst
end

function Portal:GetEntity()
	return self.inst
end

---

function Portal.NewPortalStorage(storage, shard_storage)
	return function(id)
		if getmetatable(id) == Portal then
			return id
		end
		local p = storage[id]
		if p == nil then
			p = Portal(id)
			p.shard_storage = shard_storage
			storage[id] = p
		end
		return p
	end
end

---

return Portal
