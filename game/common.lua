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


local EntityScript = EntityScript
local Point = Point




local Lambda = wickerrequire 'paradigms.functional'
local Logic = wickerrequire 'lib.logic'

local Pred = wickerrequire 'lib.predicates'

local Math = wickerrequire "math"


ToPoint = Math.ToPoint
local ToPoint = ToPoint

ToComplex = Math.ToComplex
local ToComplex = ToComplex

function Move(inst, x, y, z)
	local pt = ToPoint(x, y, z)

	if inst.Physics then
		inst.Physics:Teleport( pt:Get() )
	elseif inst.Transform then
		inst.Transform:SetPosition( pt:Get() )
	end
end
MoveTo = Move

function DistanceSqToNode(pt, node)
	pt = ToPoint(pt)

	local dx, dy, dz = pt.x - node.cent[1], pt.y, pt.z - node.cent[2]

	return dx*dx + dy*dy + dz*dz
end

DistanceToNode = Lambda.Compose(math.sqrt, DistanceSqToNode)

function ListenForEventOnce(inst, event, fn, source)
	-- Currently, inst2 == source, but I don't want to make that assumption.
	local function gn(inst2, data)
		inst:RemoveEventCallback(event, gn, source)
		return fn(inst2, data)
	end
	
	return inst:ListenForEvent(event, gn, source)
end


AddSelfPostInit(function()
	pkgrequire "searching"
end)
