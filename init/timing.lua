--------------------------------------------------------------------------------
-- | 
-- Module      : wicker.init.timing
-- Note        : 
-- 
-- Utilities for time lapses
-- 
--------------------------------------------------------------------------------

local assert = assert
local _K = assert( _K )
local _G = assert( _G )

local type = assert( _G.type )

--[[
-- If os.clock is available, under Linux this will measure the time the
-- actual process takes (even if the CPU is busy with other concurrent
-- processes). Under other OSes, this will measure the real elapsed time.
--]]
local os_clock = assert( _G.os.clock or _G.os.time )

local string_format = assert( _G.string.format )

local DEFAULT_TIME_FMT = "%.5f seconds"

local function NewTimeMeasurer()
	local t0

	local ret = function()
		return os_clock() - t0
	end

	t0 = os_clock()
	return ret
end
_K.NewTimeMeasurer = NewTimeMeasurer

local function apply_fmt(fmt, dt)
    if type(fmt) == "string" then
        return string_format(fmt, dt)
    else
        return fmt(dt)
    end
end

local function NewFormattedTimeMeasurer(fmt)
    fmt = fmt or DEFAULT_TIME_FMT

    local measure = NewTimeMeasurer()
    return function()
        local dt = measure()
        return apply_fmt(fmt, dt)
    end
end
_K.NewFormattedTimeMeasurer = NewFormattedTimeMeasurer


local timed_call = (function()
    local function handle_retvals(t0, ...)
        return os_clock() - t0, ...
    end
    
    return function(f, ...)
        local t0 = os_clock()
        return handle_retvals(t0, f(...))
    end
end)()
_K.timed_call = timed_call

local timed_call_format = (function()
    local function handle_retvals(fmt, dt, ...)
        return apply_fmt(fmt, dt), ...
    end

    return function(str_fmt, f, ...)
        fmt = fmt or DEFAULT_TIME_FMT
        return handle_retvals(fmt, timed_call(f, ...))
    end
end)()
_K.timed_call_format = timed_call_format

local showbenchmark_with = (function()
    local function handle_retvals(consumer, dt_str, ...)
        consumer( dt_str )
        return ...
    end

    return function(consumer, f, ...)
        return handle_retvals(consumer, timed_call_format(nil, f, ...))
    end
end)()
_K.showbenchmark_with = showbenchmark_with
