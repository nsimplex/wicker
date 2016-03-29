-- TODO: pass parent objects to Shard and Portal

--[[
-- Abstracts over the connection of shards through portals.
--]]

local Lambda = wickerrequire "paradigms.functional"
local Debuggable = wickerrequire "adjectives.debuggable"
local Pred = wickerrequire "lib.predicates"

---

local Shard = wickerrequire "gadgets.shard"
local Portal = wickerrequire "gadgets.portal"

---

local function emptyadj()
	return {}
end

local ShardGraph = Class(Debuggable, function(self)
	Debuggable._ctor(self, "ShardGraph", false)

	self.raw_shards = {}
	self.shard = Shard.NewShardStorage(self.raw_shards)

	self.raw_portals = {}
	self.portal = Portal.NewPortalStorage(self.raw_portals, self.shard)

	self.allow_loops = false

	-- Arcs. Maps to portals.
	self.arcs = {
		[self.shard(GetShardId())] = emptyadj()
	}
end)

function ShardGraph:CountVertices()
	return cardinal(self.adjs)
end

function ShardGraph:CountArcs()
	return Lambda.Fold(Lambda.Add, pairs(self.adjs))
end

function ShardGraph:__tostring()
	local n, m = self:CountVertices(), self:CountArcs()
	local msg = {
		("ShardGraph (n = %d, m = %d)"):format(n, m),
		"",
		"Vertices:",
	}

	for u in pairs(self.adjs) do
		table.insert(msg, tostring(u))
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

function ShardGraph:AddVertex(sh)
	return self.shard(sh)
end

function ShardGraph:AddArc(sp, ep, p)
	assert(p)

	local adj = self.arcs[sp]
	if adj == nil then
		adj = emptyadj()
		self.arcs[sp] = adj
	end
	adj[ep] = p
	return p
end

function ShardGraph:GetArc(sp, ep)
	local adj = self.arcs[sp]
	if adj == nil then return end
	return adj[ep]
end

---

local function makeAccessTable(g)
	
end

local TheShardGraph = ShardGraph()

---

---
-- Patches
--

if IsDST() then
	require "shardnetworking"

	local Shard_UpdateWorldState = assert( _G.Shard_UpdateWorldState )
	_G.Shard_UpdateWorldState = function(world_id, state, ...)
		TheShardGraph.shard(world_id):UpdateWorldState(state, ...)
		return Shard_UpdateWorldState(world_id, state, ...)
	end

	local Shard_UpdatePortalState = assert( _G.Shard_UpdatePortalState )
	_G.Shard_UpdatePortalState = function(inst, ...)

		return Shard_UpdatePortalState(inst, ...)
	end
end

---

return TheShardGraph
