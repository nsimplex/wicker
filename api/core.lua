--[[
-- Avoid tail calls like hell.
--]]

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

--@@NO ENVIRONMENT BOOTUP
local _modname = assert( (assert(..., 'This file should be loaded through require.')):match('^[%a_][%w_%s]*') , 'Invalid path.' )


-- Returns the global environment followed by assert.
local function get_essential_values()
	local function crash()
		return ({})[nil]
	end

	local _G = _G or GLOBAL or crash()
	local assert = _G.assert or crash()

	return _G, assert
end


local _G, assert = get_essential_values()

local debug = assert( _G.debug )
local error = assert( _G.error )
local getmetatable = assert( _G.getmetatable )
local pcall = assert( _G.pcall )
local package = assert( _G.package )
local rawget = assert( _G.rawget )
local rawset = assert( _G.rawset )
local require = assert( _G.require )
local select = assert( _G.select )
local setmetatable = assert( _G.setmetatable )
local tostring = assert( _G.tostring )
local type = assert( _G.type )
local unpack = assert( _G.unpack )
local xpcall = assert( _G.xpcall )

local module = assert( _G.module )


module(...)

local _M = _M
_M._modname = _modname


function IsWorldgen()
	return rawget(_G, "SEED") ~= nil
end

IsWorldGen = IsWorldgen


-- Returns an __index metamethod.
function LazyCopier(source, filter)
	if not filter then
		return function(t, k)
			local v = source[k]
			if v ~= nil then
				rawset(t, k, v)
			end
			return v
		end
	elseif type(filter) == "table" then
		return function(t, k)
			if filter[k] then
				local v = source[k]
				if v ~= nil then
					rawset(t, k, v)
				end
				return v
			end
		end
	elseif type(filter) == "function" then
		return function(t, k)
			if filter(k) then
				local v = source[k]
				if v ~= nil then
					rawset(t, k, v)
				end
				return v
			end
		end
	else
		return error("Invalid filter given to LazyCopier.")
	end
end
local LazyCopier = LazyCopier

function AttachMetaIndex(fn, object)
	local meta = getmetatable( object )

	if not meta then
		meta = {}
		setmetatable( object, meta )
	end

	local oldfn = meta.__index

	if type(oldfn) == "function" then
		meta.__index = function(object, k)
			local v = fn(object, k)
			if v ~= nil then
				return v
			else
				return oldfn(object, k)
			end
		end
	elseif type(oldfn) == "table" then
		meta.__index = function(object, k)
			local v = fn(object, k)
			if v ~= nil then
				return v
			else
				return oldfn[k]
			end
		end
	else
		meta.__index = fn
	end

	return object
end
local AttachMetaIndex = AttachMetaIndex


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
		"nolineprint",

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

	t.GLOBAL = _G
end


function RobustlyCall(f, ...)
	--[[
	local Args = {...}

	local Rets = { xpcall(function()
		return f( unpack(Args) )
	end, debug.traceback) }

	if not Rets[1] then
		return error(Rets[2])
	else
		return select(2, unpack(Rets))
	end
	]]--
	return f(...)
end
local RobustlyCall = RobustlyCall


