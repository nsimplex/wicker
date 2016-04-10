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
local _PACKAGE = _PACKAGE

local assert = assert
local error = assert( error )
local _K = assert( _K )
local _G = assert( _G )

assert( _K ~= _G )

assert(_NAME, "This file should be loaded by a require-like function.")
assert(_NAME == _K._NAME, 'This file should be loaded through krequire.')
assert(_PACKAGE, "Logic error.")

local krequire = assert(krequire)

local WICKER_ROOT = assert(WICKER_ROOT)
local wicker_stem = WICKER_ROOT

---

local NewFormattedTimeMeasurer = assert( NewFormattedTimeMeasurer )
local showbenchmark_with = assert( showbenchmark_with )

---

local coroutine = assert( coroutine )

---

return coroutine.create(function(boot_params)
    local print = assert( _K.print )

    local function get_boot_param(k)
        return boot_params[k]
    end
    _K.get_boot_param = get_boot_param

    local function require_boot_param(k)
        local v = get_boot_param(k)
        if v == nil then
            local msg = ("Required wicker kernel boot parameter '%s' not present.")
                :format(tostring(k))
            return error(msg)
        else
            return v
        end
    end
    _K.require_boot_param = require_boot_param

	local DEBUG = get_boot_param "debug"

	local announce = (function()
		local say = print
		local tostring = assert( tostring )
		local ipairs = assert( ipairs )
		local table = assert( table )

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

    local DONE_BOOTING = false

    ---

	announce("Received boot parameters, booting with root partition bound to '"
        , WICKER_ROOT
        , "'..."
        )

	-----------------------------------------------------------------

	local function NewModProber(root, desc, onload)
        local insmod = krequire.fork(root, desc)

		return function(name)
            local ret = insmod.package_loaded(name)
			if not ret then
                if onload then
                    onload(name)
                end

                local function announce_loaded(dt)
                    announce("Loaded ", desc, " '", name, "' (", dt, ").")
                end

                return showbenchmark_with(announce_loaded, insmod, name)
            end
            return ret
		end
	end
    _K.NewModProber = NewModProber


    local kernelboot_dt = NewFormattedTimeMeasurer()

    local modprobe_init = NewModProber(
        _PACKAGE..".init_modules."
        , "init module"
        , function(name)
            if DONE_BOOTING then
                local msg = ("Loading init module '%s' after booting.")
                    :format(tostring(name))
                return error(msg)
            end
        end
        )

    _K.modprobe_init = modprobe_init

    local modprobe = NewModProber("modules.", "kernel module")
    _K.modprobe = modprobe

	-----------------------------------------------------------------
	--[[
	-- We proceed to add kernel components, returning the kernel binder.
	--]]
	announce("Loading static kernel modules...")

	modprobe_init "cleanup"
	local PerformCleanup = assert( PerformCleanup )

	modprobe_init "invariants"
    -- ("invariants", boot_params, wicker_stem)

	-- modprobe_init("basic_utilities")
    modprobe_init "corelib"
    modprobe_init "metatablelib"
    modprobe_init "auxlib"

	modprobe_init("layering")
	assert( GetEnvironmentLayer )
	assert( GetOuterEnvironment )

    modprobe_init "package_management"
    modprobe_init "importers"

    --[[
	local InjectNonPrivatesIntoTable = InjectNonPrivatesIntoTable
    local basic_importer_metadata = modprobe_init("basic_importers")
    _K.basic_importer_metadata = basic_importer_metadata
	modprobe_init("advanced_importers")
    _K.basic_importer_metadata = nil
    ]]--

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
	
	modprobe_init("bindings", BindTheKernel)

	modprobe_init("extra_utilities")

	modprobe_init("loaders", boot_params, wicker_stem, module)

	modprobe_init("hooks")
	

	announce("Finished adding kernel components.")


	announce "Cleaning up."
	PerformCleanup()


	announce "Overriding package value."
	boot_params.package.loaded[_NAME] = BindTheKernel

	announce("Booted (", kernelboot_dt(), ").")
    DONE_BOOTING = true

	return BindTheKernel
end)
