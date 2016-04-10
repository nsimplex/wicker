--------------------------------------------------------------------------------
-- | 
-- Module      : wicker.init.init_modules.corelib
-- Note        : 
-- 
-- Essential utilities
-- 
--------------------------------------------------------------------------------

local assert = assert
local _K = assert( _K )
local _G = assert( _G )

local _M = _M
assert( _K == _M )

---

local NewVarFetcher = (function()
    local rawget = assert( rawget )

    local function doget(k)
        local v = _K[k]
        if v == nil then
            return rawget(_G, k)
        else
            return v
        end
    end

    local function doget_opt(k, dflt_v)
        local v = doget(k)
        if v == nil then
            if dflt_v == nil then
                return error(("Required variable %s not set."):format(tostring(k)))
            end
            return dflt_v
        else
            return v
        end
    end

	local function doget_wrapper(self, k)
		local v = doget(k)
		if v == nil then
			return error(("Required variable %s not set."):format(k))
		end
		return v
	end

	local getter_meta = {
		__index = doget_wrapper,
		__call = doget_wrapper,
	}
	
    return function(kernel)
		local setmetatable = doget "setmetatable"

		local ret = {}
		ret[ret] = doget
		ret.opt = doget_opt

		return setmetatable(ret, getter_meta)
	end
end)()
_K.NewVarFetcher = NewVarFetcher

--- 

local get = NewVarFetcher(kernel)

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

local function const(x)
	return function()
		return x
	end
end
_K.const = const

local Nil = function() end
_K.Nil = Nil

local True, False = const(true), const(false)
_K.True, _K.False = True, False

local Zero, One = const(0), const(1)
_K.Zero, One = Zero, One

local function id(...)
    return ...
end
_K.id = id

local function id1(x)
    return x
end
_K.id1 = id1

local function bind(f, x)
	return function(...)
		return f(x, ...)
	end
end
_K.bind = bind

local function compose(f, g)
	return function(...)
		return f(g(...))
	end
end
_K.compose = compose

----------

-- "tee" here refers to the Unix utility tee.
-- We provide similar functionality where environment newindexing takes place
-- of text output.
local tee, clear_tee = (function()
	local env_data = {}

	local function get_env_data(env)
		local data = env_data[env]
		if data == nil then
			data = { get = NewVarFetcher(env) }
			env_data[env] = data
		end
		return data
	end

	local tee
	local get_tees, clear_tees
	local get_tree_newindex

	local function get_tees_meta(env)
		local data = get_env_data(env)
		local meta = data.teesmeta
		if meta == nil then
			meta = {
				__call = function()
					clear_tees(env)
				end
			}
			data.teesmeta = meta
		end
		return meta
	end

	get_tees = function(env)
		local data = get_env_data(env)
		local tees = data.tees
		if tees == nil then
			tees = setmetatable({}, get_tees_meta(env))
			data.tees = tees

			local env_meta = getmetatable(env)
			if env_meta == nil then
				env_meta = {}
				setmetatable(env, env_meta)
				data.had_meta = false
			else
				data.had_meta = true
				data.oldnewindex = env_meta.__newindex
			end

			env_meta.__newindex = get_tree_newindex(env)
		end
		return tees
	end

	clear_tees = function(env)
		local data = env_data[env]
		if data then
			env_data[env] = nil
			local tees = data.tees
			if tees then
				if not data.had_meta then
					setmetatable(env, nil)
				else
					getmetatable(env).__newindex = data.oldnewindex
				end
			end
		end
	end

	local function clear_tee(env, t)
		local data = get_env_data(env)
		local tees = get_tees(env)
		tees[t] = nil
		if data.get.next(tees) == nil then
			return clear_tees(env)
		end
	end

	get_tree_newindex = function(env)
		local data = get_env_data(env)
		local newindex = data.newindex
		if newindex == nil then
			local tees = get_tees(env)
			
			newindex = function(t, k, v)
				for tee in pairs(tees) do
					tee[k] = v
				end
				rawset(t, k, v)
			end

			data.newindex = newindex
		end
		return newindex
	end

	local function get_tee_meta(env)
		local data = get_env_data(env)
		local meta = data.teemeta
		if meta == nil then
			meta = {
				__call = function(self)
					clear_tee(env, self[self])
				end,
			}
			data.teemeta = meta
		end
		return meta
	end

	local function tee(env, t)
		t = t or {}

		local data = get_env_data(env)

		local ret = {}
		ret[ret] = t
		data.get.setmetatable(ret, get_tee_meta(env))

		local tees = get_tees(env)
		tees[t] = true

		return ret
	end

	return tee, clear_tee
end)()
-- _K.tee = tee
-- _K.clear_tee = clear_tee