local function raw_bootstrapper(wicker_stem)
	_M.wicker_stem = wicker_stem

	import_stdlib_into(_M)
	import_game_essentials_into(_M)

	-- Returns a unique key.
	GetModKey = (function()
		local k = {}
		return function()
			return k
		end
	end)()
	local GetModKey = GetModKey
	
	function GetModname()
		return _modname
	end
	local GetModName = GetModname
	
	function GetWickerStem()
		return wicker_stem
	end
	local GetWickerStem = GetWickerStem
	
	
	function AssertEnvironmentValidity(env)
		assert( env.GetModname == nil or env.GetModname() == GetModname(), env._NAME )
		assert( env._modname == nil or env._modname == GetModname(), env._NAME )
		assert( env.GetModKey == nil or env.GetModKey() == GetModKey(), env._NAME )
		assert( env.TheMod == nil or _M.TheMod == nil or env.TheMod == _M.TheMod, env._NAME )
		assert( modenv == nil or env.modname == nil or env.modname == modenv.modname )
	end
	local AssertEnvironmentValidity = AssertEnvironmentValidity
	
	local function prefixed_require(prefix, name)
		assert( type(prefix) == "string" )
		assert( type(name) == "string", "Package name is not a string." )
		local M = require(prefix .. '.' .. name)
		if type(M) == "table" then
			AssertEnvironmentValidity( M )
		end
		return M
	end
	
	
	local loader_metadata = {}
	
	loader_metadata[require] = {name = 'require', category = 'Module'}
	
	loader_metadata[function(t) return t end] = {name = 'GetTable', category = 'Table'}
	
	-- This should be hidden as soon as possible.
	function TheCore()
		return _M
	end
	local TheCore = TheCore
	loader_metadata[TheCore] = {name = 'TheCore', category = 'TheCore'}
	
	function wickerrequire(name)
		local M = require(GetWickerStem() .. '.' .. tostring(name))
		if type(M) == "table" then
			AssertEnvironmentValidity( M )
		end
		return M
	end
	local wickerrequire = wickerrequire
	wickerequire = wickerrequire
	loader_metadata[wickerrequire] = {name = 'wickerrequire', category = 'WickerModule'}
	
	function modrequire(name)
		local M = require(GetModname() .. '.' .. tostring(name))
		if type(M) == "table" then
			AssertEnvironmentValidity( M )
		end
		return M
	end
	local modrequire = modrequire
	loader_metadata[modrequire] = {name = 'modrequire', category = 'ModModule'}
	
	function GetTheMod()
		local M = wickerrequire 'api.themod'
		return M
	end
	local GetTheMod = GetTheMod
	loader_metadata[GetTheMod] = {name = 'GetTheMod', category = 'TheMod'}
	
	function InjectNonPrivatesIntoTableIf(p, t, f, s, var)
		for k, v in f, s, var do
			if type(k) == "string" and not k:match('^_') then
				if p(k, v) then
					t[k] = v
				end
			end
		end
		return t
	end
	local InjectNonPrivatesIntoTableIf = InjectNonPrivatesIntoTableIf
	
	function InjectNonPrivatesIntoTable(t, f, s, var)
		t = InjectNonPrivatesIntoTableIf(function() return true end, t, f, s, var)
		return t
	end
	local InjectNonPrivatesIntoTable = InjectNonPrivatesIntoTable
	
	local function trace_error(msg)
		return error(msg .. "\n" .. debug.traceback())
	end
	
	-- Returns the index (relative to the calling function) in the Lua stack of the last function with a different environment than the outer function.
	-- It uses the Lua side convention for indexes, which are nonnegative and count from top to bottom.
	--
	-- It defaults to 2 because it shouldn't be used directly from outside this module.
	--
	-- We should always reach the global environment, which prevents an infinite loop.
	-- Ignoring errors is needed to pass over tail calls (which trigger them).
	--
	-- This could be written much more cleanly and robustly at the C/C++ side.
	-- The real setback is that Lua doesn't tell us what the stack size is.
	local function GetNextEnvironmentThreshold(i)
		assert( i == nil or (type(i) == "number" and i > 0 and i == math.floor(i)) )
		i = (i or 1) + 1
	
		local env
	
		local function get_first()
			local status
	
			status, env = pcall(getfenv, i + 2)
			if not status then
				trace_error('Unable to get the initial environment!')
			end
			i = i + 1
	
			return env
		end
	
		local function get_next()
			local status
			
			while not status do
				status, env = pcall(getfenv, i + 2)
				i = i + 1
			end
	
			return env
		end
	
		local first_env = get_first()
		if first_env == _G then
			trace_error('The initial environment is the global environment!')
		end
	
		assert( env == first_env )
	
		while env == first_env do
			env = get_next()
		end
		i = i - 1
	
		if env == _G then
			trace_error('Attempt to reach the global environment!')
		elseif env == _M then
			trace_error('Attempt to reach the core environment!')
		end
	
		-- No, this is not a typo. The index should be subtracted twice.
		-- The subtractions just have different meanings.
		return i - 1, env
	end
	
	-- Counts from 0 up, with 0 meaning the innermost environment different than the caller's.
	function GetEnvironmentLayer(n)
		assert( type(n) == "number" )
		assert( n >= 0 )
	
		local i, env = GetNextEnvironmentThreshold()
		for _ = 1, n do
			i, env = GetNextEnvironmentThreshold(i)
		end
	
		return env, i - 1
	end
	local GetEnvironmentLayer = GetEnvironmentLayer
	
	function GetOuterEnvironment()
		local env, i = GetEnvironmentLayer(0)
		return env, i - 1
	end
	
	local GetOuterEnvironment = GetOuterEnvironment
	
	function pkgrequire(name)
		assert( type(name) == "string" )
		
		local env = GetOuterEnvironment()
		assert( env )
		assert( type(env._PACKAGE) == "string" )
	
		local M = require( env._PACKAGE:gsub("%.+$", "") .. '.' .. name )
	
		if type(M) == "table" then
			AssertEnvironmentValidity( M )
		end
	
		return M
	end
	local pkgrequire = pkgrequire
	loader_metadata[pkgrequire] = {name = 'pkgrequire', category = 'ModPackage'}
	
	local function GetDebugInfo()
		local i = GetNextEnvironmentThreshold()
		if i then
			return debug.getinfo(i, 'Sl')
		end
	end
	
	function InjectNonPrivatesIntoEnvironmentIf(p, f, s, var)
		local env = GetOuterEnvironment()
		assert( env )
		InjectNonPrivatesIntoTableIf( p, env, f, s, var  )
	end
	
	function InjectNonPrivatesIntoEnvironment(f, s, var)
		InjectNonPrivatesIntoEnvironmentIf(function() return true end, f, s, var)
	end
	
	local function push_loader_error(loader, what)
		if type(what) == "string" then
			what = "'" .. what .. "'"
		else
			what = tostring(what or "")
		end
		local info = GetDebugInfo() or {}
		return error(  ("The %s(%s) call didn't return a table at:\n%s:%d"):format( loader_metadata[loader].name, what, info.source or "?", info.currentline or 0 )  )
	end
	
	
	
	
	
	local advanced_prototypes = {}

	local function normalize_args(env, what)
		if type(env) == "table" and env._PACKAGE then
			return env, what
		else
			return GetOuterEnvironment(), env
		end
	end
	
	function advanced_prototypes.Inject(loader)
		assert( type(loader) == "function" )
		assert( type(loader_metadata[loader].name) == "string" )
	
		return function(env, what)
			env, what = normalize_args(env, what)

			local M = loader(what)
			if type(M) ~= "table" then
				push_loader_error(loader, what)
			end

			InjectNonPrivatesIntoTable( env, pairs(M) )
		end
	end
	
	function advanced_prototypes.Bind(loader)
		assert( type(loader) == "function" )
		assert( type(loader_metadata[loader].name) == "string" )
	
		return function(env, what)
			env, what = normalize_args(env, what)

			local M = loader(what)
			if type(M) ~= "table" then
				push_loader_error(loader, what)
			end
	
			AttachMetaIndex( LazyCopier(M), env )	
	
			return M
		end
	end
	
	function advanced_prototypes.Become(loader)
		assert( type(loader) == "function" )
		assert( type(loader_metadata[loader].name) == "string" )
	
		return function(what)
			local M = loader(what)
			if type(M) ~= "table" then
				push_loader_error(loader, what)
			end
			local env, i = GetOuterEnvironment()
			assert( type(i) == "number" )
			assert( i >= 2 )
			local status, err = pcall(setfenv, i + 1, M)
			if not status then
				trace_error(err)
			end
			return M
		end
	end
	
	for action, prototype in pairs(advanced_prototypes) do
		for loader, info in pairs(loader_metadata) do
			_M[action .. info.category] = prototype(loader)
		end
	end
	
	assert( InjectTheCore )
	assert( BindTheCore )
	assert( BecomeTheCore )
	BecomeTheCore = nil
	
	assert( InjectTheMod )
	assert( BindTheMod )
	assert( BecomeTheMod )
	
	
	local loadfile = loadfile
	
	function loadmodfile(fname)
		assert( type(fname) == "string", "Non-string given as a file path." )
		return loadfile(MODROOT .. fname)
	end
	local loadmodfile = loadmodfile
	
	function domodfile(fname)
		return assert( loadmodfile(fname) )()
	end
	
	
	package.loaded[_NAME] = BindTheCore
	package.loaded[_modname .. '.booter'] = BindTheCore
	return BindTheCore
end


return function(...)
	return RobustlyCall(raw_bootstrapper, ...)
end
