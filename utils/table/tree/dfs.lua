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


local Tree = pkgrequire 'core'

local Lambda = wickerrequire 'paradigms.functional'

local Logic = wickerrequire 'lib.logic'
local Pred = wickerrequire 'lib.predicates'


-- It actually works for arbitrary table graphs.
-- The return list consists of a metadata table
-- followed by the node value.
function Iterator(r, revisit_fn)
	
	local function new_empty_data()
		local ret = {}
		ret.branch = {}
		ret.visited = setmetatable({}, {__mode = 'k'})

		ret.is_initial = true
			
		-- Convenience functions.
		
		ret.branchTop = Lambda.StackGetter( ret.branch )
		ret.branchPop = Lambda.StackPopper( ret.branch )
		ret.branchPush = Lambda.StackPusher( ret.branch )
		ret.branchTopOrEmpty = function()
			return ret.branchTop() or {}
		end
		ret.t = function(t)
			local top = ret.branchTop()
			if top then
				if t ~= nil then
					assert( Tree.IsTree(t) )
					top.t = t
				end
				return top.t
			end
		end
		ret.parent_k = function()
			return ret.branchTopOrEmpty().parent_k
		end
		ret.k = function(k)
			local top = ret.branchTop()
			if top then
				if k ~= nil then top.k = k end
				return top.k
			end
		end
		ret.v = function(v)
			local top = ret.branchTop()
			if top and top.k ~= nil then
				if v ~= nil then
					top.t[top.k] = v
				end
				return top.t[top.k]
			end
		end
		ret.subroot = ret.t

		ret.branchGetAt = function(i)
			if i < 0 then
				i = #ret.branch + i + 1
			end
			return ret.branch[i]
		end

		return ret
	end

	local function initialize_data(data, s)
		assert( data.is_initial )
		data.is_initial = nil
		table.insert(data.branch, {t = s.root, parent_k = nil, k = nil})
		return data
	end

	if Tree.IsSingletonIfTree(r) then
		return Lambda.iterator.SingletonList(new_empty_data(), r)
	end

	local s = {root = r}

	assert( Tree.IsTree(s.root) )

	local function f(s, data)
		if not data then
			data = new_empty_data()
			return data, s.root
		elseif data.is_initial then
			data = initialize_data(data, s)
		end

		local t, k = data.t(), data.k()
		assert( Tree.IsTree(t) )

		k = next(t, k)

		while k == nil do
			data.branchPop()
			if not data.branchTop() then
				return nil
			end
			t = data.t()
			k = next(t, data.k())
		end

		data.k(k)

		--local branch_keys = Lambda.CompactlyMap(function(n) return tostring(n.k) end, ipairs(data.branch))
		--print( 'Current branch: ' .. table.concat( branch_keys, ', ') )

		local v = data.v()

		if Tree.IsTree(v) then
			if data.visited[v] and not (revisit_fn and revisit_fn(v, data)) then
				-- Tail call.
				return f(s, data)
			end
			data.visited[v] = true
			if not Tree.IsSingleton(v) then
				data.branchPush( {t = v, parent_k = k} )
			end
		end

		return data, v
	end

	return f, s, nil
end

return Lambda.GenerateConceptsFromIteration( Iterator, _M )
