--------------------------------------------------------------------------------
-- | 
-- Module      : wicker.dsmodules.introspection
-- Note        : 
-- 
-- Provides an API for introspecting upon the game state with an abstraction
-- layer for multiplatform support.
--
-- Essentially an advanced extension to the platform_detection dsmodule.
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
dsmodprobe "constants"

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


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--  Main detection functions
--------------------------------------------------------------------------------

IsWorldgen = memoize_0ary(function()
    return rawget(_G, "SEED") ~= nil
end)
local IsWorldgen = IsWorldgen
IsWorldGen = IsWorldgen
AtWorldgen = IsWorldgen
AtWorldGen = IsWorldgen

IfWorldgen = immutable_lambdaif(IsWorldgen)
IfWorldGen = IfWorldgen

---

GetWorkshopId = memoize_0ary(function()
    local dirname = GetModDirectoryName():lower()
    local strid = dirname:match("^workshop%s*%-%s*(%d+)$")
    if strid ~= nil then
        return tonumber(strid)
    end
end)
GetSteamWorkshopId = GetWorkshopId
local GetWorkshopId = GetWorkshopId

IsWorkshop = function()
    return GetWorkshopId() ~= nil
end
IsSteamWorkshop = IsWorkshop
local IsWorkshop = IsWorkshop


---

local GetSteamAppID
local has_TheSim = VarExists("TheSim")
if has_TheSim and _G.TheSim.GetSteamAppID then
    GetSteamAppID = function()
        return _G.TheSim:GetSteamAppID()
    end
else
    GetSteamAppID = function()
        if IsDST() then
            return DONT_STARVE_TOGETHER_APPID
        else
            return DONT_STARVE_APPID
        end
    end
    if has_TheSim then
        getmetatable(_G.TheSim).__index.GetSteamAppID = GetSteamAppID
    end
end
GetSteamAppId = GetSteamAppID

---

if IsDST() then
    GetPlayerId = function(player)
        return player.userid
    end
else
    GetPlayerId = One
end
GetPlayerID = GetPlayerId
GetUserId = GetPlayerId
GetUserID = GetPlayerID

---

local is_vacuously_host = memoize_0ary(function()
    return IsWorldgen() or not IsMultiplayer()
end)

IsHost = function()
    if is_vacuously_host() then
        return true
    else
        return _G.TheNet:GetIsServer() and true or false
    end
end
local IsHost = IsHost
IsServer = IsHost

IsMasterSimulation = function()
    if is_vacuously_host() then
        return true
    else
        return _G.TheNet:GetIsMasterSimulation() and true or false
    end
end
IsMasterSim = IsMasterSimulation

IfHost = immutable_lambdaif(IsHost)
IfServer = IfHost

IfMasterSimulation = immutable_lambdaif(IsMasterSimulation)
IfMasterSim = IfMasterSimulation

IsClient = function()
    if is_vacuously_host() then
        return false
    else
        return _G.TheNet:GetIsClient() and true or false
    end
end

IfClient = immutable_lambdaif(IsClient)

IsDedicated = (function()
    if IsWorldgen() then
        return true
    elseif IsSingleplayer() then
        return false
    else
        return _G.TheNet:IsDedicated() and true or false
    end
end)
local IsDedicated = IsDedicated
IsDedicatedHost = IsDedicated
IsDedicatedServer = IsDedicated

IfDedicated = immutable_lambdaif(IsDedicated)

---

local function can_be_shard()
    return IsDST() and IsServer() and not IsWorldgen() and VarExists("TheShard")
end

IsMasterShard = memoize_0ary(function()
    return can_be_shard() and _G.TheShard:IsMaster()
end)

IsSlaveShard = memoize_0ary(function()
    return can_be_shard() and _G.TheShard:IsSlave()
end)

IsShardedServer = memoize_0ary(function()
    return IsMasterShard() or IsSlaveShard()
end)
IsShard = IsShardedServer

IfMasterShard = immutable_lambdaif(IsMasterShard)

IfSlaveShard = immutable_lambdaif(IsSlaveShard)

IfShardedServer = immutable_lambdaif(IsShardedServer)
IfShard = IfShardedServer

---

local function GetSaveIndex()
    return rawget(_G, "SaveGameIndex")
end
_M.GetSaveIndex = GetSaveIndex

local function current_wrap(fn)
    return function(...)
        return fn(nil, ...)
    end
end

local function GetCurrentSaveSlot()
    local slot = nil

    local sg = GetSaveIndex()
    if sg then
        slot = sg:GetCurrentSaveSlot()
    end

    return slot or 1
