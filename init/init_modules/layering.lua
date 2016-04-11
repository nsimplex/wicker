--------------------------------------------------------------------------------
-- | 
-- Module      : wicker.init.static_modules.layering
-- Note        : 
-- 
-- Tools for manipulating the Lua call stack under the 'environment layer'
-- equivalence relation. Two functions in the call stack are 'environment
-- layer' equivalent iff they are adjacent and share an environment.
--
-- Functions without an environment or having the wicker kernel as their
-- environment (i.e., kernelspace functions) are treated specially. See
-- GetEnvironmentLayer for details.
-- 
--------------------------------------------------------------------------------


local assert = assert

local _K = assert( _K )

local _G = assert( _G )

local type = assert(type)
local pcall = assert(pcall)

-- This will be a customized getfenv.
local getfenv = assert(getfenv)


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--  The main function: GetEnvironmentLayer
--------------------------------------------------------------------------------

-- The code would be absolutely broken if this trivial claim were false.
assert( _K ~= _G )

-- | Utility from init.debug that iterates through the call stack skipping
-- tail calls and providing debug info.
local getenvlayer_infogetter = DebugInfoGetter "f"

-- |
-- We define an environment layer as the environment of a sequence of 1 or
-- more consecutive functions in the call stack with the same environment.
--
-- Functions without an environment (possible in Lua 5.2+) and functions with
-- the wicker kernel as their environment are ignored and skipped. As an
-- important corollary, wicker kernel functions never belong to an environment
-- layer (and using them as utilities doesn't split a layer). In particular,
-- this function only makes sense if the call stack crosses userspace.
--
-- This function takes a non-negative integer 'n' and returns the nth
-- environment layer from the callee. An 'n' of 0 returns the environment of
-- the callee (or, more precisely, the environment of the youngest ancestor of
-- this function having a non-nil environment which differs from the wicker
-- kernel environment).
--
-- If the parameter 'allow_global' evaluates to false, then crossing the
-- global environment raises an error.
function GetEnvironmentLayer(n, allow_global)
    assert(type(n) == "number" and n >= 0 and n % 1 == 0)

    -- Current Lua call stack index relative for the *current* function.
    -- This means (i - 1) is the stack index relative to the caller.
    local i = 0

    local last_env = nil

    -- Current Lua call stack index ignoring tail calls relative to the
    -- *current* function.  This means (pseudo_lvl - 1) is the stack index
    -- relative to the caller.
    local pseudo_lvl = 0

    for real_lvl, info in getenvlayer_infogetter(pseudo_lvl + 1) do
        pseudo_lvl = pseudo_lvl + 1

        local func = assert(info.func)
        local status, env = pcall(getfenv, func)
        if status and env ~= nil then
            if env ~= last_env and env ~= _K then
                if not allow_global and env == _G then
                    error('Attempt to reach the global environment! (real_lvl = '..tostring(real_lvl)..')')
                    return
                end

                n = n - 1
                last_env = env

                if n < 0 then
                    return env, pseudo_lvl - 1
                end
            end
        end
    end

    error(("No such environment layer: %d."):format(n))
end
local GetEnvironmentLayer = GetEnvironmentLayer

-- Old code.
--[=[
function GetNextEnvironmentThreshold(i, allow_global)
    assert( i == nil or (type(i) == "number" and i > 0 and i == math.floor(i)) )

    local i0 = i or 1
    i = i0 + 1

    local env

    local function get_first()
        local status

        status, env = pcall(getfenv, i + 2)
        if not status then
            return error('Unable to get the initial environment!')
        end

        return env
    end

    local function get_next()
        local status
        
        while not status do
            status, env = pcall(getfenv, i + 2)
            i = i + 1
        end
        i = i - 1

        return env
    end

    local first_env = get_first()
    if first_env == _G then
        return error('The initial environment is the global environment!')
    end

    assert( env == first_env )

    while env == first_env or env == _M do
        i = i + 1
        env = get_next()
    end

    if not allow_global and env == _G then
        return error('Attempt to reach the global environment! (i0 = '..i0..', i = '..i..')')
    --[[
    elseif env == _M then
        return error('Attempt to reach the kernel environment! (i0 = '..i0..', i = '..i..')')
    ]]--
    end

    -- This subtraction makes i relative to the parent function.
    return i - 1, env
end
--]=]

-- |
-- This is meant to be called in kernelspace only.
--
-- Under this condition, it returns the innermost outer userspace environment.
function _GetOuterEnvironment(allow_global)
    local env, i = GetEnvironmentLayer(0, allow_global)
    return env, i - 1
end
local _GetOuterEnvironment = _GetOuterEnvironment
