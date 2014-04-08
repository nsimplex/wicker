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

local assert = assert
local error = error

local Lambda = pkgrequire "common"
pkgrequire "concepts"

function Error(...)
	local Args = {...}
	return function()
		return error( table.concat( Lambda.CompactlyMap(tostring, ipairs(Args)) ), 2 )
	end
end

function Assert(p, ...)
	assert( Lambda.IsFunctional(p), "The assertion predicate should be functional." )
	local Args = {...}
	return function(...)
		local b = p(...)
		return assert( b, b or table.concat( Lambda.CompactlyMap(tostring, ipairs(Args)) ) )
	end
end


-- Receives an iterator over functions.
-- Its return values will be flipped, according to the general convention adopted here.
function FunctionList(f, s, var)
	return function(...)
		Lambda.Apply( Lambda.EvaluationMap(...), f, s, var )
	end
end
