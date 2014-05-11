--[[
-- By importing this file, +-infinity and Nan are properly stored in savedata.
--]]


--[[
-- Name of the global function which, when run inside DataDumper, triggers its patching.
--]]
local dumpertrigger_name = "ipairs"


------------------------------------------------------------------------


local _G = GLOBAL
local require, error, assert = _G.require, _G.error, _G.assert
local tostring = _G.tostring
local type = _G.type
local pcall = _G.pcall
local debug = _G.debug
local getmetatable, setmetatable = _G.getmetatable, _G.setmetatable
local getfenv, setfenv = _G.getfenv, _G.setfenv

--local os = _G.os

local math = _G.math
local plus_inf = math.huge
local minus_inf = -math.huge


------------------------------------------------------------------------


require "dumper"

local original_DataDumper = assert( _G.DataDumper )


------------------------------------------------------------------------


-- New function used to turn a number into a string.
local function dump_number(x)
	if x == plus_inf then
		return "1/0"
	elseif x == minus_inf then
		return "-1/0"
	elseif x ~= x then
		return "0/0"
	else
		return x--tostring(x)
	end
end

-- This should be called from within DataDumper.
local function patch_DataDumper()
	--print(os.time().." patch_DataDumper")

	-- Stack level of the DataDumper function.
	local level
	for i = 3, 16 do
		local status, info = pcall(debug.getinfo, i + 1, 'f')
		if status and info.func == original_DataDumper then
			level = i
			break
		end
	end
	if not level then return false end

	for local_idx = 1, plus_inf do
		local varname, fcts = debug.getlocal(level, local_idx)
		if varname == nil then break end

		if varname == "fcts" and type(fcts) == "table" then
			--print(os.time().." patched")
			fcts.number = dump_number
			return true
		end
	end

	return false
end


------------------------------------------------------------------------


local function NewDataDumperEnvironment(parent_env)
	local dumpertrigger
	dumpertrigger = (function()
		local old_dumpertrigger = assert( parent_env[dumpertrigger_name], "Trigger function '"..tostring(dumpertrigger_name).."' not found." )

		return function(...)
			--print(os.time().." dumpertrigger")

			if patch_DataDumper() then
				dumpertrigger = old_dumpertrigger
			end
			return old_dumpertrigger(...)
		end
	end)()

	local proxy_env_meta = {
		__index = parent_env,
		__newindex = parent_env,
	}

	return setmetatable({
		[dumpertrigger_name] = function(...)
			return dumpertrigger(...)
		end,
	}, proxy_env_meta)
end


------------------------------------------------------------------------


function _G.DataDumper(...)
	--print(os.time().." Running patched DataDumper")
	local oldenv = getfenv(1)
	setfenv(original_DataDumper, NewDataDumperEnvironment(oldenv))
	local ret = original_DataDumper(...)
	setfenv(original_DataDumper, oldenv)
	--print(os.time().." ran")
	return ret
end
setfenv(_G.DataDumper, getfenv(original_DataDumper))
