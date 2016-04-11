--------------------------------------------------------------------------------
-- | 
-- Module      : wicker.debug
-- Note        : This must be loaded in the kernel environment.
-- 
-- This module defines introspection utilities over the Lua stack, and
-- debugging utilities built on top of that.
-- 
--------------------------------------------------------------------------------

local assert = assert
local _G = assert( _G )
local type = assert( _G.type )

local debug = assert( _G.debug )
local coroutine = assert( _G.coroutine )
local tostring = assert( _G.tostring )

---

krequire "init.dataops"

---

local kdebug = {}
_K.kdebug = kdebug

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--  Misc. utilities for manipulating threads and stack levels
--------------------------------------------------------------------------------

local function if_not_thread_shift_right(thread, ...)
    if thread ~= nil and type(thread) ~= "thread" then
        return nil, thread, ...
    else
        return thread, ...
    end
end


local function if_not_thread_shift_left(thread, ...)
	if thread == nil then
		return ...
	else
		return thread, ...
	end
end
local process_getinfo_args = if_not_thread_shift_left

-- Bumps a given level to account for 'n' possible new function added to the
-- call stack, where 'n' is the 'same_thread_offset' parameter. This value,
-- which defaults to 1, will only be added of the given level refers to the
-- same thread we're currently in.
--
-- Requires thread to be explicitly nil if absent.
local function bump_level(thread, level, same_thread_offset)
    local is_same_thread =
        thread == nil or (thread == coroutine.running())

    if is_same_thread then
        level = level or 1
        level = level + (same_thread_offset or 1)
    else
        level = level or 0
    end

    return level
end


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--  Functions implementing Lua 5.2+ equivalent functionality in stack index
--  manipulation, skipping tails calls.
--------------------------------------------------------------------------------

local DebugInfoGetter = (function()
    local getinfo = assert(debug.getinfo)

    -- assert(_G._VERSION == "Lua 5.1")

    local new_info_fetcher
    if IS_LUA51 then
        local string_find = assert(_G.string.find)
        local string_gsub = assert(_G.string.gsub)

        new_info_fetcher = function(what)
            -- Only relevant for Lua 5.1.
            local wants_istailcall = IS_LUA51

            if what ~= nil then
                assert(type(what) == "string")
                -- FIXME
                what = "n"..what

                if not string_find(what, "S", 1, true) then
                    what = "S"..what
                end

                if IS_LUA51 then
                    local num_ts
                    what, num_ts = string_gsub(what, "t", "")
                    if not num_ts or num_ts == 0 then
                        wants_istailcall = false
                    end
                end
            end

            local function get_next(thread, offset, lvl)
                offset = offset + 1

                local info
                repeat
                    lvl = lvl + 1
                    info = getinfo( process_getinfo_args(thread, lvl + offset, what) )
                    if info == nil then
                        return
                    end
                until info.source ~="=(tail call)"
                return lvl, info
            end

            local function initialize(thread, offset, start_level)
                local real_offset = 0
                for i = 1, offset do
                    real_offset = get_next(thread, 1, real_offset)
                    if real_offset == nil then return end
                end

                local real_start_level = 0
                for i = 1, start_level do
                    real_start_level = get_next(thread, real_offset + 1, real_start_level)
                    if real_start_level == nil then return end
                end

                assert(real_offset >= offset)
                assert(real_start_level >= start_level)
            
                return real_offset, real_start_level - 1
            end

            -- The 'lvl' parameter is the last level.
            -- Therefore, on the initial call, it should be the start level minus
            -- one.
            return function(thread, offset, start_level, s, lvl)
                if lvl == nil then
                    s.offset, lvl = initialize(thread, offset, start_level)
                    if lvl == nil then return end
                end
                offset = s.offset

                local info
                lvl, info = get_next(thread, offset, lvl)
                if lvl == nil then return end

                if wants_istailcall and info.istailcall == nil then
                    local next_info = getinfo( process_getinfo_args(thread, lvl + 1 + offset, "S") )

                    info.istailcall =
                        next_info
                        and (next_info.source == "=(tail call)")
                        or false
                end

                return lvl, info
            end
        end
    else
        new_info_fetcher = function(what)
            return function(thread, offset, start_level, _, lvl)
                if lvl == nil then
                    lvl = start_level
                else
                    lvl = lvl + 1
                end
                local info = getinfo( process_getinfo_args(thread, lvl + offset, what) )
                if info == nil then
                    return
                end
                return lvl, info
            end
        end
    end

    local function close_info_fetcher(f, thread, offset, start_level)
        return function(s, lvl)
            return f(thread, offset, start_level, s, lvl)
        end, {}
    end

    local cache = {}
    local CATCHALL_KEY = uuid()

    return function(what)
        local whatkey
        if what == nil then
            whatkey = CATCHALL_KEY
        else
            whatkey = what
        end
        local ret = cache[whatkey]
        if ret == nil then
            local f = new_info_fetcher(what)

            ret = function(thread, start_level, same_thread_offset)
                thread, start_level, same_thread_offset =
                    if_not_thread_shift_right(thread, start_level, same_thread_offset)

                local offset = bump_level(thread, 0, (same_thread_offset or 0) + 1)
                start_level = start_level or 0

                return close_info_fetcher(f, thread, offset, start_level)
            end

            cache[whatkey] = ret
        end
        return ret
    end
end)()
kdebug.DebugInfoGetter = DebugInfoGetter

