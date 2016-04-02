--[[
-- A basic implementation of directed multigraphs.
--
-- TODO: continue working on this, rethink what really needs to be represented
-- to propagate to slave shards.
--]]

local Lambda = wickerrequire "paradigms.functional"
local Debuggable = wickerrequire "adjectives.debuggable"
local Pred = wickerrequire "lib.predicates"

---

local rawget, rawset = assert( rawget ), assert( rawget )
local getmetatable, setmetatable = assert( getmetatable ), assert( setmetatable )
local pairs, ipairs = assert( ipairs ), assert( pairs )

---

local defaultArcCoMonad = Lambda.Tuple

---

-- This is the multigraph class, called simply Graph here for brevity.
local Graph = Class(Debuggable, function(self, name, arcW)
	Debuggable._ctor(self, self, false)

	self.name = name or "Graph"

	self:Clear()

	self:SetVertexLabelMap()
	self:SetArcLabelMap()

	self:SetArcCoMonad(arcW)

	self:SetVertexSerializer()
	self:SetArcSerializer()
end)

function Graph:GetName()
	return tostring(self.name)
end

function Graph:SetName(name)
	self.name = name
end

Graph.DEFAULT_GLOBAL_SOURCE_IDX = 1
Graph.DEFAULT_GLOBAL_SINK_IDX = "nil"

Graph.ORIGIN = {}
Graph.NIL_VERTEX = {}

-- Maps special tables to functions returning the corresponding idx.
local SPECIAL_LABELS = {
	[Graph.ORIGIN] = function(self)
		return self.global_source_idx
	end,
	[Graph.NIL_VERTEX] = function()
		return self.global_sink_idx
	end,
}

function Graph:GetVertexIdx(label)
	local handler = SPECIAL_LABELS[label]
	if handler ~= nil then
		return handler(self)
	else
		return self.inv_V[label]
	end
end
local GetVertexIdx = Graph.GetVertexIdx

local function normalize_vertex_label(self, v_label)
	return self.V[GetVertexIdx(self, v_label)]
end

local function normalize_arc_pair(self, src_label, tgt_label)
	if src_label == nil then
		src_label = Graph.ORIGIN
	end
	if tgt_label == nil then
		tgt_label = Graph.NIL_VERTEX
	end
	local src = normalize_vertex_label(self, src_label)
	local tgt = normalize_vertex_label(self, tgt_label)
	return src, tgt
end

-- Vertex used as default origin for arcs.
Graph.global_source = {
	get = function(self)
		return self.V[self.global_source_idx]
	end,
	set = function(self, label)
		if label == nil then
			label = Graph.ORIGIN
		end
		self.global_source_idx = GetVertexIdx(self, label)
	end,
}

-- Vertex used as default destination for arcs.
Graph.global_sink = {
	get = function(self)
		return self.V[self.global_sink_idx]
	end,
	set = function(self, label)
		if label == nil then
			label = Graph.NIL_VERTEX
		end
		self.global_sink_idx = GetVertexIdx(self, label)
	end,
}

-- Returns the idxs of the vertex extremities of an arc.
local function GetArcIdxs(self, label)
	local src, tgt = self:ExtractArc(label)

	if src == nil then
		src = Graph.ORIGIN
	end
	if tgt == nil then
		tgt = Graph.NIL_VERTEX
	end
	
	local src_idx = GetVertexIdx(self, src)
	local tgt_idx = GetVertexIdx(self, tgt)

	return src_idx, tgt_idx
end

function Graph:ExpandArc(label)
	local src_idx, tgt_idx = GetArcIdxs(self, label)
	local V = self.V
	return V[src_idx], V[tgt_idx]
end
local ExpandArc = Graph.ExpandArc

local GetArc = ExpandArc
Graph.GetArc = GetArc

function Graph:UpdateArc(label, src, tgt)
	src, tgt = normalize_arc_pair(self, src, tgt)
	return self:ApplyArc(label, src, tgt)
