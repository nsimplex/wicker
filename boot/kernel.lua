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


local _NAME = ...


--[[
-- Function which defines the body of the bootstrapping coroutine.
--
-- The counterpart to it is the boot.lua file, which manages its
-- stepwise execution.
--]]
local function kernel_boot_coroutine_body(_G, module)
	--[[
	-- Early booting process.
	--
	-- Here we just get the global environment, import some essentials
	-- from it and call the module() function.
	--]]
	local assert = _G.assert
	local error = assert( _G.error )
	local coroutine = _G.coroutine


	assert(_NAME, 'This file should be loaded through require or equivalent.')


	module(_NAME)


	local _M = _M
	local _PACKAGE = _PACKAGE
	_M._G = _G
	_M.module = module
	_M.assert = assert
	_M.error = error


	VarExists = (function()
		local rawget = assert( _G.rawget )
		local pcall = assert( _G.pcall )

		local function indextable(t, k)
			return t[k]
		end

		local function get_global(k)
			return rawget(_G, k)
		end

		return function(name, env)
			if env == nil or env == _G then
				return get_global(name) ~= nil
			end

			local status, val = pcall(indextable, env, name)

			return status and val ~= nil
		end
	end)()
	local VarExists = VarExists


	local DEBUG

	local Announce = (function()
		local say = assert( VarExists("nolineprint") and _G.nolineprint or _G.print )
		local tostring = assert( _G.tostring )
		local ipairs = assert( _G.ipairs )
		local table = assert( _G.table )

		return function(...)
			if DEBUG then
				local pieces = {"wicker kernel: "}
				for _, v in ipairs{...} do
					table.insert(pieces, tostring(v))
				end
				say( table.concat(pieces) )
			end
		end
	end)()



	-----------------------------------------------------------------
	--[[
	-- Yield.
	--
	-- We wait for the boot parameters, returning the kernel module.
	--]]
	local boot_params = assert( coroutine.yield() )

	DEBUG = boot_params.debug
	Announce "Received boot parameters, bootstrapping initiated."


	local AddKernelComponent = (function()
		local tostring = assert( _G.tostring )
		local import = assert( boot_params.import )
		local type = assert( _G.type )
		local setfenv = assert( _G.setfenv )
		local unpack = unpack

		local memory = {}

		return function(name, ...)
			if memory[name] ~= nil then
				return error("Re-adding kernel component "..tostring(name), 2)
			end

			Announce("Adding component '", name, "'.")

			local cmp = import(_PACKAGE.."kernel_components."..name)
			assert( type(cmp) == "function" )
			setfenv(cmp, _M)

			memory[name] = true
			return cmp(...)
		end
	end)()
	


	-----------------------------------------------------------------
	--[[
	-- Yield.
	--
	-- Wait for the wicker stem (initial part of wicker paths).
	-- We proceed to add kernel components, returning the kernel binder.
	--]]
	Announce "Waiting for wicker stem."
	local wicker_stem = assert( coroutine.yield(_M) )
	Announce('Got "', wicker_stem..'".')


	Announce("Adding kernel components.")


	AddKernelComponent("cleanup")
	local PerformCleanup = PerformCleanup

	AddKernelComponent("invariants", boot_params, wicker_stem)

	AddKernelComponent("basic_utilities")
	local VarExists = VarExists
	local IsWorldGen = IsWorldgen
	local LazyCopier = LazyCopier
	local AttachMetaIndex = AttachMetaIndex
	local InjectNonPrivatesIntoTableIf = InjectNonPrivatesIntoTableIf
	local InjectNonPrivatesIntoTable = InjectNonPrivatesIntoTable

	AddKernelComponent("import_essentials")
	local ImportEssentialsInto = _M.ImportEssentialsInto
	ImportEssentialsInto(_M)

	AddKernelComponent("layering")
	local GetNextEnvironmentThreshold = GetNextEnvironmentThreshold
	local GetEnvironmentLayer = GetEnvironmentLayer
	local GetOuterEnvironment = GetOuterEnvironment

	AddKernelComponent("advanced_importers", 
		AddKernelComponent("basic_importers", boot_params, wicker_stem))
	local BindTheKernel = BindTheKernel
	assert( BindTheKernel )
	InjectTheKernel = nil
	BecomeTheKernel = nil
	assert( BindTable )
	assert( InjectTable )
	assert( BecomeTable )
	assert( BindTheMod )
	InjectTheMod = nil
	assert( BecomeTheMod )
	
	AddKernelComponent("bindings", BindTheKernel)

	AddKernelComponent("extra_utilities")

	AddKernelComponent("loaders", boot_params, wicker_stem, module)

	AddKernelComponent("hooks")
	

	Announce "Finished adding kernel components."


	Announce "Cleaning up."
	PerformCleanup()


	Announce "Overriding package value."
	boot_params.package.loaded[_NAME] = BindTheKernel

	Announce "Booted."
	return BindTheKernel
end


return function(_G, module)
	local assert = _G.assert
	local coroutine = _G.coroutine

	local kernel_booter = assert( coroutine.create(kernel_boot_coroutine_body) )
	assert( coroutine.resume(kernel_booter, _G, module) )

	return kernel_booter
end
