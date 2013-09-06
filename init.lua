-----
--[[ Wicker ]] VERSION="1.0"
--
-- Last updated: 2013-08-06
-----

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
local error = assert( error )

local require = assert( require )

local type = assert( type )

local table = assert( table )
local pairs = assert( pairs )
local ipairs = assert( ipairs )


--@@NO ENVIRONMENT BOOTUP
local _modname = assert( (assert(..., 'This file should be loaded through require.')):match('^[%a_][%w_%s]*') , 'Invalid path.' )


module(...)


local core_bootstrapper = require(_modname .. '.wicker.api.core')
assert( type(core_bootstrapper) == "function" )
local booter = core_bootstrapper(_PACKAGE:gsub("%.+$", ""))
assert( type(booter) == "function" )
core_bootstrapper = nil


booter(_M)


local core = assert( assert( TheCore )() )
core.TheCore = nil
TheCore = nil



local TheMod = (function()
	local mod_builder = GetTheMod()
	assert( type(mod_builder) == "function" )

	local TheMod = mod_builder()
	local TheModConcept = GetTheMod()

	assert( TheMod ~= TheModConcept )
	assert( TheMod == TheModConcept.TheMod )

	TheMod._modname = GetModname()

	core.TheMod = TheMod
	core.TheModConcept = TheModConcept

	return TheMod
end)()


AssertEnvironmentValidity(_M)


-- Additions to core from mod environments.
local core_env_additions = {}


local function raw_init(env, overwrite)
	AssertEnvironmentValidity(_M)
	
	if overwrite == nil then overwrite = true end

	core.InjectNonPrivatesIntoTableIf(function(k, v)
		local kl = k:lower()
		if (core[k] == nil or (overwrite and core_env_additions[k])) and v ~= env and not k:match('^Add') and not kl:match('modname') then
			core_env_additions[k] = true
			return true
		end
	end, core, pairs(env))

	assert( modinfo, 'The mod environment has no modinfo!' )
	assert( MODROOT, 'The mod environment has no MODROOT!' )

	if overwrite or core.modenv == nil then
		core.modenv = env
	end

	if core.modname == nil then
		core.modname = env.modname
	end

	core.Modname = core.Modname or core.modinfo.name or _modname


	AssertEnvironmentValidity(_M)


	if not TheMod.modinfo then
		TheMod.Modname = Modname
		TheMod.version = modinfo.version
		TheMod.author = modinfo.author

		TheMod.modinfo = modinfo
	end

	TheMod:SlurpEnvironment(env, overwrite)


	AssertEnvironmentValidity(_M)


	-- Now the loading is explicit.
	--[[
	local Configurable = wickerrequire 'gadgets.configurable'
	TheMod:LoadConfiguration(modrequire('rc.defaults'), 'the default configuration file')
	TheMod:LoadConfiguration('rc.lua')
	]]--


	AssertEnvironmentValidity(_M)


	return TheMod
end


return function(...)
	return RobustlyCall(raw_init, ...)
end
