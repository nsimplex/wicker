--------------------------------------------------------------------------------
-- | 
-- Module      : wicker.dsmodules.constants
-- Note        : 
-- 
-- Imports essential constants from the game, with sane default replacement
-- values if absent (due to multiplatform support).
-- 
--------------------------------------------------------------------------------

local assert = assert
local _K = assert( _K )
local _G = assert( _G )

local _M = _M
assert( _K == _M )

---

modprobe_init "corelib"
dsmodprobe "platform_detection"

---

local get = NewVarFetcher()

local assert, error = get.assert, get.error
local VarExists = get.VarExists

local type = get.type
local rawget, rawset = get.rawget, get.rawset

local getmetatable, setmetatable = get.getmetatable, get.setmetatable
local table, math = get.table, get.math

local pairs, ipairs = get.pairs, get.ipairs
local next = get.next

local tostring = get.tostring

local unpack = get.unpack

---

local function addConstants(name, t)
    if t == nil then
        return bind(addConstants, name)
    end

    local t2 = ShallowCopy(t)

    local _N
    if name == nil then
        _N = _M
    else
        _N = _M[name]
        if not _N then
            _N = {}
            _M[name] = _N
        end
    end

    ShallowInject(_N, t)
end

local dflts = {}
local function addDefaultConstants(name, t)
    if t == nil then
        return bind(addDefaultConstants, name)
    end

    addConstants(name, t)

    local _N
    if name == nil then
        _N = dflts
    else
        _N = dflts[name]
        if not _N then
            _N = {}
            dflts[name] = _N
        end
    end

    ShallowInject(_N, t)
end

local validateConstants = (function()
    local function atomic_error(val)
        return {tostring(val)}
    end

    local function rec_find_error(dflt_subroot, check_subroot)
        local dflt_type = type(dflt_subroot)
        local check_type = type(check_subroot)

        if dflt_type ~= check_type then
            return atomic_error(check_subroot)
        end

        if dflt_type ~= "table" then
            if dflt_subroot ~= check_subroot then
                return atomic_error(check_subroot)
            end
        else
            for name, v in pairs(dflt_subroot) do
                local err = rec_find_error(v, check_subroot[name])
                if err then
                    local myerr = atomic_error(name)
                    myerr.next = err
                    return myerr
                end
            end
        end
    end

    return function()
        local err = rec_find_error(dflts, _M)
        if err then
            local push = table.insert
            
            local keys = {}
            local val = nil

            while err.next do
                push(keys, err[1])
                err = err.next
            end
            val = assert( err[1] )
            err = err.next
            assert( err == nil )

            local msg = ("Constant %s = %s violates default assumptions.")
                :format(table.concat(keys, "."), val)

            return error(msg, 0)
        end
    end
end)()

---


addConstants (nil) {
    DONT_STARVE_APPID = get.opt("DONT_STARVE_APPID", 219740),
    DONT_STARVE_TOGETHER_APPID = get.opt("DONT_STARVE_TOGETHER_APPID", 322330),
}

addDefaultConstants "SHARDID" {
    INVALID = "0", 
    MASTER = "1",
}

addDefaultConstants "REMOTESHARDSTATE" {
    OFFLINE = 0, 
    READY = 1, 
}

if IsDST() then
    _M.SHARDID = assert(_G.SHARDID)
    _M.REMOTESHARDSTATE = assert(_G.REMOTESHARDSTATE)
else
    addConstants "SHARDID" {
        CAVE_PREFIX = "2",
    }
end

---

validateConstants()