local function _make_inner_kernel_env()
	local inner_env = {}
	inner_env._M = inner_env

	local inner_meta = {
		__index = _K,
	}
	setmetatable(inner_env, inner_meta)

	local proto = tee(inner_env, _K)
	inner_meta.__call = function(...) proto(...) return inner_env end

	setfenv(2, inner_env)

	return inner_env
end
_K._make_inner_kernel_env = _make_inner_kernel_env

---

local function IsCallable(x)
    if type(x) == "function" then
        return true
    end
    local mt = getmetatable(x)
    return mt and mt.__call
end
local IsFunctional = IsCallable
_M.IsCallable = IsCallable
_M.IsFunctional = IsFunctional

---

local function listify_higherorder(F)
    return function(f, ...)
        local function g(...)
            local frets = {f(...)}
            if frets[1] == nil then
                return nil
            else
                return frets
            end
        end

        local rets = F(g, ...)
        if rets ~= nil then
            return unpack(rets)
        end
    end
end

local MEMOIZE_NIL = uuid()

local memoize_cache_meta = {__mode = "k"}

local function make_cache()
    return setmetatable({}, memoize_cache_meta)
end

--[[
-- This is optimized compared to the (n >= 1)-ary versions in that if the
-- clear function is not stored, then the memoized function will have
-- their references freed once the computation is done, allowing for
-- memory reclaim by the GC.
--]]
local function memoize_0ary(f, dont_retry)
    local y = nil
    local f0 = f

    local function clear()
        local old = y
        y = nil
        f = f0
        return old
    end

    return function()
        if y == nil and f ~= nil then
            y = f()
            if y ~= nil or dont_retry then
                f = nil
            end
        end
        return y
    end, clear
end

--[[
-- This one is reimplemented in full for efficiency.
--]]
local function memoize_0ary_inplace(cachekey, f, dont_retry)
    local NIL = MEMOIZE_NIL

    local function clear(mastercache)
        local old = mastercache[cachekey]
        mastercache[cachekey] = nil
        return old
    end

    return function(mastercache)
        local y = mastercache[cachekey]
        if y == nil then
            y = f()
            if y == nil and dont_retry then
                mastercache[cachekey] = NIL
            end
        elseif y == NIL then
            y = nil
        end
        return y
    end, clear
end

local function lift_inplace_memoize(inplace_memoize)
    local function process_memoized(g, clear, ...)
        -- We do *not* use a weak table at the top level.
        -- Note we only use a single key into it (1).
        local mastercache = {}

        local function h(...)
            return g(mastercache, ...)
        end

        local function clear2(...)
            return clear(mastercache, ...)
        end

        return h, clear2, ...
    end

    return function(...)
        return process_memoized(inplace_memoize(1, ...))
    end
end

local function memoize_1ary_inplace(cachekey, f, dont_retry)
    local NIL = MEMOIZE_NIL

    local function clear(mastercache)
        local old = mastercache[cachekey]
        mastercache[cachekey] = nil
        return old
    end

    return function(mastercache, x)
        local cache = mastercache[cachekey]
        if cache == nil then
            cache = make_cache()
            mastercache[cachekey] = cache
        end

        if x == nil then
            x = NIL
        end
        local y = cache[x]
        if y == nil then
            y = f(x)
            if y ~= nil then
                cache[x] = y
            elseif dont_retry then
                cache[x] = NIL
            end
        elseif y == NIL then
            y = nil
        end
        return y
    end, clear
end
local memoize_1ary = lift_inplace_memoize(memoize_1ary_inplace)

local function raw_memoize_nary_inplace(cachekey, f, n, dont_retry)
    local NIL = MEMOIZE_NIL

    local function clear(mastercache)
        local old = mastercache[cachekey]
        mastercache[cachekey] = nil
        return old
    end
    
    return function(mastercache, ...)
        local args = {...}

        local NIL = NIL

        local last_subroot = mastercache
        local last_key = cachekey
        for i = 1, n do
            local xi = args[i]
            if xi == nil then
                xi = NIL
            end

            local subroot = last_subroot[last_key]
            if subroot == nil then
                subroot = make_cache()
                last_subroot[last_key] = subroot
            end

            last_subroot = subroot
            last_key = x1
        end

        local y = last_subroot[last_key]
        if y == nil then
            y = f(...)
            if y ~= nil then
                last_subroot[last_key] = y
            elseif dont_retry then
                last_subroot[last_key] = NIL
            end
        elseif y == NIL then
            y = nil
        end

        return y
    end, clear
end

local raw_memoize_nary = lift_inplace_memoize(raw_memoize_nary_inplace)

local memoize_inplace = function(cachekey, n)
    if n < 1 then
        return bind(memoize_0ary, cachekey)
    elseif n < 2 then
        return bind(memoize_1ary, cachekey)
    else
        return function(f, ...)
            return raw_memoize_nary(cachekey, f, n, ...)
        end
    end
end

local function memoize_nary_inplace(cachekey, f, n, ...)
    return memoize_inplace(cachekey, n)(f, ...)
