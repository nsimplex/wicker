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


require 'util'
require 'map/terrain'

local Asset = _G.Asset

local tiledefs = require 'worldtiledefs'
local GROUND = _G.GROUND
local GROUND_NAMES = _G.GROUND_NAMES

local resolvefilepath = _G.resolvefilepath

local softresolvefilepath
if VarExists("softresolvefilepath") then
	softresolvefilepath = _G.softresolvefilepath
else
	softresolvefilepath = function(path)
		local status, ret = pcall(resolvefilepath, path)
		return status and ret
	end
end


--[[
-- The return value from this function should be stored and
-- reused between saves (otherwise the tile information saved in the map may
-- become mismatched if the order of ground value generation changes).
--]]
local function getNewGroundValue(id)
	local used = {}

	for k, v in pairs(GROUND) do
		used[v] = true
	end

	local i = 1
	while used[i] and i < GROUND.UNDERGROUND do
		i = i + 1
	end

	if i >= GROUND.UNDERGROUND then
		-- The game assumes values greater than or equal to GROUND.UNDERGROUND
		-- represent walls.
		return error("No more values available!", 3)
	end

	return i
end


local GroundAtlas = rawget(_G, "GroundAtlas") or function( name )
	return ("levels/tiles/%s.xml"):format(name) 
end

local GroundImage = rawget(_G, "GroundImage") or function( name )
	return ("levels/tiles/%s.tex"):format(name) 
end

local noise_locations = {
	"%s.tex",
	"levels/textures/%s.tex",
}

local function GroundNoise( name )
	local trimmed_name = name:gsub("%.tex$", "")
	for _, pattern in ipairs(noise_locations) do
		local tentative = pattern:format(trimmed_name)
		if softresolvefilepath(tentative) then
				return tentative
		end
	end

	-- This is meant to trigger an error.
	local status, err = pcall(resolvefilepath, name)
	return error(err or "This shouldn't be thrown. But your texture path is invalid, btw.", 3)
end


local function AddAssetsTo(assets_table, specs)
	table.insert( assets_table, Asset( "IMAGE", GroundNoise( specs.noise_texture ) ) )
	table.insert( assets_table, Asset( "IMAGE", GroundImage( specs.name ) ) )
	table.insert( assets_table, Asset( "FILE", GroundAtlas( specs.name ) ) )
end

local function AddAssets(specs)
	AddAssetsTo(tiledefs.assets, specs)
	TheMod:AddPostRun(function()
		modenv.Assets = modenv.Assets or {}
		AddAssetsTo(modenv.Assets, specs)
	end)
end


-- Lists the structure for a tile specification by mapping the possible fields to their
-- default values.
local tile_spec_defaults = {
	noise_texture = "images/square.tex",
	runsound = "dontstarve/movement/run_dirt",
	walksound = "dontstarve/movement/walk_dirt",
	snowsound = "dontstarve/movement/run_ice",
}

-- Like the above, but for the minimap tile specification.
local mini_tile_spec_defaults = {
	name = "map_edge",
	noise_texture = "levels/textures/mini_dirt_noise.tex",
}

--[[
-- name should match the texture/atlas specification in levels/tiles.
-- (it's not just an arbitrary name, it defines the texture used)
--]]
function AddTile(id, numerical_id, name, specs, minispecs)
	assert( type(id) == "string" )
	assert( numerical_id == nil or type(numerical_id) == "number" )
	assert( type(name) == "string" )
	assert( GROUND[id] == nil, ("GROUND.%s already exists!"):format(id))

	specs = specs or {}
	minispecs = minispecs or {}

	assert( type(specs) == "table" )
	assert( type(minispecs) == "table" )

	-- Ideally, this should never be passed, and we would wither generate it or load it
	-- from savedata if it had already been generated once for the current map/saveslot.
	if numerical_id == nil then
		numerical_id = getNewGroundValue()
	else
		for k, v in pairs(GROUND) do
			if v == numerical_id then
				return error(("The numerical value %d is already used by GROUND.%s!"):format(v, tostring(k)), 2)
			end
		end
	end


	GROUND[id] = numerical_id
	GROUND_NAMES[numerical_id] = name


	local real_specs = { name = name }
	for k, default in pairs(tile_spec_defaults) do
		if specs[k] == nil then
			real_specs[k] = default
		else
			-- resolvefilepath() gets called by the world entity.
			real_specs[k] = specs[k]
		end
	end
	real_specs.noise_texture = GroundNoise( real_specs.noise_texture )

	table.insert(tiledefs.ground, {
		GROUND[id], real_specs
	})

	AddAssets(real_specs)


	local real_minispecs = {}
	for k, default in pairs(mini_tile_spec_defaults) do
		if minispecs[k] == nil then
			real_minispecs[k] = default
		else
			real_minispecs[k] = minispecs[k]
		end
	end

	TheMod:AddPrefabPostInit("minimap", function(inst)
		local handle = GLOBAL.MapLayerManager:CreateRenderLayer(
			GROUND[id],
			resolvefilepath( GroundAtlas(real_minispecs.name) ),
			resolvefilepath( GroundImage(real_minispecs.name) ),
			resolvefilepath( GroundNoise(real_minispecs.noise_texture) )
		)
		inst.MiniMap:AddRenderLayer( handle )
	end)

	AddAssets(real_minispecs)


	return real_specs, real_minispecs
end


TheMod:EmbedAdder("Tile", AddTile)


return AddTile