-- Iterator over stack indices discarding tail calls.
-- Essentially makes stack debug info conformant with Lua 5.2 or later.
local stack_indices = DebugInfoGetter "t"
kdebug.stack_indices = stack_indices

---

-- The global getinfo
local raw_getinfo = assert( _G.debug.getinfo )

-- | Function behaving like Lua 5.2+'s debug.getinfo (so it skips tail calls),
-- except it returns the real stack level before the debug info table, and it
-- also accepts a final optional parameter consisting of a stack level offset
-- to be applied if the given function is a stack index.
local get_fullinfo

-- | Function behaving like Lua 5.2+'s debug.getinfo (so it skips tail calls).
local getinfo

-- | Function normalizing a call stack in under the convention that tail calls
-- are skipped to the convention adopted by the current Lua version.
local normalize_stack_idx

-- The global debug.getlocal
local raw_getlocal = assert( _G.debug.getlocal )

-- The global debug.setlocal
local raw_setlocal = assert( _G.debug.setlocal )

-- debug.getlocal normalized
local getlocal = raw_getlocal

-- debug.setlocal normalized
local setlocal = raw_setlocal

if IS_LUA51 then
    local oldgetinfo = assert( raw_getinfo )

    get_fullinfo = function(thread, lvl, what, same_thread_offset)
        thread, lvl, what, same_thread_offset =
            if_not_thread_shift_right(thread, lvl, what, same_thread_offset)

        if lvl == nil or type(lvl) == "number" then
            local infogetter = DebugInfoGetter(what)

            same_thread_offset = same_thread_offset or 0

            local offset = bump_level(thread, 0, same_thread_offset + 1)

            for real_lvl, info in infogetter(thread, 0, offset) do
                if lvl <= 0 then
                    return real_lvl, info
                else
                    lvl = lvl - 1
                end
            end
        else
            return nil, oldgetinfo( if_not_thread_shift_left(thread, lvl, what) )
        end
    end

    getinfo = function(thread, lvl, what)
        thread, lvl, what =
            if_not_thread_shift_right(thread, lvl, what, same_thread_offset)
        local real_lvl, info = get_fullinfo(thread, lvl, what, 1)
        return info
    end

    -- Assumes an explicit nil thread if absent.
    local function normalize_thread_lvl_pair(thread, lvl, offset)
        offset = offset or 0
        offset = offset + 2

        local real_lvl = get_fullinfo(thread, lvl, "", offset)

        return thread, real_lvl -- bump_level(thread, real_lvl, -offset)
    end

    normalize_stack_idx = function(thread, lvl)
        thread, lvl =
            if_not_thread_shift_right(thread, lvl)

        thread, lvl = normalize_thread_lvl_pair(thread, lvl, 1)

        return lvl
    end

    -- | Wraps a function, such as debug.setlocal, and makes it index the call
    -- stack skipping tail calls.
    local function normalize_index_references(fn)
        assert(type(fn) == "function")
        return function(thread, lvl, ...)
            local extra
            thread, lvl, extra =
                if_not_thread_shift_right(thread, lvl)

            thread, lvl = normalize_thread_lvl_pair(thread, lvl, 0)
            lvl = bump_level(thread, lvl, 1)

            thread, lvl =
                if_not_thread_shift_left(thread, lvl, extra)

            return fn(thread, lvl, ...)
        end
    end

    getlocal = normalize_index_references(_G.debug.getlocal)

    setlocal = normalize_index_references(_G.debug.setlocal)
