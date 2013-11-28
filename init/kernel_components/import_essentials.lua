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


return function()
	local assert = assert
	local error = assert( _G.error )
	local type = assert( _G.type )
	local pcall = assert( _G.pcall )


	local function import_stdlib_extensions_into(t)
		local loadfile = assert( t.loadfile )

		function t.loadmodfile(fname)
			assert( type(fname) == "string", "Non-string given as a file path." )
			return loadfile(MODROOT .. fname)
		end
		local loadmodfile = loadmodfile
		
		function t.domodfile(fname)
			return assert( loadmodfile(fname) )()
		end
	end

	local function import_stdlib_patches_into(t)
		local function loadfile(fname)
			assert( type(fname) == "string", "Non-string given as a file path." )

			local status, f = pcall(_G.kleiloadlua, fname)
		
			if not status or type(f) ~= "function" then
				if f then
					return nil, tostring(f)
				else
					return nil, ("Can't load " .. fname)
				end
			else
				return f
			end
		end


		t.loadfile = loadfile

		t.dofile = function(fpath)
			return assert( loadfile(fpath) )()
		end
	end

	local function import_stdlib_into(t)
		t.assert = assert( _G.assert )
	--	t.collectgarbage = assert( _G.collectgarbage )
		-- dofile() gets set up later
		t.error = assert( _G.error )
		t.getfenv = assert( _G.getfenv )
		t.getmetatable = assert( _G.getmetatable )
		t.ipairs = assert( _G.ipairs )
		t.load = assert( _G.load )
		-- loadfile() gets set up later
		t.loadstring = assert( _G.loadstring )
		t.module = assert( _G.module )
		t.next = assert( _G.next )
		t.pairs = assert( _G.pairs )
		t.pcall = assert( _G.pcall )
		t.print = assert( _G.print )
		t.rawequal = assert( _G.rawequal )
		t.rawget = assert( _G.rawget )
		t.rawset = assert( _G.rawset )
		t.require = assert( _G.require )
		t.select = assert( _G.select )
		t.setfenv = assert( _G.setfenv )
		t.setmetatable = assert( _G.setmetatable )
		t.tonumber = assert( _G.tonumber )
		t.tostring = assert( _G.tostring )
		t.type = assert( _G.type )
		t.unpack = assert( _G.unpack )
		t.xpcall = assert( _G.xpcall )

		t.coroutine = assert( _G.coroutine )
		t.debug = assert( _G.debug )
		t.io = assert( _G.io )
		t.math = assert( _G.math )
		t.package = assert( _G.package )
		t.string = assert( _G.string )
		t.table = assert( _G.table )

		t.os = {}
		assert( _G.os )
		for _, k in ipairs {
			"clock",
			"date",
			"difftime",
			"time",
		} do
			t.os[k] = assert( _G.os[k] )
		end


		t._G = _G

		import_stdlib_patches_into(t)
	end

	-- Works even if this is called on worldgen, etc.
	local function import_game_essentials_into(t)
		--[[
		-- These are loaded right away into the environment.
		-- The main reason for NOT including something here
		-- is if it doesn't exist during worldgen.
		--]]
		local mandatory_imports = {
			"print",

			"Class",
			"Vector3",
			"Point",
			"TUNING",
			"STRINGS",
			"GROUND",
			
			"distsq",

			"Prefab",
		}
		--[[
		-- These are loaded on the fly, IF they exist.
		--]]

		local optional_imports = {
			"nolineprint",

			"TheSim",
			"SaveIndex",
			"SaveGameIndex",

			"LEVELTYPE",
			"KEYS",
			"LOCKS",

			"EntityScript",
			"CreateEntity",
			"SpawnPrefab",
			"DebugSpawn",
			"PrefabExists",

			"GetTime",
			
			"GetPlayer",
			"GetWorld",
			"GetClock",
			"GetSeasonManager",

			"GetGroundTypeAtPosition",
		}

		local import_filter = {}
		for _, k in ipairs(mandatory_imports) do
			import_filter[k] = true
		end
		for _, k in ipairs(optional_imports) do
			import_filter[k] = true
		end

		AttachMetaIndex(LazyCopier(_G, import_filter), t)

		for _, k in ipairs(mandatory_imports) do
			assert( rawget(_G, k) ~= nil, ("The mandatory import %q doesn't exist!"):format(k) )
			assert( t[k] ~= nil )
		end

		if not VarExists("nolineprint") then
			function _M.nolineprint(...)
				return print(...)
			end
		end

		t.GLOBAL = _G
	end


	function ImportEssentialsInto(t)
		import_stdlib_into(t)
		import_stdlib_extensions_into(t)
		import_game_essentials_into(t)
	end
	AddVariableCleanup("ImportEssentialsInto")
end