end

local memoize = memoize_1ary(function(n)
    if n < 1 then
        return memoize_0ary
    elseif n < 2 then
        return memoize_1ary
    else
        return function(f, ...)
            return raw_memoize_nary(f, n, ...)
        end
    end
end)

local function memoize_nary(f, n, ...)
    return memoize(n)(f, ...)
end

_M.memoize_0ary_inplace = memoize_0ary_inplace
_M.memoize_1ary_inplace = memoize_1ary_inplace
_M.memoize_nary_inplace = memoize_nary_inplace
_M.memoize_inplace = memoize_inplace

_M.memoize_0ary = memoize_0ary
_M.memoize_1ary = memoize_1ary
_M.memoize_nary = memoize_nary
_M.memoize = memoize

---

_M.tee, _M.clear_tee = tee, clear_tee

---

local function ShallowInject(tgt, src)
    for k, v in pairs(src) do
        tgt[k] = v
    end
    return tgt
end
_M.ShallowInject = ShallowInject

local function ShallowCopy(t)
    return ShallowInject({}, t)
end
_M.ShallowCopy = ShallowCopy

local function DeepTreeInject(tgt, src)
    for k, v in pairs(src) do
        if type(v) == "table" then
            local tgt_k = tgt[k]
            if type(tgt_k) ~= "table" then
                tgt_k = {}
                tgt[k] = tgt_k
            end
            DeepTreeInject(tgt_k, v)
        else
            tgt[k] = v
        end
    end
end
_M.DeepTreeInject = DeepTreeInject
_M.DeepInject = DeepTreeInject

local function DeepTreeCopy(t)
    return DeepTreeInject({}, t)
end
_M.DeepTreeCopy = DeepTreeCopy
_M.DeepCopy = DeepCopy

local function DeepGraphInject_internal(tgt, src, refmap)
    for k, v in pairs(src) do
        if type(v) == "table" then
            local tgt_k = refmap[v]
            if tgt_k ~= nil then
                tgt[k] = tgt_k
            else
                tgt_k = tgt[k]
                if type(tgt_k) ~= "table" then
                    tgt_k = {}
                    tgt[k] = tgt_k
                end

                refmap[v] = tgt_k

                DeepGraphInject_internal(tgt_k, v, refmap)
            end
        end
    end
end

local function DeepGraphInject(tgt, src)
    return DeepGraphInject_internal(tgt, src, {[src] = tgt})
end
_M.DeepGraphInject = DeepGraphInject

local function DeepGraphCopy(t)
    return DeepGraphInject({}, t)
end
_M.DeepGraphCopy = DeepGraphCopy

-- Returns the size of a table including *all* entries.
local function cardinal(t)
    local sz = 0
    for _ in pairs(t) do
        sz = sz + 1
    end
    return sz
end
_M.cardinal = cardinal

local function cardinalset(n)
    if type(n) == "table" then
        n = cardinal(n)
    end
    local s = {}
    for i = 1, n do
        s[i] = true
    end
    return s
end
_M.cardinalset = cardinalset

-- Compares cardinal(t) and n.
--
-- Returns -1 if cardinal(t) < n
-- Returns 0 if cardinal(t) == n
-- Returns +1 if cardinal(t) > n
local function withnum_cardinalcmp(t, n)
    -- cardinal(t) - n
    local difference = -n
    for _ in pairs(t) do
        difference = difference + 1
        if difference > 0 then
            return 1
        end
    end
    if difference == 0 then
        return 0
    else
        return -1
    end
end

local function withtable_cardinalcmp(t, u)
    -- cardinal(t) - cardinal(n)
    local difference = 0

    local k_t, k_u = next(t), next(u)
    while k_t ~= nil and k_u ~= nil do
        k_t, k_u = next(t), next(u)
    end

    if k_t == nil then
        if k_u == nil then
            return 0
        else
            return -1
        end
    else
        return 1
    end
end

local function card_type_error(x)
    return "Value '"..tostring(x).."' has no cardinal.", 2
end

local function cardinalcmp(m, n)
    local ty_m, ty_n = type(m), type(n)

    if ty_m == "number" then
        if ty_n == "number" then
            return m - n
        else
            return -cardinalcmp(n, m)
        end
    else
        if ty_m ~= "table" then
            return error(card_type_error(m))
        end
        if ty_n == "number" then
            return withnum_cardinalcmp(m, n)
        else
            if ty_n ~= "table" then
                return error(card_type_error(n))
            end
            return withtable_cardinalcmp(m, n)
        end
    end
end
_M.cardinalcmp = cardinalcmp

local function value_dump(t)
    -- FIXME: make this not rely on Don't Starve
    require "dumper"

    local str = _G.DataDumper(t, nil, false)
    return ( str:gsub("^return%s*", "") )
end
_M.value_dump = value_dump
_M.table_dump = value_dump
