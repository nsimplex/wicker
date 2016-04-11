--------------------------------------------------------------------------------
-- | 
-- Module      : wicker.init.stdlib
-- Note        : 
-- 
-- This module imports, extends and, if necessary, patches the Lua standard
-- library in order to be a superset of the union of the Lua 5.1 and Lua 5.2
-- standard libraries
--
-- A notable exception is the unability to support __len metamethods for
-- tables under Lua 5.1.
-- 
--------------------------------------------------------------------------------

local assert = assert

local _K = assert( _K )
local _G = assert( _G )

local pairs = assert( _G.pairs )
local type = assert( _G.type )
local getmetatable = assert( _G.getmetatable )

---

krequire "init.dataops"

local kdebug = krequire "init.debug"
assert(type(kdebug) == "table")

krequire "init.checks"

---

local std = {}
_K.std = std

---

--[[
		function t.loadmodfile(fname)
			assert( type(fname) == "string", "Non-string given as file path." )
			return loadfile(MODROOT .. fname)
		end
		local loadmodfile = loadmodfile
		
		function t.domodfile(fname)
			return assert( loadmodfile(fname) )()
		end
		local domodfile = t.domodfile
]]--

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--  Importing the raw stdlib from _G
--------------------------------------------------------------------------------

filteredImporter(std, _G) {
    "assert",
    "dofile",
    "error",
    -- "getfenv" was already set up in the kernel
    "getmetatable",
    "ipairs",
    -- "load" was already set up in the kernel
    -- "loadfile" was already set up in the kernel
    -- "loadstring" gets set up later
    -- "module" doesn't get imported
    "next",
    "pairs",
    "pcall",
    "print",
    "rawequal",
    "rawget",
    "rawset",
    "require",
    "select",
    -- "setfenv" was already set up in the kernel
    "setmetatable",
    "tonumber",
    "tostring",
    "type",
    "xpcall",

    "coroutine",
    "debug",
    "io",
    "math",
    "package",
    "string",
    "table",

    os = {
        "clock",
        "date",
        "difftime",
        "time",
        ETC
    },

    _G = false,

    ETC
}


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--  Import overrides from the kernel
--------------------------------------------------------------------------------

std.getfenv = assert( _K.getfenv )
std.setfenv = assert( _K.setfenv )
std.loadfile = assert( _K.loadfile )

std.error = kdebug.error

std.debug = filteredImport(std.debug, kdebug, true)

std.debug.getfenv = assert( std.debug.getfenv or std.getfenv )
std.debug.setfenv = assert( std.debug.setfenv or std.setfenv )

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--  Extending stdlib's behavior
--------------------------------------------------------------------------------

std.table.unpack = assert(std.table.unpack or std.unpack)
std.unpack = std.table.unpack

local _G_next = assert( _G.next )
local _G_pairs = assert( _G.pairs )
local _G_ipairs = assert( _G.ipairs )

local function std_next(t, k)
    local mt = getmetatable(t)
    local mynext = mt and mt.__next
    if mynext then
        return mynext(t, k)
    else
        return _G_next(t, k)
    end
end
std.next = std_next

local function std_pairs(t)
    local mt = getmetatable(t)
    if mt then
        local mypairs = mt.__pairs
        if mypairs then
            return mypairs(t)
        end
        local mynext = mt.__next
        if mynext then
            return mynext, t, nil
        end
    end
    checks("table")
    return _G_pairs(t)
end
std.pairs = std_pairs

local std_ipairs
if IS_LUA51 then
    std_ipairs = function(t)
        local mt = getmetatable(t)
        local myipairs = mt and mt.__ipairs
        if myipairs then
            return myipairs(t)
        else
            return _G_ipairs(t)
        end
    end
else
    std_ipairs = _G_ipairs
end
std.ipairs = std_ipairs


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--  Exporting
--------------------------------------------------------------------------------

cleanMerge(_K, std)

dataops.makeExporter(std, _G)

-----

do return end
	
-- Works even if this is called on worldgen, etc.
local function import_game_essentials_into(t)
    --[[
    -- These are loaded right away into the environment.
    -- The main reasons for NOT including something here
    -- are if it doesn't exist during worldgen or if it
    -- exists only in DST or only outside of it.
    --]]
    local mandatory_imports = {
        "print",

        "Class",
        "Vector3",
        "Point",
        "TUNING",
        "STRINGS",
        "GROUND",
        
        "distsq",

        "Prefab",
    }
    --[[
    -- These are loaded on the fly, IF they exist.
    --]]

    local optional_imports = {
        "nolineprint",

        "TheSim",
        "WorldSim",
        "TheFrontEnd",
        "SaveIndex",
        "SaveGameIndex",
        "TheWorld",
        "TheNet",
        "TheShard",

        "LEVELTYPE",
        "KEYS",
        "LOCKS",

        "EntityScript",
        "CreateEntity",
        "SpawnPrefab",
        "DebugSpawn",
        "PrefabExists",

        "GetGroundTypeAtPosition",

        "ACTIONS",
        "Action",
        "BufferedAction",

        "Sleep",
        "Yield",
    }

    local import_filter = {}
    for _, k in ipairs(mandatory_imports) do
        import_filter[k] = true
    end
    for _, k in ipairs(optional_imports) do
        import_filter[k] = true
    end

    local raw_G = setmetatable({}, {
        __index = function(_, k)
            return rawget(_G, k)
        end,
    })

    AttachMetaIndex(t, LazyCopier(raw_G, import_filter))

    for _, k in ipairs(mandatory_imports) do
        assert( rawget(_G, k) ~= nil, ("The mandatory import %q doesn't exist!"):format(k) )
        assert( t[k] ~= nil )
    end

    if not VarExists("nolineprint") then
        function _M.nolineprint(...)
            return print(...)
        end
    end

    t.GLOBAL = _G
end