end
Graph.SetArc = Graph.UpdateArc

function Graph:Clear()
	-- Maps vertex ids to labels.
	self.V = {}
	self.inv_V = {}

	-- Maps arc ids to labels.
	self.A = {}
	self.inv_A = {}

	self.global_source = nil

	self.global_sink = nil
end

---

local function basic_vertex()
	return {}
end

local function basic_arc(src, tgt)
	return {src, tgt}
end

local function default_vertex_label_map(label, self)
	if label == nil then
		return basic_vertex()
	else
		return label
	end
end

local function default_arc_label_map(label, self)
	if label == nil then
		return basic_arc()
	else
		return label
	end
end

local function default_arc_quotient(arc)
	return arc[1], arc[2]
end

local function default_arc_binder(arc, src, tgt)
	arc[1], arc[2] = src, tgt
end

local default_serializer = Lambda.Identity

local default_unserializer = Lambda.Identity

---

function Graph:__tostring()
	return ("%s (n = %d, m = %d)"):format(self:GetName(), self.n, self.m)
end

function Graph:SetVertexLabelMap(fn)
	self.vertex_label_map = fn or default_vertex_label_map
end

function Graph:SetArcLabelMap(fn)
	-- FIXME: THIS IS OBSOLETE!!!
	self.arc_label_map = fn or default_arc_label_map
end

---

--[[
-- https://hackage.haskell.org/package/comonad-5/docs/Control-Comonad.html
--
-- Can be called as a class method on subclasses.
--]]
function Graph:SetArcCoMonad(arcW)
	if not arcW then
		arcW = defaultArcCoMonad
	end

	Lambda.CoMonad.instance(arcW)

	self.arcW = arcW

	-- fmap :: (a -> b) -> (w a -> w b)
	local fmap = assert( arcW.fmap )
	-- apply :: w a -> b -> w b
	local apply = assert( arcW.apply )

	-- extract :: w a -> a
	local extract = assert( arcW.extract )

	function self:ExtractArc(label)
		return extract(label)
	end

	function self:ApplyArc(a_label, src, tgt)
		return apply(a_label, src, tgt)
	end
end

---

function Graph:SetVertexSerializer(write, read)
	assert( Pred.IfAndOnlyIf(write, read) )
	if not write then
		self.vertex_serialize = default_serializer
		self.vertex_unserialize = default_unserializer
	else
		self.vertex_serialize = write
		self.vertex_unserialize = read
	end
end

function Graph:SetArcSerializer(write, read)
	assert( Pred.IfAndOnlyIf(write, read) )
	if not write then
		self.arc_serialize = default_serializer
		self.arc_unserialize = default_unserializer
	else
		self.arc_serialize = write
		self.arc_unserialize = read
	end
end

function Graph:CountVertices()
	return #self.V
end

Graph.n = { get = Graph.CountVertices }

function Graph:vertices()
	return ipairs(self.V)
end

function Graph:CountArcs()
	return #self.A
end

Graph.m = { get = Graph.CountArcs }

local BlessArcListIterator = (function()
	local function g(s, var)
		local self, _f, _s = s[1], s[2], s[3]

		local a_label
		var, a_label = _f(_s, var)

		if var == nil then return end

		return var, a_label, self:GetArc(a_label)
	end

	return function(self, f, s, var)
		return g, {self, f, s}, var
	end
end)()

local function NewArcListIterator(self, arclist)
	return BlessArcListIterator(self, ipairs(arclist))
end

Graph.arcsIn = NewArcListIterator

function Graph:arcs()
	return self:arcsIn(self.A)
end

