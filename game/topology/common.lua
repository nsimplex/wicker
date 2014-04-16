--[[
-- Information about the world topology.
--]]

local Lambda = wickerrequire "paradigms.functional"

local GameCommon = wickerrequire "game.common"


local rooms = require "map/rooms"
local levels = require "map/levels"


--[[
-- Keys in the return value of "map/levels" corresponding to arrays of levels.
--]]
local leveltype_keys = {
	"sandbox_levels",
	"cave_levels",
	"custom_levels",
	"story_levels",
}


function GetWorldTopology()
	local w = GetWorld()
	return w and w.topology
end
local GetWorldTopology = GetWorldTopology

function GetWorldMeta()
	local w = GetWorld()
	return w and w.meta
end
local GetWorldMeta = GetWorldMeta

function IsWorldInitialized()
	return GetWorldMeta() ~= nil
end
IsWorldInitialised = IsWorldInitialized
local IsWorldInitialized = IsWorldInitialized


function GetNodes()
	local topo = GetWorldTopology()
	
	if not topo then
		return {}
	end
	
	return assert( topo.nodes )
end
local GetNodes = GetNodes

function IsValidNode(node)
	local t = node.type
	return t == "START" or rooms[t]
end
local IsValidNode = IsValidNode

GetValidNodes = (function()
	local valid_nodes

	return function()
		if not valid_nodes then
			valid_nodes = Lambda.CompactlyFilter(IsValidNode, ipairs(GetNodes()))
		end
		return valid_nodes
	end
end)()
local GetValidNodes = GetValidNodes


function GetCurrentLevelId()
	local meta = GetWorldMeta()
	return meta and meta.level_id
end
local GetCurrentLevelId = GetCurrentLevelId

GetCurrentLevelData = (function()
	local data

	return function()
		if not data then
			local id = GetCurrentLevelId()
			if not id then
				return error("Unable to find current level id.")
			end
			for _, leveltypekey in ipairs(leveltype_keys) do
				for _, level in pairs(levels[leveltypekey]) do
					if level.id == id then
						data = level
						return data
					end
				end
			end
			return error("Unable to find current level data.")
		end
		return data
	end
end)()
local GetCurrentLevelData = GetCurrentLevelData


GetStartNodeId = (function()
	local computed = false
	local start_node_id

	return function()
		if not computed then
			computed = true
			local curlevel = GetCurrentLevelData()
			for _, override in ipairs(curlevel.overrides) do
				if override[1] == "start_node" then
					start_node_id = override[2]
					break
				end
			end
		end
		return start_node_id
	end
end)()

GetStartNodeData = (function()
	local data

	return function()
		if not data then
			local start_node_id = GetStartNodeId()

			if start_node_id then
				data = rooms[start_node_id]
			end

			if not data then
				TheMod:DebugSay("Custom start_node not found, adopting default one.")

				-- Simplified default node, see vanilla's map/storygen.lua.
				data = {
					value = GROUND.GRASS,								
					terrain_contents={
						countprefabs = {
							spawnpoint=1,
							sapling=1,
							flint=1,
							berrybush=1, 
							grass=3
						} 
					}
				 }
			 end
		end
		return data
	end
end)()
local GetStartNodeData = GetStartNodeData

function GetNodeId(node)
	if node then
		local ty = node.type
		if ty == "START" then
			return GetStartNodeId()
		else
			return ty
		end
	end
end
local GetNodeId = GetNodeId

function GetNodeData(node)
	if node then
		local ty = node.type
		if ty == "START" then
			return GetStartNodeData()
		else
			return rooms[ty]
		end
	end
end
local GetNodeData = GetNodeData

-- Returns first id, then data.
function GetNodeRoom(node)
	return GetNodeId(node), GetNodeData(node)
end


function GetNodeOf(x, y, z)
	local pt = GameCommon.ToPoint(x, y, z)

	local real_x, real_z = pt.x, pt.z

	local best_node, min_dsq

	for _, node in ipairs(GetValidNodes()) do
		local dx, dz = real_x - node.x, real_z - node.y
		local dsq = dx*dx + dz*dz
		if not best_node or dsq < min_dsq then
			best_node, min_dsq = node, dsq
		end
	end

	return best_node
end
GetNodeAt = GetNodeOf
local GetNodeOf = GetNodeOf

GetRoomNameOf = Lambda.Compose(GetNodeId, GetNodeOf)
GetRoomNameAt = GetRoomNameOf
local GetRoomNameOf = GetRoomNameOf

GetRoomDataOf = Lambda.Compose(GetNodeData, GetNodeOf)
GetRoomDataAt = GetRoomDataOf
local GetRoomDataOf = GetRoomDataOf

GetRoomOf = Lambda.Compose(GetNodeRoom, GetNodeOf)
GetRoomAt = GetRoomOf
local GetRoomOf = GetRoomOf


--------------


--[[
-- Returns the minimum square distance between a point and a line segment.
--]]
local function distsq_point_to_line_segment(pt, seg_start, seg_end)
	--[[
	-- All "lengths" below are actually the square of them.
	--]]
	
	local base = seg_start
	-- Not normalized.
	local dir = seg_end - seg_start

	local seg_len = dir:LengthSq()
	
	--[[
	-- Coefficient of the projection.
	--]]
	local t = dir:Dot(pt - base)

	if t <= 0 then
		return pt:DistSq(seg_start)
	elseif t >= seg_len then
		return pt:DistSq(seg_end)
	else
		return pt:DistSq(base + dir*(t/seg_len))
	end
end


--[[
-- Receives a topology node and returns its inradius, i.e. the maximum
-- radius of a circle placed in its center such that the circle is completely
-- contained in the node.
--]]
GetNodeInradius = (function()
	local function CalculateInradius(node)
		local r2 = math.huge

		local center = Vector3(node.cent[1], 0, node.cent[2])

		local poly = node.poly
		local n_vertices = #poly
		for i, vertex1 in ipairs(poly) do
			local vertex2 = assert( poly[(i % n_vertices) + 1] )

			r2 = math.min(
				r2,
				distsq_point_to_line_segment(center, Vector3(vertex1[1], 0, vertex1[2]), Vector3(vertex2[1], 0, vertex2[2]))
			)
		end

		assert( r2 < math.huge )
		return math.sqrt(r2)
	end

	local inradii = setmetatable({}, {
		__index = function(t, k)
			local v = CalculateInradius(k)
			t[k] = v
			return v
		end,
	})

	return Lambda.Getter(inradii)
end)()
GetNodeInRadius = GetNodeInradius