else
    local oldgetinfo = assert( debug.getinfo )

    get_fullinfo = function(thread, lvl, what, same_thread_offset)
        thread, lvl, what, same_thread_offset =
            if_not_thread_shift_right(thread, lvl, what, same_thread_offset)

        if lvl == nil or type(lvl) == "number" then
            lvl = bump_level(thread, lvl, (same_thread_offset or 0) + 1)

            local info = oldgetinfo(if_not_thread_shift_left(
                thread, lvl, what))

            return bump_level(thread, lvl, -1), info
        else
            return nil, oldgetinfo( if_not_thread_shift_left(thread, lvl, what) )
        end
    end

    getinfo = oldgetinfo

    normalize_stack_idx = function(thread, lvl)
        thread, lvl =
            if_not_thread_shift_right(thread, lvl)
        return lvl
    end
end

kdebug.get_fullinfo = get_fullinfo
kdebug.raw_getinfo = raw_getinfo
kdebug.getinfo = getinfo
kdebug.normalize_stack_idx = normalize_stack_idx

kdebug.raw_getlocal = raw_getlocal
kdebug.raw_setlocal = raw_setlocal
kdebug.getlocal = getlocal
kdebug.setlocal = setlocal

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--  getfenv and setfenv
--
--  These functions are implemented with Lua 5.2+ like stack index
--  conventions, as implemented above.
--------------------------------------------------------------------------------

if IS_LUA51 then
    local _G_getfenv = assert( _G.getfenv )
    local _G_setfenv = assert( _G.setfenv )

    function _K.getfenv(lvl)
        if lvl == nil then
            lvl = 1
        end
        if type(lvl) == "number" and lvl > 0 then
            lvl = lvl + 1

            -- Here we normalize the level to skip tail calls.
            lvl = get_fullinfo(nil, lvl, "")

            local ret = _G_getfenv(lvl)
            return ret
        else
            return _G_getfenv(lvl)
        end
    end

    function _K.setfenv(lvl, env)
        if type(lvl) == "number" then
            if lvl < 1 then
                return error("Setting a thread's environment has no direct counterpart in Lua 5.2+.", 2)
            end

            lvl = lvl + 1

            -- Here we normalize the level to skip tail calls.
            lvl = get_fullinfo(nil, lvl, "")

            local ret = _G_setfenv(lvl, env)
            return ret
        else
            return _G_setfenv(lvl, env)
        end
    end
else
    local raw_getfenv = assert( _K.raw_getfenv )
    local raw_setfenv = assert( _K.raw_setfenv )

    function _K.getfenv(lvl)
        if lvl == nil then
            lvl = 1
        end
        local ty_lvl = type(lvl)
        if ty_lvl ~= "number" and ty_lvl ~= "function" then
            return error("Number or function expected as argument to getfenv.")
        end
        if ty_lvl == "number" then
            if lvl < 1 then
                return _G
            end

            lvl = lvl + 1

            local info = getinfo(nil, lvl, "f")
            lvl = info and info.func
            if not lvl then
                return error("Unable to fetch function from stack index "..tostring(lvl + 1))
            end
        end
        assert(type(lvl) == "number")
        return raw_getfenv(lvl)
    end

    function _K.setfenv(lvl, env)
        local ty_lvl = type(lvl)
        if ty_lvl ~= "number" and ty_lvl ~= "function" then
            return error("Number or function expected as first argument to setfenv.")
        end
        if type(env) ~= "table" then
            return error("Table expected as second argument to setfenv.")
        end
        if ty_lvl == "number" then
            if lvl < 1 then
                return error("Setting a thread's environment has no direct counterpart in Lua 5.2+.", 1)
            end

            lvl = lvl + 1

            local info = getinfo(nil, lvl, "f")
            lvl = info and info.func
            if not lvl then
                return error("Unable to fetch function from stack index "..tostring(lvl + 1))
            end
        end
        assert(type(lvl) == "number")
        return raw_setfenv(lvl, env)
    end
end


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--  Debugging utilities
--------------------------------------------------------------------------------

local traceback_infogetter = DebugInfoGetter "nSlt"