end
_M.GetCurrentSaveSlot = GetCurrentSaveSlot

local GetSlotMode
if IsDST() then
    GetSlotMode = const "survival"
else
    GetSlotMode = function(slot)
        slot = slot or GetCurrentSaveSlot()
        local sg = GetSaveIndex()
        if sg then
            return sg:GetCurrentMode(slot)
        end
    end
end
_M.GetSlotMode = GetSlotMode

local GetCurrentMode = current_wrap(GetSlotMode)
_M.GetCurrentMode = GetCurrentMode

local function GetSlotData(slot)
    slot = slot or GetCurrentSaveSlot()
    local sg = GetSaveIndex()
    if sg and sg.data and sg.data.slots then
        return sg.data.slots[slot]
    end
end
_M.GetSlotData = GetSlotData

local GetCurrentSlotData = current_wrap(GetSlotData)
_M.GetCurrentSlotData = GetCurrentSlotData

-- In DS, returns current mode data.
local GetSlotWorldData
if IsDST() then
    GetSlotWorldData = function(slot)
        local slot_data = GetSlotData(slot)
        if slot_data then
            return slot_data.world
        end
    end
else
    GetSlotWorldData = function(slot)
        slot = slot or GetCurrentSaveSlot()
        local sg = GetSaveIndex()
        if sg then
            return sg:GetModeData(slot, GetSlotMode(slot))
        end
    end
end

local GetSlotCaveNum
if IsDST() then
    GetSlotCaveNum = One
else
    GetSlotCaveNum = function(slot)
        local sg = GetSaveIndex()
        if sg then
            return sg:GetCurrentCaveNum(slot)
        end
    end
end

local GetCurrentCaveNum = current_wrap(GetSlotCaveNum)
_M.GetCurrentCaveNum = GetCurrentCaveNum

local GetSlotCaveLevel
if IsDST() then
    GetSlotCaveLevel = Nil
else
    GetSlotCaveLevel = function(slot, cavenum)
        local sg = GetSaveIndex()
        if sg and GetSlotMode(slot) == "cave" then
            slot = slot or GetCurrentSaveSlot()
            cavenum = cavenum or GetSlotCaveNum(slot)
            return sg:GetCurrentCaveLevel(slot, cavenum)
        end
    end
end

---

IsSWLevel = memoize_0ary(function()
    local sg = GetSaveIndex()
    if sg then
        return sg:IsModeShipwrecked()
    end
end)

IfSWLevel = lambdaif(IsSWLevel)

---

local doGetShardId = memoize_0ary(function()
    if can_be_shard() then
        local id = _G.TheShard:GetShardId()
        assert( type(id) == "string" )
        return id
    else
        if IsWorldgen() or not IsServer() then
            return SHARDID.INVALID
        end

        if IsDST() or not GetSaveIndex() then
            return nil
        end

        local cavenum = GetCurrentCaveNum()
        local cavelevel = GetCurrentCaveLevel()

        if cavenum and cavelevel then
            local prefix = assert( SHARDID.CAVE_PREFIX )
            return ("%s.%d.%d"):format(prefix, cavenum, cavelevel)
        else
            return SHARDID.MASTER
        end
    end
end)

local function GetShardId()
    local id = doGetShardId()
    if id == nil then
        assert(SHARDID.INVALID)
        id = SHARDID.INVALID
    end
    return id
end
_M.GetShardId = GetShardId
_M.GetShardID = GetShardId


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--  Misc
--------------------------------------------------------------------------------

GetTick = get.opt("GetTick", Zero)
GetTime = get.opt("GetTime", get.os.clock or Zero)
GetTimeReal = get.opt("GetTimeReal", GetTime)
FRAMES = get.opt("FRAMES", 1/60)

if VarExists "TheSim" then
    GetTickTime = memoize_0ary(function()
        return _G.TheSim:GetTickTime()
    end)
else
    GetTickTime = function()
        return 1/30
    end
end
local GetTickTime = GetTickTime

GetTicksPerSecond = memoize_0ary(function()
    return 1/GetTickTime()
end)
local GetTicksPerSecond = GetTicksPerSecond

GetTicksForInterval = (function()
    local floor = math.floor
    return function(dt)
        return floor(dt*GetTicksPerSecond())
    end
end)()
GetTicksInInterval = GetTicksForInterval

GetTicksCoveringInterval = (function()
    local ceil = math.ceil
    return function(dt)
        return ceil(dt*GetTicksPerSecond())
    end
end)()
