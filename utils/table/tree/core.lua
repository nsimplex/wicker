--[[
Copyright (C) 2013  simplex

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.
]]--


--@@ENVIRONMENT BOOTUP
local _modname = assert( (assert(..., 'This file should be loaded through require.')):match('^[%a_][%w_%s]*') , 'Invalid path.' )
module( ..., require(_modname .. '.booter') )

--@@END ENVIRONMENT BOOTUP

local Lambda = wickerrequire 'paradigms.functional'
local Iterator = Lambda.iterator
local Logic = wickerrequire 'paradigms.logic'

local Pred = wickerrequire 'lib.predicates'

local string = wickerrequire 'utils.string'


local Tree

local metadata_spec = {'parent', 'key', 'value'}

local function tree_ctor_from_meta(m)
	return function(t, k, v)
		local datum = {parent = t, key = k, value = v}

		local r = {}
		m.__data[r] = datum
	
		return setmetatable(r, m)
	end
end

local function tree_meta_from_template(f, s, var)
	local metadata = setmetatable({}, {__mode = 'k'})

	local m = {}
	local c = tree_ctor_from_meta(m)

	m.__new = c

	m.__data = metadata

	m.__index = function(t, k)
		local v = c(t, k)
		rawset(t, k, v)
		return v
	end

	m.__call = function(...)
		return Tree.Get(...)
	end

	Lambda.InjectInto(m, f, s, var)
	
	return m
end

local tree_meta = tree_meta_from_template(pairs {})
local weak_tree_meta = tree_meta_from_template(pairs {__mode = 'k'})


Tree = {}

Tree.New = tree_meta.__new

Tree.NewWeak = weak_tree_meta.__new
Tree.WeakNew = Tree.NewWeak

Tree.IsAbstractTree = Lambda.Compose( Lambda.Getter {[tree_meta] = true, [weak_tree_meta] = true}, getmetatable )

Tree.IsTree = Pred.IsTable
Pred.IsTree = Tree.IsTree

-- There are no empty trees with this implementation.
-- Every tree has at least its root as a node.
Tree.IsSingleton = function(t) return next(t) == nil end

Tree.IsSingletonTree = Lambda.And( Tree.IsTree, Tree.IsSingleton )

Tree.IsSingletonIfTree = Lambda.Implies( Tree.IsTree, Tree.IsSingleton )

Tree.IsLeaf = Tree.IsSingletonIfTree

Tree.IsLeafParent = function(t)
	return Tree.IsTree(t) and Logic.ThereExists(Tree.IsLeaf, pairs(t))
end

Tree.GetChild = function(t, k)
	if Tree.IsTree(t) then
		return rawget(t, k)
	end
end

Tree.HasChild = function(t, k)
	return Tree.GetChild(t, k) ~= nil
end

Tree.GetMetaData = function(t)
	if Tree.IsAbstractTree(t) then
		return getmetatable(t).__data[t]
	else
		return {}
	end
end

for _, k in ipairs(metadata_spec) do
	local Name = string.Capitalize(k)
	Tree['Get' .. Name] = function(t)
		return Tree.GetMetaData(t)[k]
	end
	Tree['Set' .. Name] = function(t, v)
		Tree.GetMetaData(t)[k] = v
		return v
	end
end

assert( Lambda.IsFunctional(Tree.GetParent) )

Tree.PredecessorIterator = function(v)
	return function(s, var) return Tree.GetParent(var) end, nil, v
end

Tree.NonStrictPredecessorIterator = function(v)
	return Iterator.AppendTo(Iterator.Singleton(v))(Tree.PredecessorIterator(v))
end

Tree.IsRoot = Lambda.And( Tree.IsAbstractTree, Lambda.Compose(Lambda.IsNil, Tree.GetParent) )

-- If v is not an abstract tree, this will just return nil (because Tree.GetParent will).
Tree.GetRoot = function(v)
	return Tree.IsRoot(v) and v or Lambda.Find( Tree.IsRoot, Tree.PredecessorIterator(v) )
end

Tree.Predecessors = function(v)
	return Lambda.CompactlyInjectInto({}, Tree.PredecessorIterator(v))
end

Tree.NonStrictPredecessors = function(v)
	return Lambda.CompactlyInjectInto({v}, Tree.PredecessorIterator(v))
end

-- Height of a node.
Tree.Height = function(v)
	return Lambda.Fold( function(_, total) return (total or 0) + 1 end, Tree.PredecessorIterator(v) ) or 0
end

-- Height of a subtree.
Tree.SubTreeHeight = function(t)
	return
		(Tree.IsLeaf(t) and 0)
		or (1 + Lambda.Fold( 
			function(v, total)
				return math.max(Tree.SubTreeHeight(v), total)
			end,
			pairs(t)
		))
end

Tree.Get = function(t, k, ...)
	if k == nil then
		return t
	elseif Tree.IsTree(t) then
		t = t[k]
		if t ~= nil then
			-- Tail call.
			return Tree.Get(t, ...)
		end
	end
end

-- The iterator should return the succession of keys.
Tree.IterativeGet = function(t, f, s, var)
	if Logic.ForAll(
		function(k)
			if Tree.IsTree(t) then
				t = t[k]
				return t ~= nil
			end
		end,
		f, s, var
	) then
		return t
	end
end



--[[
-- Conditionally injects a tree T into a table t through its dfs postorder.
-- The tree T may be a metatable-less table, as long as its actually a tree.
--
-- I think this should be in dfs, as part of a more general set of algorithms,
-- but for now it's here (and if it's ever moved, it should be aliased here).
--]]
function Tree.InjectIntoIf(p, t, T)
	for k, v in pairs(T) do
		if p(v, k) then
			if Tree.IsTree(v) then
				if not Tree.IsTree(t[k]) then
					t[k] = {}
				end
				Tree.InjectInto(t[k], v)
			else
				t[k] = v
			end
		end
	end
	return t
end

Tree.InjectInto = Lambda.BindFirst(Tree.InjectIntoIf, Lambda.True)



return Tree