-- How to set the default arc? pair table. quotient. when.
local function new_getset(array_key, inv_array_key, labelmap_key, cb)
	local function add(self, label)
		local array, inv_array = self[array_key], self[inv_array_key]
		local labelmap = self[labelmap_key]

		label = labelmap(label, self)

		local idx = #array + 1
		array[idx] = label
		inv_array[label] = idx

		if cb then
			cb(self, idx, nil, label)
		end

		return idx
	end

	local function remove_by_idx(self, idx)
		local array, inv_array = self[array_key], self[inv_array_key]

		local oldlabel = array[idx]

		for i = #array, idx + 1, -1 do
			inv_array[array[i]] = i - 1
		end
		table.remove(array, idx)
		inv_array[idx] = nil

		if cb then
			cb(self, idx, oldlabel, nil)
		end
	end

	local function remove_by_label(self, label)
		local labelmap = self[labelmap_key]

		label = labelmap(label, self)

		local idx = self[inv_array_key][label]
		if idx ~= nil then
			return remove_by_idx(self, idx)
		end
	end

	return {
		["Add%s"] = add,
		["Remove%sByIndex"] = remove_by_idx,
		["Remove%s"] = remove_by_label,
		["Remove%sByLabel"] = remove_by_label,
	}
end

local function MakeGetSetMethods(infix, ...)
	for patt, fn in pairs(new_getset(...)) do
		Graph[patt:format(infix)] = fn
	end
end

MakeGetSetMethods("Vertex", "V", "inv_V", "vertex_label_map")

local function filter_arclist(arclist, badarc)
	for i, arc in ipairs(arclist) do
		if arc == badarc then
			table.remove(arclist, i)
			return idx
		end
	end
end

local function onchangearc(self, idx, oldlabel, label)
	local adjs = assert( self.adjs )

	if oldlabel ~= nil then
		assert(label == nil)
		local u, v = self.arc_quotient(oldlabel, self)
		local adj = adjs[u]
		if adj ~= nil then
			local arclist = adj[v]
			if arclist ~= nil then
				filter_arclist(arclist, oldlabel)
			end
		end
	else
		assert(label ~= nil)
		local u, v = self.arc_quotient(label, self)
		local adj = adjs[u]
		if adj == nil then
			adj = emptyadj()
			adjs[u] = adj
		end
		local arclist = adj[v]
		if arclist == nil then
			arclist = emptyarclist()
			adj[v] = arclist
		end
		table.insert(arclist, label)
	end
end

MakeGetSetMethods("Arc", "A", "inv_A", "arc_label_map", onchangearc)

---
-- Serialization
--

local function fmap(f)
	local ipairs = ipairs
	return function(t)
		local u = {}
		for i, v in ipairs(t) do
			u[i] = f(v)
		end
		return u
	end
end

function Graph:SaveVertex(self, v_label)
	return self.vertex_serialize(v_label)
end

function Graph:LoadVertex(self, s_v)
	local v_label = self.vertex_unserialize(s_v)
	return self:AddVertex(v_label)
end

function Graph:SaveArc(self, a_label)
	return self.arc_serialize(a_label)
end

function Graph:LoadArc(self, s_a)
	local a_label = self.arc_unserialize(s_a)
	return self:AddArc(a_label)
end

Graph.SaveVertexList = fmap(Graph.SaveVertex)
Graph.LoadVertexList = fmap(Graph.LoadVertex)

Graph.SaveArcList = fmap(Graph.SaveArc)
Graph.LoadArcList = fmap(Graph.LoadArc)

function Graph:Save(fastmode)
	local vkey, akey
	if fastmode then
		vkey, akey = "V", "A"
	else
		vkey, akey = 1, 2
	end
	return {
		name = not fastmode and self.name or nil,
		[vkey] = self:SaveVertexList(self.V),
		[akey] = self:SaveArcList(self.A),
	}
end

function Graph:Load(data)
	self:Clear()

	if data.name then
		self:SetName(data.name)
	end

	local s_V = data[1] or data.V or {}
	local s_A = data[2] or data.A or {}

	self:LoadVertexList(s_V)
	self:LoadArcList(s_A)
end

---

return Graph
