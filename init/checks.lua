--------------------------------------------------------------------------------
-- | 
-- Module      : wicker.init.checks
-- Note        : 
-- 
-- Inspired by the interface of the module 'checks' from
-- https://github.com/SierraWireless/luasched
-- 
--------------------------------------------------------------------------------

local kdebug = krequire "init.debug"

---

local _G = _G
local assert = assert

local type = assert( _G.type )
local getmetatable = assert( _G.getmetatable )

local error = assert( kdebug.error )
assert(error == _K.error)

local raw_error = assert( kdebug.raw_error )

local raw_getinfo = assert( kdebug.raw_getinfo )
-- local getinfo = assert( kdebug.getinfo )
local raw_getlocal = assert( kdebug.raw_getlocal )
-- local getlocal = assert( kdebug.getlocal )

local getupvalue = assert( _G.debug.getupvalue )

---

local _K = _K

---

local checkers_providers = {}
local ncheckers_providers = 0

local function addCheckersProvider(fn)
    ncheckers_providers = ncheckers_providers + 1
    checkers_providers[ncheckers_providers] = fn
end
_K.AddCheckersProvider = addCheckersProvider

--- 

local function is_type(ty)
    return function(x)
        return type(x) == ty
    end
end

local function add_type_checkers(tbl)
    local function add_checker(ty)
        tbl[ty] = is_type(ty)
        return add_checker
    end
    return add_checker
end


-- Maps strings to predicates.
local checkers = {}

-- Maps non-string representation of types (such as metatables) to a string
-- id, obtained from upvalue introspection.
local checkernames = {}

add_type_checkers(checkers)
    "nil"
    "number"
    "string"
    "boolean"
    "table"
    "function"
    "thread"
    "userdata"

_K.checkers = checkers

---

local function get_func_info(info, target_lvl)
    return info or raw_getinfo(target_lvl + 1, "nfu") or {}
end

local function get_func_name(info)
    return info and info.name or "???"
end

local function get_func_func(info)
    return info and info.func or error("No function in checked stack level.")
end

-- What to add to a Lua call stack index after a tail call.
local TAIL_CALL_LVL_INC = (IS_LUA51 and 1 or 0)

local function expand_checks(info, idx, target_lvl, consumer, testname, ...)
    if testname == nil then return true end

    local testval = nil

    if type(testname) ~= "string" then
        testval = testname
        testname = checkernames[testval]
        if testname == nil then
            info = assert( get_func_info(info, target_lvl) )
            local func = assert(info.func)
            local nups = assert(info.nups)

            for i = 1, nups do
                local k, v = getupvalue(func, i)
                if v == testval then
                    testname = k
                    break
                end
            end

            if testname2 == nil then
                local err_msg = ("Function '%s' has no upvalue matching checker id '%s'.")
                    :format(get_func_name(info), tostring(testval))
                return raw_error(err_msg, target_lvl)
            end

            assert(type(testname) == "string")

            checkernames[testval] = testname
        end
    end

    local status
    status, info = consumer(info, idx, target_lvl + 1, testname, testval)
    if not status then
        return false, info
    end

    return expand_checks(info, idx + 1, target_lvl + TAIL_CALL_LVL_INC, consumer, ...)
end

local function metatable_tester(meta)
    return function(x)
        return getmetatable(x) == meta
    end
end

local function opt_wrap(fn)
    return function(x)
        return x == nil or fn(x)
    end
end

local function pretty_testname(testname)
    local isopt, strict_testname = testname:match("^%?(.*)$")
    if not isopt then
        return testname
    end

    return strict_testname.." or nil"
end

local function apply_single_check(info, idx, target_lvl, testname, testval)
    local checkfn = checkers[testname]

    if checkfn == nil then
        assert(type(testname) == "string")

        local isopt, strict_testname = testname:match("^%?(.*)$")
        local permissive_testname = testname
        local strict_checkfn = nil
        local permissive_checkfn = nil

        if isopt then
            strict_checkfn = checkers[strict_testname]
        else
            strict_testname = testname
            permissive_testname = "?"..testname
        end

        if strict_checkfn == nil then
            for i = 1, ncheckers_providers do
                local provfn = checkers_providers[i]
                strict_checkfn = provfn(strict_testname)
                if strict_checkfn then break end
            end

            if strict_checkfn == nil and testval == nil then
                info = assert( get_func_info(info, target_lvl) )
                local func = assert(info.func)
                local nups = assert(info.nups)

                for i = 1, nups do
                    local k, v = getupvalue(func, i)
                    if k == testname then
                        testval = v
                        break
                    end
                end
            end

            if strict_checkfn == nil and type(testval) == "table" then
                strict_checkfn = metatable_tester(testval)
            end

            if strict_checkfn == nil then
                info = get_func_info(info, target_lvl)
                return raw_error(("No test for type '%s' under function '%s'.")
                    :format(strict_testname, get_func_name(info)), 2)
            end

            checkers[strict_testname] = strict_checkfn
        end

        checkers[permissive_testname] = opt_wrap(strict_checkfn)

        checkfn = isopt and permissive_checkfn or strict_checkfn
    end

    local k, v = raw_getlocal(target_lvl, idx)

    if k == nil then
        info = get_func_info(info, target_lvl)
        return raw_error(("bad checks list for '%s': no local at #%d.")
            :format(get_func_name(info), idx), target_lvl)
    end

    if not checkfn(v) then
        info = get_func_info(info, target_lvl)

        local msg = ("bad argument #%d ('%s') to '%s' (%s expected, got %s)")
            :format(idx, k, get_func_name(info), pretty_testname(testname), type(v))

        return false, msg
    end

    return true, info
end

local function checks(...)
    local status, msg = expand_checks(nil, 1, 3, apply_single_check, ...)
    if not status then
        error(msg, 3)
    end
    return true
end
_K.checks = checks
