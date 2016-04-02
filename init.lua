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
local math = assert( _G.math )
local table = assert( _G.table )
local pairs = assert( _G.pairs )
local ipairs = assert( _G.ipairs )
local tostring = assert( _G.tostring )
local setfenv = assert( _G.setfenv )
local debug = assert( _G.debug )


local function super_basic_module(name)
	local t = {}

	t._M = t
	t._NAME = name
	t._PACKAGE = name:match("^(.-)[%a_][%w_]*$") or ""

	return t
end



setfenv(1, super_basic_module(...))


local FAILED_RUNNING = false

local function fail(message, level)
	level = level or 1
	if level > 0 then
		level = level + 1
	end
	FAILED_RUNNING = true
	return error(tostring(message), level)
end

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
			return fail("String expected as boot parameter 'modcode_root'.", 3)
		end

		if type(boot_params.id) ~= "string" then
			return fail("String expected as boot parameter 'id'", 3)
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

---

local function process_getinfo_args(thread, ...)
	if thread == nil then
		return ...
	else
		return thread, ...
	end
end

local function traceback(thread, message, start_level)
	if thread ~= nil and type(thread) ~= "thread" then
		thread, message, start_level = nil, thread, message
	end

	local is_same_thread = true
	if thread ~= nil then
		is_same_thread = (thread == coroutine.running())
	end

	if start_level == nil and type(message) == "number" then
		start_level, message = message, nil
	end

	if is_same_thread then
		start_level = start_level or 1
		start_level = start_level + 1
	else
		start_level = start_level or 0
	end

	local header = "stack traceback:"

	local pieces = {}
	if message ~= nil then
		message = tostring(message)
		local head, tail = message:match("^(.-)\a(.*)$")
		if head then
			table.insert(pieces, head)
			table.insert(pieces, tail.." "..header)
			header = nil
		else
			table.insert(pieces, message)
		end
	end
	if header then
		table.insert(pieces, header)
	end

	local getinfo = debug.getinfo

	for lvl = start_level, math.huge do
		local info = getinfo( process_getinfo_args(thread, lvl, "nSl") )
		if info == nil then break end

		local is_C = (info.what == "C")
		local is_tailcall = (info.source == "=(tail call)")

		local src

		local primary_location
		if is_C then
			primary_location = "[C]"
		elseif is_tailcall then
			primary_location = "(tail call)"
		else
			src = info.source
			if src then
				src = src:gsub("^@", "")
			else
				src = "???"
			end
			primary_location = src..":"..(info.currentline or "???")
		end

		local secondary_location
		if is_C or is_tailcall then
			secondary_location = "?"
		elseif info.what == "main" then
			secondary_location = "in main chunk"
		else
			local name = info.name
			if name then
				name = "function '"..name.."'"
			else
				name = "anonymous function"
			end
			local modifier = info.namewhat
			if modifier and #modifier > 0 then
				modifier = modifier.." "
			else
				modifier = ""
			end
			secondary_location = "in "..modifier..name
		end

		local subpieces = {
			"\t",
			primary_location,
			": ",
			secondary_location,
		}

		table.insert(pieces, table.concat(subpieces))
	end

	return table.concat(pieces, "\n")
end

---

local kernel, TheMod

local function ptraceback(message, lvl)
	return TheMod:Say(traceback(message, (lvl or 1) + 1))
end

local function bootstrap(env, boot_params)
	local package = boot_params.package

	local function basic_module(name)
		local t = super_basic_module(name)
		package.loaded[name] = t
		setfenv(2, t)
		return t
	end

	local kernel_bootstrapper = boot_params.import(_PACKAGE .. 'boot.kernel')(_G, basic_module)
	assert( type(kernel_bootstrapper) == "thread" )

	local function resume_kernel(...)
		local status, ret = coroutine.resume(kernel_bootstrapper, ...)
		if not status then
			local msg = tostring(ret).."\aWICKER KERNEL THREAD"
			return fail(traceback(kernel_bootstrapper, msg), 0)
		end
		return ret
	end

	kernel = resume_kernel(boot_params)
	kernel.traceback = traceback
	kernel.ptraceback = ptraceback

	local binder = resume_kernel(_PACKAGE)

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

local function extend_self()
	local kernel_extender = wickerrequire "kernel_extensions"
	kernel_extender(kernel)

	local api_extender = wickerrequire "api_extensions"
	api_extender()
end

local process_mod_environment = (function()
	local first_run = true

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

		assert( type(modinfo.id) == "string", "Mods without a modinfo.id cannot be used with wicker." )

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

		if first_run then
			extend_self()
			first_run = false
		end
	end
end)()


return function(env, raw_boot_params)
	if FAILED_RUNNING then return end

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
