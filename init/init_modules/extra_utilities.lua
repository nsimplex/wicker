--------------------------------------------------------------------------------
-- | 
-- Module      : wicker.init.init_modules.extra_utilities
-- Note        : 
-- 
-- Misc. utilities added last in the booting process.
-- 
--------------------------------------------------------------------------------

local assert = assert

local tostring = assert( tostring )

---

modprobe_init "layering"
modprobe_init "metatablelib"

---

local GetEnvironmentLayer = assert( GetEnvironmentLayer )
local GetOuterEnvironment = assert( _GetOuterEnvironment )
local AddLazyVariableTo = assert( AddLazyVariableTo )

---

--[[
-- Propagates the error point to the outer environment.
--]]
function OuterError(str, ...)
    local out_env, out_ind = GetEnvironmentLayer(1, true)

    return error(
        (str and tostring(str) or "ERROR"):format(...),
        out_ind
    )
end
local OuterError = OuterError

--[[
-- Propagates the assertion point to the outer environment.
--]]
function OuterAssert(cond, str, ...)
    if not cond then
        return OuterError(str or "assertion failed!", ...)
    end
end
local OuterAssert = OuterAssert

--[[
-- Adds a lazy variable to the current environment.
--]]
function AddLazyVariable(k, fn)
    return AddLazyVariableTo( GetOuterEnvironment(), k, fn )
end
local AddLazyVariable = AddLazyVariable
