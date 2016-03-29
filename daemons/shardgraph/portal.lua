--[[
-- Abstraction over a shard migration portal.
--]]

local Lambda = wickerrequire "paradigms.functional"
local Debuggable = wickerrequire "adjectives.debuggable"
local Pred = wickerrequire "lib.predicates"

local getmetatable = getmetatable
local select = select

---

local Shard = wickerrequire "daemons.shardgraph.shard"

---

local default_shard_storage = Shard

local STARTPOINT, ENDPOINT = {}, {}
local ANTIP = {}

local Portal
Portal = Class(Debuggable, function(self, graph, id)
	Debuggable._ctor(self, self, true)

	assert( Pred.IsShardGraph(graph) )
	assert( type(id) == "number" )

	self.graph = graph
	self.id = id

	self.inst = nil

	self[STARTPOINT] = Shard( GetShardId() )
	self[ENDPOINT] = nil
	self[ANTIP] = nil

	self.shard_storage = Lambda.Error "Shard storage unset"
	self.portal_storage = Lambda.Error "Portal storage unset"
end)

local function updateSelf(self, u1, v1)
	return self.graph:UpdatePortal(self, u1, v1)
end

function Portal:__tostring()
	return ("Portal %d (%s -> %s)"):format(self.id, tostring(self:fst()), tostring(self:snd()))
end

function Portal:GetEntity()
	return self.inst
end

function Portal:SetEntity(inst)
	local u1, v1 = self:get()
	self.inst = inst
	updateSelf(self, u1, v1)
end

local function GetWorldMigrator(self)
	local inst = self:GetEntity()
	if inst ~= nil and inst:IsValid() then
		return inst.components.worldmigration
	end
end
if not IsDST() then GetWorldMigrator = Lambda.Nil end

Portal.GetWorldMigrator = GetWorldMigrator

function Portal:GetStartPoint()
	return self[STARTPOINT]
end

local function rawSetStartPoint(sp)
	self[STARTPOINT] = sp and self.shard_storage(sp)
end

function Portal:SetStartPoint(sp)
	local old = self:GetStartPoint()
	rawSetStartPoint(sp)
	updateSelf(self, old, self:GetEndPoint())
end

function Portal:GetEndPoint()
	local wm = GetWorldMigrator(self)
	if wm then
		return wm.linkedWorld and self.shard_storage(wm.linkedWorld)
	else
		return self[ENDPOINT]
	end
end

local function rawSetEndPoint(self, ep)
	ep = ep and self.shard_storage(ep)
	local wm = GetWorldMigrator(self)
	if wm then
		wm.linkedWorld = ep and ep.id
	else
		self[ENDPOINT] = ep
	end
end

function Portal:SetEndPoint(ep)
	local old = self:GetEndPoint()
	rawSetEndPoint(self, ep)
	updateSelf(self, self:GetStartPoint(), old)
end

function Portal:get()
	return self:GetStartPoint(), self:GetEndPoint()
end

function Portal:set(sp, ep)
	local u1, v1 = self:get()

	rawSetStartPoint(self, sp)
	rawSetEndPoint(self, ep)

	updateSelf(self, u1, v1)
end

function Portal:fst(...)
	if select("#", ...) == 0 then
		return self:GetStartPoint()
	else
		return self:SetStartPoint((...))
	end
end

function Portal:snd(...)
	if select("#", ...) == 0 then
		return self:GetEndPoint()
	else
		return self:SetEndPoint((...))
	end
end

function Portal:GetAntiParallel()
	local wm = GetWorldMigrator(self)
	if wm then
		return wm.receivedPortal and self.portal_storage(wm.receivedPortal)
	else
		return self[ANTIP]
	end
end
Portal.GetDual = Portal.GetAntiParallel
Portal.__unm = Portal.GetAntiParallel

function Portal:SetAntiParallel(p)
	p = p and self.portal_storage(p)

	local old = self:GetAntiParallel()
	
	local wm = GetWorldMigrator(self)
	if wm then
		wm.receivedPortal = p and p.id
	else
		self[ANTIP] = p
	end
end
Portal.SetDual = Portal.SetAntiParallel

function Portal:Clear()
	self:set(Shard(GetShardId()), nil)
	self:SetAntiParallel(nil)
end

---

function Portal.NewPortalStorage(graph, storage, shard_storage)
	assert( Pred.IsShardGraph(graph) )
	assert( Pred.IsTable(storage) )
	assert( Pred.IsFunctional(shard_storage) )

	local function portal_storage(id)
		if id == nil then return end

		if getmetatable(id) == Portal then
			return id
		end
		local p = storage[id]
		if p == nil then
			p = Portal(graph, id)
			p.shard_storage = shard_storage
			p.portal_storage = portal_storage
			storage[id] = p
		end
		return p
	end

	return portal_storage
end

---

return Portal
