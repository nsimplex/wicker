--[[
-- Abstracts over the connection of shards through portals.
--]]

local Lambda = wickerrequire "paradigms.functional"
local Debuggable = wickerrequire "adjectives.debuggable"
local Pred = wickerrequire "lib.predicates"

---

local Shard = wickerrequire "daemons.shardgraph.shard"
local Portal = wickerrequire "daemons.shardgraph.portal"

---

local function emptyadj()
	return {}
end

local ShardGraph = Class(Debuggable, function(self)
	Debuggable._ctor(self, "ShardGraph", false)

	self.raw_shards = {}
	self.shard = Shard.NewShardStorage(self, self.raw_shards)

	self.raw_portals = {}
	self.portal = Portal.NewPortalStorage(self, self.raw_portals, self.shard)

	self.allow_loops = false

	-- Arcs. Maps to portals.
	self.adjs = {
		[self.shard(GetShardId())] = emptyadj()
	}
end)
Pred.IsShardGraph = Pred.IsInstanceOf(ShardGraph)

function ShardGraph:CountVertices()
	return cardinal(self.adjs)
end

function ShardGraph:CountArcs()
	return Lambda.Fold(Lambda.Add, pairs(self.adjs))
end

function ShardGraph:__tostring()
	local n, m = self:CountVertices(), self:CountArcs()
	return ("ShardGraph (n = %d, m = %d)"):format(n, m)
end

function ShardGraph:GetInfoString()
	local msg = {
		"Vertices:",
	}

	for u in pairs(self.adjs) do
		table.insert(msg, u:GetDebugString())
	end

	table.insert(msg, "")
	table.insert(msg, "Arcs:")
	for u, adj in pairs(self.adjs) do
		for v, p in pairs(adj) do
			table.insert(msg, tostring(p))
		end
	end

	return table.concat(msg, "\n")
end

function ShardGraph:GetDebugString()
	return tostring(self).."\n\n"..self:GetInfoString()
end

function ShardGraph:GetVertex(id)
	return self.raw_shards[id]
end
ShardGraph.GetShard = ShardGraph.GetVertex

function ShardGraph:GetArc(id)
	return self.raw_portals[id]
end
ShardGraph.GetPortal = ShardGraph.GetArc

local function AddShard(self, sh)
	return self.shard(sh)
end

local function AddPortal(self, p)
	p = self.portal(p)

	assert(p)

	local sp, ep = p:get()
	if sp ~= nil and ep ~= nil then
		local adj = self.adjs[sp]
		if adj == nil then
			adj = emptyadj()
			self.adjs[sp] = adj
		end
		adj[ep] = p
	end

	return p
end

local function RemoveArc(self, sp, ep)
	local adj = self.adjs[sp]
	if adj ~= nil then
		local p = adj[ep]
		adj[ep] = nil
		return p
	end
end

function ShardGraph:GetArcLabel(sp, ep)
	local adj = self.adjs[sp]
	if adj == nil then return end
	return adj[ep]
end

-- For internal usage. Receives the prior vertex pair and the old dual.
function ShardGraph:UpdatePortal(p, u1, v1)
	if u1 ~= nil and v1 ~= nil then
		u1, v1 = self.shard(u1), self.shard(v1)
		RemoveArc(self, u1, v1)
	end
	AddPortal(p)
end

---

local TheShardGraph = ShardGraph()

---

---
-- Patches
--

if IsDST() then
	require "shardnetworking"

	local Shard_UpdateWorldState = assert( _G.Shard_UpdateWorldState )
	_G.Shard_UpdateWorldState = function(world_id, state, ...)
		AddShard(TheShardGraph, world_id):UpdateWorldState(state, ...)

		local rets = {Shard_UpdateWorldState(world_id, state, ...)}

		if TheShardGraph:Debug() then
			TheShardGraph:Say("updated world state:\n", TheShardGraph:GetInfoString())
		end
	end

	local Shard_UpdatePortalState = assert( _G.Shard_UpdatePortalState )
	_G.Shard_UpdatePortalState = function(inst, ...)
		local wm = inst and inst.components.worldmigration
		if wm then
			assert( wm.id )
			AddPortal(TheShardGraph, wm.id):SetEntity(inst)
		end
		return Shard_UpdatePortalState(inst, ...)
	end
end

---

return TheShardGraph
