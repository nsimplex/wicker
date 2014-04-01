local Common = pkgrequire "common"
Common.Topology = _M
Common.topology = _M


local Lambda = wickerrequire "paradigms.functional"
local Pred = wickerrequire "lib.predicates"
local table = wickerrequire "utils.table"

local Geo = wickerrequire "math.geometry"


local define_road_stuff

local built_road_data = false

local GetRoadsData = (function()
	local roads

	AddModPostInit(function()
		TheMod:AddGamePostInit(function()
			if _G.GetWorld() then
				local SI = assert( _G.SaveGameIndex )
				SI:GetSaveData(SI:GetCurrentSaveSlot(), SI:GetCurrentMode(), function(savedata)
					roads = assert( savedata.map.roads )
					define_road_stuff(roads)
				end)
			end
		end)
	end)

	return function()
		return roads
	end
end)()


local function build_road_curves(roads)
	local road_parts = {}

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

local run_road_postinits

define_road_stuff = function(roads)
	build_road_curves(roads)
	built_road_data = true
	run_road_postinits()
end


AddRoadDataPostInit = (function()
	local fns = {}

	run_road_postinits = function()
		for _, fn in ipairs(fns) do
			fn()
		end
		fns = {}
	end

	return function(fn)
		table.insert(fns, fn)
		if built_road_data then
			run_road_postinits()
		end
	end
end)()
