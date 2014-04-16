local Common = pkgrequire "common"


local Lambda = wickerrequire "paradigms.functional"
local Pred = wickerrequire "lib.predicates"
local table = wickerrequire "utils.table"

local Geo = wickerrequire "math.geometry"


local function GetRoadsData()
	local roads = rawget(_G, "Roads")
	if not roads then
		return OuterError("Attempt to fetch road data before it is available.")
	end
	return roads
end


local function build_road_curves(roads)
	local road_parts = {}

	local Point = Point

	local function process_road(road_data)
		if road_data[1] ~= 3 then
			-- trail
			return
		end

		local vertices = Lambda.CompactlyMap(function(pt)
			return Point(pt[1], 0, pt[2])
		end, table.ipairs(road_data, 2))

		table.insert(road_parts, Geo.Curves.PolygonalPathFromTable(vertices))
	end

	for _, road_data in pairs(roads) do
		process_road(road_data)
	end

	_M.TheRoad = Geo.Curves.Concatenate(road_parts)
end

local function define_road_stuff()
	define_road_stuff = Lambda.Error("Attept to redefine road structures.")

	local roads = GetRoadsData()

	build_road_curves(roads)

	if TheMod then
		TheMod:DebugSay("Finished building road structures.")
	end
end

AddLazyVariable("TheRoad", function() define_road_stuff end)
