--------------------------------------------------------------------------------
-- | 
-- Module      : wicker.dsmodules.platform_detection
-- Note        : 
-- 
-- Provides an API for detecting if we're in DS or DST as well as generally
-- querying static information from the game.
-- 
--------------------------------------------------------------------------------

local assert = assert
local _K = assert( _K )
local _G = assert( _G )

local _M = _M
assert( _K == _M )

---

modprobe_init "corelib"

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

local function lambdaif(p)
	return function(a, b)
		if p() then
			return a
		else
			return b
		end
	end
end
local function immutable_lambdaif(p)
	if p() then
		return function(a, b)
			return a
		end
	else
		return function(a, b)
			return b
		end
	end
end

---

local GetModDirectoryName = get.GetModDirectoryName

---

local PLATFORM_DETECTION = _make_inner_env()

---

IsDST = memoize_0ary(function()
    return _G.kleifileexists("scripts/networking.lua") and true or false
end)
local IsDST = IsDST
IsMultiplayer = IsDST

IfDST = immutable_lambdaif(IsDST)
IfMultiplayer = IfDST

function IsSingleplayer()
    return not IsDST()
end
local IsSingleplayer = IsSingleplayer

IfSingleplayer = immutable_lambdaif(IsSingleplayer)

---

IsDLCEnabled = get.opt("IsDLCEnabled", False)
IsDLCInstalled = get.opt("IsDLCInstalled", IsDLCEnabled)

REIGN_OF_GIANTS = get.opt("REIGN_OF_GIANTS", 1)
CAPY_DLC = get.opt("CAPY_DLC", 2)

---

IsRoG = memoize_0ary(function()
    if IsDST() then
        return true
    else
        return IsDLCEnabled(REIGN_OF_GIANTS) and true or false
    end
end)
IsROG = IsRoG

IsSW = memoize_0ary(function()
    return IsDLCEnabled(CAPY_DLC) and true or false
end)

IfRoG = immutable_lambdaif(IsRoG)
IfROG = IfRoG

IfSW = immutable_lambdaif(IsSW)