local function traceback(thread, message, start_level)
    thread, message, start_level =
        if_not_thread_shift_right(thread, message, start_level)

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

    for lvl, info in traceback_infogetter(thread, lvl, 1) do
        assert( info.source ~= "=(tail call)" )

		local is_C = (info.what == "C")
        local istailcall = info.istailcall
        assert(istailcall ~= nil)

		local src

		local primary_location
		if is_C then
			primary_location = "[C]"
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
		if is_C then
			secondary_location = "?"
		elseif info.what == "main" then
			secondary_location = "in main chunk"
		else
			local name = info.name
            if name then
				name = "function '"..name.."'"
            elseif info.linedefined and info.short_src then
                local short_src = info.short_src:match("[^//\\]+$")
                    or info.short_src
                name = ("function <%s:%d>"):format(short_src, info.linedefined)
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

        if istailcall then
            table.insert(pieces, "\t(...tail calls...)")
        end
	end

	return table.concat(pieces, "\n")
end
kdebug.traceback = traceback


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--  Error
--------------------------------------------------------------------------------

local raw_error = assert( _G.error )
local k_error

if IS_LUA51 then
    local error = raw_error

    k_error = function(msg, lvl)
        lvl = lvl or 1
        if lvl ~= 0 then
            lvl = normalize_stack_idx(lvl)
        end
        return error(msg, lvl + 1)
    end
else
    k_error = raw_error
end
kdebug.raw_error = raw_error
kdebug.error = k_error


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--  Upvalue fetching
--------------------------------------------------------------------------------

local upvalues = (function()
    local getinfo = assert( getinfo )
	local getupvalue = assert( debug.getupvalue )

	local function f(fn, nups, var)
		var = var + 1
		if var > nups then
			return
		end
		return var, getupvalue(fn, var)
	end

    local function close_iter(fn, nups)
        return function(_, var)
            return f(fn, nups, var)
        end
    end

	return function(fn)
		local info = getinfo(fn, "u")
		local nups = info and info.nups or 0

		return close_iter(fn, nups), nil, 0
	end
end)()
kdebug.upvalues = upvalues

kdebug.Upvalues = upvalues
kdebug.UpValues = upvalue

---

local function find_upvalue_such_that(fn, p, ...)
    assert(type(fn) == "function", "Function expected as 'fn' parameter.")

    local info = getinfo(fn, "u")
    local nups = info and info.nups
    if not nups then return end

    local getupvalue = debug.getupvalue

	for i = 1, nups do
		local k, v = getupvalue(fn, i)
		if p(k, v, ...) then
			return v, k
		end
	end
end
kdebug.find_upvalue_such_that = find_upvalue_such_that

---

local function conditional_upvalue_finder(p, base_finder)
    base_finder = base_finder or find_upvalue_such_that
    return function(fn, ...)
        return find_upvalue_such_that(fn, p, ...)
    end
end

local function upvalue_requirer(base_finder)
    base_finder = base_finder or find_upvalue_such_that
    return function(fn, ...)
        local v, k = base_finder(fn, ...)
        if k == nil then
            local upvalue_id = tostring((...))
            return error("Unable to find upvalue '"..upvalue_id.."' through introspection.")
        end
        return v, k
    end
end

---

local function name_test(k, v, name)
    return k == name
end

local function value_test(k, v, val)
    return v == val
end

---

kdebug.FindUpvalueSuchThat = kdebug.find_upvalue_such_that
kdebug.FindUpValueSuchThat = kdebug.find_upvalue_such_that

---

kdebug.find_upvalue = conditional_upvalue_finder(name_test)
kdebug.find_upvalue_by_value = conditional_upvalue_finder(value_test)

kdebug.FindUpvalue = kdebug.find_upvalue
kdebug.FindUpValue = kdebug.find_upvalue

kdebug.FindUpvalueByValue = kdebug.find_upvalue_by_value
kdebug.FindUpValueByValue = kdebug.find_upvalue_by_value

---

kdebug.require_upvalue_such_that = upvalue_requirer()
kdebug.require_upvalue = upvalue_requirer(kdebug.find_upvalue)
kdebug.require_upvalue_by_value = upvalue_requirer(kdebug.find_upvalue_by_value)

kdebug.RequireUpvalueSuchThat = kdebug.require_upvalue_such_that
kdebug.RequireUpValueSuchThat = kdebug.require_upvalue_such_that

kdebug.RequireUpvalue = kdebug.require_upvalue
kdebug.RequireUpValue = kdebug.require_upvalue

kdebug.RequireUpvalueByValue = kdebug.require_upvalue_by_value
kdebug.RequireUpValueByValue = kdebug.require_upvalue_by_value

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--  Exporting
--------------------------------------------------------------------------------

cleanMerge(_K, kdebug)

---

return kdebug
