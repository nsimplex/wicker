-----
--[[ Wicker ]] VERSION="3.0"
--
-- Last updated: 2013-11-29
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


-- Returns the global environment followed by assert.
local function get_essential_values()
	local function crash()
		({})[nil] = nil
	end

	local _G = _G or GLOBAL or crash()
	local assert = _G.assert or crash()

	return _G, assert
end


local _G, assert = get_essential_values()


local error = assert( _G.error )
local require = assert( _G.require )
local coroutine = assert( _G.coroutine )
local type = assert( _G.type )
local table = assert( _G.table )
local pairs = assert( _G.pairs )
local ipairs = assert( _G.ipairs )
local setfenv = assert( _G.setfenv )


local function super_basic_module(name)
	local t = {}

	t._M = t
	t._NAME = name
	t._PACKAGE = name:match("^(.-)[%a_][%w_]*$") or ""

	return t
end



setfenv(1, super_basic_module(...))



local preprocess_boot_params = (function()
	local default_boot_params = {
		debug = false,

		import = require,

		package = assert( _G.package ),

		modcode_root = nil,

		id = nil,

		overwrite_env = true,
	}

	return function(raw_boot_params)
		local boot_params = {}

		for k, v in pairs(default_boot_params) do
			boot_params[k] = v
		end
		for k, v in pairs(raw_boot_params) do
			boot_params[k] = v
		end

		if type(boot_params.modcode_root) ~= "string" then
			return error("String expected as boot parameter 'modcode_root'.", 3)
		end

		if type(boot_params.id) ~= "string" then
			return error("String expected as boot parameter 'id'", 3)
		end

		if not boot_params.modcode_root:match("[%./\\]$") then
			boot_params.modcode_root = boot_params.modcode_root.."."
		end

		if type(boot_params.import) == "table" and boot_params.import.package then
			boot_params.package = boot_params.import.package
		end

		return boot_params
	end
end)()


local kernel, TheMod
local function bootstrap(env, boot_params)
	local package = boot_params.package

	local function basic_module(name)
		local t = super_basic_module(name)
		package.loaded[name] = t
		setfenv(2, t)
		return t
	end

	local kernel_bootstrapper = boot_params.import(_PACKAGE .. 'init.kernel')(_G, basic_module)
	assert( type(kernel_bootstrapper) == "thread" )

	do
		local status
		status, kernel = coroutine.resume(kernel_bootstrapper, boot_params)
		assert( status, kernel )
	end

	local binder
	do
		local status
		status, binder = coroutine.resume(kernel_bootstrapper, _PACKAGE)
		assert( status, binder )
	end

	assert( coroutine.status(kernel_bootstrapper) == "dead" )


	binder(_M)


	kernel.TheKernel = nil
	TheKernel = nil


	local modrequire, wickerrequire = assert(modrequire), assert(wickerrequire)


	TheMod = (function()
		local mod_builder = GetTheMod()
		assert( type(mod_builder) == "function" )

		local TheMod = mod_builder(boot_params)

		function TheMod:modrequire(...)
			return modrequire(...)
		end

		function TheMod:wickerrequire(...)
			return wickerrequire(...)
		end

		local TheModConcept = GetTheMod()

		assert( TheMod ~= TheModConcept )
		assert( TheMod == TheModConcept.TheMod )

		kernel.TheMod = TheMod
		kernel.TheModConcept = TheModConcept

		kernel.RunModPostInits()

		return TheMod
	end)()
end


local process_mod_environment = (function()
	-- Additions to kernel from mod environments.
	local kernel_env_additions = {}

	return function(env, overwrite)
		kernel.InjectNonPrivatesIntoTableIf(function(k, v)
			local kl = k:lower()
			if (kernel[k] == nil or (overwrite and kernel_env_additions[k])) and v ~= env and not k:match('^Add') and not kl:match('modname') then
				kernel_env_additions[k] = true
				return true
			end
		end, kernel, pairs(env))

		assert( modinfo, 'The mod environment has no modinfo!' )
		assert( MODROOT, 'The mod environment has no MODROOT!' )

		if overwrite or kernel.modenv == nil then
			kernel.modenv = env
		end

		if kernel.modname == nil then
			kernel.modname = env.modname
		end

		kernel.Modname = kernel.Modname or kernel.modinfo.name or kernel.modname


		AssertEnvironmentValidity(_M)


		if not TheMod.modinfo then
			TheMod.Modname = Modname
			TheMod.version = modinfo.version
			TheMod.author = modinfo.author

			TheMod.modinfo = modinfo
		end

		TheMod:SlurpEnvironment(env, overwrite)
	end
end)()


return function(env, raw_boot_params)
	assert( type(raw_boot_params) == "table", "Boot parameters table expected." )

	if kernel == nil then
		bootstrap(env, preprocess_boot_params(raw_boot_params))
		assert( kernel )
		assert( TheMod )
	end

	AssertEnvironmentValidity(_M)

	local overwrite_env = raw_boot_params.overwrite_env
	if overwrite_env == nil then
		overwrite_env = true
	end
	
	process_mod_environment(env, raw_boot_params.overwrite_env)

	AssertEnvironmentValidity(_M)

	return TheMod
end
