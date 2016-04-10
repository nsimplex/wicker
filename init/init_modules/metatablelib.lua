--------------------------------------------------------------------------------
-- | 
-- Module      : wicker.init.init_modules.metatablelib
-- Note        : 
-- 
-- Utilities for manipulating metatables and metamethods.
-- 
--------------------------------------------------------------------------------



local assert = assert
local _K = assert( _K )
local _G = assert( _G )

---

modprobe_init "corelib"

---

local metatable = _make_inner_kernel_env()
local _M = metatable
assert( _M ~= _K )

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

local tostring = get.tostring

local IsFunctional = get.IsFunctional

---

-- Returns an __index metamethod followed by a function which flushes the
-- copy (basically a particular version of Haskell's seq).
function LazyCopier(source, filter, is_late_filter)
    local cp_index, seq

    local iterate_filter = false

    local ty = type(filter)

    if filter == nil then
        cp_index = function(t, k)
            local v = source[k]
            if v ~= nil then
                rawset(t, k, v)
            end
            return v
        end
    elseif ty == "table" then
        if cardinalcmp(source, filter) > 0 then
            iterate_filter = true
        end

        cp_index = function(t, k)
            if filter[k] then
                local v = source[k]
                if v ~= nil then
                    rawset(t, k, v)
                end
                return v
            end
        end
    elseif ty == "function" then
        cp_index = function(t, k)
            if is_late_filter or filter(k) then
                local v = source[k]
                if v ~= nil and (not is_late_filter or filter(k, v)) then
                    rawset(t, k, v)
                    return v
                end
            end
        end
    else
        return error("Invalid filter given to LazyCopier.", 2)
    end

    if not iterate_filter then
        seq = function(t)
            for k, v in pairs(keys_set) do
                if rawget(t, k) == nil then
                    rawset(t, k, t[k])
                end
            end
        end
    else
        seq = function(t)
            for k, p in pairs(filter) do
                if p then
                    if t[k] == nil then
                        local v = source[k]
                        rawset(t, k, v)
                    end
                end
            end
        end
    end

    return cp_index, seq
end

-- Returns an objects metatable, creating a setting an empty one if it
-- doesn't exist.
local function require_metatable(object)
    local meta = getmetatable( object )
    if meta == nil then
        meta = {}
        setmetatable( object, meta )
    end
    return meta
end
_M.require_metatable = require_metatable

-- Normalizes a metamethod name, prepending a "__" if necessary.
local normalize_metamethod_name = (function()
    local cache = {}

    return function(name)
        local long_name = cache[name]
        if long_name == nil then
            assert(type(name) == "string")

            long_name = name

            local short_name = name:match("^__(.+)$")
            if not short_name then
                short_name = name
                long_name = "__"..name
            end

            cache[short_name] = long_name
            cache[long_name] = long_name
        end
        return long_name
    end
end)()

local function table_get(t, k)
    return t[k]
end

local function table_set(t, k, v)
    t[k] = v
end

local function table_call(t, ...)
    return t(...)
end

local function check_metamethod(x, name)
    local meta = getmetatable(x)
    return meta ~= nil and meta[name] ~= nil
end

--[[
-- Table of functions mapping metamethod names to function handling a
-- non-function metamethod.
--]]
local metamethod_get_handler = {
    __index = function(x)
        local ok = table_get
        if type(x) == "table" or check_metamethod(x, "__index") then
            return ok
        end
    end,
    __newindex = function(x)
        local ok = table_set
        if type(x) == "table" or check_metamethod(x, "__newindex") then
            return ok
        end
    end,
    __call = function(x)
        if check_metamethod(x, "__call") then
            return table_call
        end
    end,
}

local default_metamethods = {
    __index = rawget,
    __newindex = rawset,
}

--[[
-- Receives the name of a metamethod, which may include or not the "__"
-- prefix.
--
-- It returns a function that attaches a new metamethod of the given type
-- to a chain of such metamethods. This chain will keep calling
-- metamethods queued into it until a non-nil return value is obtained.
--]]
NewMetamethodManager = memoize_1ary(function(name)
    local metakey = normalize_metamethod_name(name)
    local metachainkey = uuid()
    local metastackkey = uuid()

    local get_handler = metamethod_get_handler[metakey]
    assert(get_handler == nil or type(get_handler) == "function")

    local function fromJust(meta, t)
        if meta == nil then
            meta = {}
            setmetatable(t, meta)
        end
        return meta
    end

    local mgr = {}

    local function clear(t)
        local meta = getmetatable(t)
        if meta ~= nil then
            local rawset = rawset

            rawset(meta, metachainkey, nil)
            rawset(meta, metakey, nil)
        end
        return meta
    end
    mgr.clear = clear

    local function fullclear(t)
        local meta = clear(t)
        if meta ~= nil then
            rawset(meta, metastackkey, nil)
        end
        return meta
    end

    local function truncate(t)
        return fromJust(clear(t), t)
    end

    local function overwrite(t, fn)
        local meta = truncate(t)
        return rawset(meta, metakey, fn)
    end
    mgr.set = overwrite

    function mgr.get(t)
        local meta = getmetatable(t)
        if meta ~= nil then
            return rawget(meta, metakey)
        end
    end
    local get = mgr.get

    function mgr.has(t)
        return get(t) ~= nil
    end

    local function push(t, fn)
        local meta = getmetatable(t)

        local oldmethod
        if meta ~= nil then
            oldmethod = rawget(meta, metakey)
        end

        if oldmethod ~= nil then
            local stack = rawget(meta, metastackkey)
            if stack == nil then
                stack = {}
                rawset(meta, metastackkey, stack)
            end

            local oldchain = rawget(meta, metachainkey)
            table.insert(stack, {oldmethod, oldchain})
        end

        meta = fromJust(meta, t)
        rawset(meta, metakey, fn)
    end
    mgr.push = push

    local function pop(t)
        local meta = getmetatable(t)

        if meta ~= nil then
            local stack = rawget(meta, metastackkey)
            if stack ~= nil then
                local old = table.remove(stack)
                if old ~= nil then
                    rawset(meta, metakey, old[1])
                    rawset(meta, metachainkey, old[2])
                end	
            end
        end
    end
    mgr.pop = pop

    local function accessor(t, ...)
        local chain = rawget(getmetatable(t), metachainkey)
        if not chain then return end

        for i = #chain, 1, -1 do
            local metamethod = chain[i]
            local meta_ty = type(metamethod)
            local v
            if meta_ty == "function" then
                v = metamethod(t, ...)
            else
                local handler = get_handler(metamethod)
                if handler then
                    v = handler(metamethod, ...)
                else
                    local msg = ("Invalid %s metamethod '%s'"):format(metakey, tostring(v))
                    return error(msg, 2)
                end
            end
            if v ~= nil then
                return v
            end
        end
    end

    -- If last, it is put in front, because we are using a stack.
    local function include(chain, newv, last)
        if last then
            table.insert(chain, 1, newv)
        else
            table.insert(chain, newv)
        end
        return chain
    end

    local function attach(t, fn, last)
        local meta = require_metatable(t)

        local chain = rawget(meta, metachainkey)
        if chain then
            include(chain, fn, last)
        else
            local oldfn = rawget(meta, metakey)
            if type(fn) == "table" and type(oldfn) == "table" then
                for k, v in pairs(fn) do
                    oldfn[k] = v
                end
            else
                if oldfn == nil then
                    oldfn = default_metamethods[metakey]
                end
                if oldfn ~= nil then
                    rawset(meta, metachainkey, include({oldfn, nil}, fn, last))
                    rawset(meta, metakey, accessor)
                else
                    rawset(meta, metakey, fn)
                end
            end
        end

        return t
    end
    mgr.attach = attach

    local function detach(t, fn)
        local meta = getmetatable(t)
        if not meta then return end

        local chain = rawget(meta, metachainkey)
        if chain then
            for i, v in ipairs(chain) do
                if v == fn then
                    table.remove(chain, i)
                    if #chain == 0 then
                        rawset(meta, metachainkey, nil)
                        rawset(meta, metakey, nil)
                    end
                    return fn
                end
            end
        end
    end
    mgr.detach = detach
    mgr.dettach = detach

    return mgr
end)

local parse_metamethod_args = (function()
    local valid_types = {
        name = {string = true},
        t = {table = true, userdata = true},
    }

    local function fn_test(fn, ty_fn)
        if fn == nil or ty_fn == "function" or ty_fn == "table" then
            return true
        else
            local meta = getmetatable(fn)
            return meta ~= nil and meta.__call ~= nil
        end
    end

    return function(name, t, fn)
        local ty_name, ty_t, ty_fn = type(name), type(t), type(fn)

        if not valid_types.name[ty_name] then
            name, t = t, name
            ty_name, ty_t = ty_t, ty_name
        end

        assert( valid_types.name[ty_name] )
        assert( valid_types.t[ty_t] )
        assert( fn_test(fn, ty_fn) )

        return name, t, fn
    end
end)()

local curried_managers = {}

for methodname in pairs(NewMetamethodManager "DUMMY") do
    local funcname = methodname.."metamethod"

    local curried = memoize_1ary(function(name)
        local op = NewMetamethodManager(name)[methodname]
        return function(t, fn, ...)
            local name2
            name2, t, fn = parse_metamethod_args(name, t, fn)
            assert( name == name2, "Logic error." )
            return op(t, fn, ...)
        end
    end)

    curried_managers[methodname] = curried
    _M[methodname.."metamethod"] = curried

    local function generic(x)
        local ty_x = type(x)
        if ty_x == "string" then
            return curried(x)
        else
            return function(name, ...)
                return curried(name)(...)
            end
        end
    end

    _M["metamethod"..methodname.."er"] = generic
end

_M.metamethodpopper = _M.metamethodpoper

local function capitalize(str)
    return str:sub(1, 1):upper()..str:sub(2):lower()
end

local sample_attachers = {
    __index = "Index",
    __newindex = "NewIndex",
    __call = "Call",
    __tostring = "ToString",
}

for name, label in pairs(sample_attachers) do
    for methodname, func in pairs(NewMetamethodManager(name)) do
        local basic_prefix = capitalize(methodname)
        
        local prefixes = {
            basic_prefix,
            basic_prefix.."Meta",
        }

        for _, prefix in ipairs(prefixes) do
            local basic_funcname = prefix..label

            local func = curried_managers[methodname](name)

            local funcnames = {
                basic_funcname,
                basic_funcname.."To",
            }

            for _, funcname in ipairs(funcnames) do
                _M[funcname] = func
                _M[funcname:lower()] = func
            end
        end
    end
end

---

local function access_error_msg(kind, self, k)
    return ("Attempt to %s '%s' in readonly table %s."):format(kind, tostring(self), tostring(k))
end

local function new_access_error(kind)
    return function(self, k)
        return error(access_error_msg(kind, self, k), 2)
    end
end

local write_new_error = new_access_error "create new entry"

local function freeze(t)
    AttachMetaNewIndexTo(t, write_new_error)
    return t
end
_M.freeze = freeze

local function thaw(t)
    DetachMetaNewIndexFrom(t, write_new_error)
    return t
end
_M.thaw = thaw

local newaccessor = (function()
    local function new_meta(get, set)
        return {
            __index = get or nil,
            __newindex = set or write_new_error,
        }
    end

    return function(get, set)
        return setmetatable({}, new_meta(get, set))
    end
end)()
_M.newaccessor = newaccessor

local props_getters_metakey = {}
local props_setters_metakey = {}

local function property_index(object, k)
    local props = rawget(getmetatable(object), props_getters_metakey)
    if props == nil then return end

    local fn = props[k]
    if fn ~= nil then
        return fn(object, k, props)
    end
end

local function property_newindex(object, k, v)
    local props = rawget(getmetatable(object), props_setters_metakey)
    if props == nil then return end

    local fn = props[k]
    if fn ~= nil then
        fn(object, k, v, props)
        return true
    end
end

function AddPropertyTo(object, k, getter, setter)
    local meta = require_metatable(object)
    if getter ~= nil then
        local getters = rawget(meta, props_getters_metakey)
        if not getters then
            getters = {}
            rawset(meta, props_getters_metakey, getters)
            AttachMetaIndexTo(object, property_index)
        end
        getters[k] = getter
    end
    if setter ~= nil then
        local setters = rawget(meta, props_setters_metakey)
        if not setters then
            setters = {}
            rawset(meta, props_setters_metakey, setters)
            AttachMetaNewIndexTo(object, property_newindex)
        end
        setters[k] = setter
    end
end
local AddPropertyTo = AddPropertyTo

function AddLazyVariableTo(object, k, fn)
    local function getter(object, k, props)
        local v = fn(k, object)
        if v ~= nil then
            props[k] = nil
            rawset(object, k, v)
        end
        return v
    end

    return AddPropertyTo(object, k, getter)
end
local AddLazyVariableTo = AddLazyVariableTo

---

cleanMerge(_K, _M)

---

_M.rawget = get.debug.getmetatable
_M.rawset = get.debug.setmetatable

_M.get = get.getmetatable
_M.set = get.setmetatable
_M.require = require_metatable

---

return _M()
