--------------------------------------------------------------------------------
-- | 
-- Module      : wicker.init.importers
-- Note        : 
-- 
-- Definitions and metadata on module importing methods
-- 
--------------------------------------------------------------------------------

local assert = assert

local _K = assert( _K )
local _M = assert( _M )
assert( _K == _K )

---

local Requirer = assert( Requirer )

do return end

local basic_import = require_boot_param "import"
local modcode_root = require_boot_param "usercode_root"

local AssertEnvironmentValidity = assert( AssertEnvironmentValidity )

local GetNextEnvironmentThreshold = GetNextEnvironmentThreshold
local GetEnvironmentLayer = GetEnvironmentLayer
local GetOuterEnvironment = GetOuterEnvironment


local function prefixed_import(prefix, name)
    assert( type(prefix) == "string" )
    assert( type(name) == "string", "Package name is not a string." )
    local M = basic_import(prefix..name)
    --[[
    if type(M) == "table" then
        AssertEnvironmentValidity( M )
    end
    ]]--
    return M
end


local importer_metadata = {}



importer_metadata[require] = {name = 'require', category = 'Module'}

function wickerrequire(name)
    local M = prefixed_import(wicker_stem, name)
    --[[
    if type(M) == "table" then
        AssertEnvironmentValidity( M )
    end
    ]]--
    return M
end
local wickerrequire = wickerrequire
wickerequire = wickerrequire
importer_metadata[wickerrequire] = {name = 'wickerrequire', category = 'WickerModule'}

function modrequire(name)
    local M = prefixed_import(modcode_root, name)
    --[[
    if type(M) == "table" then
        AssertEnvironmentValidity( M )
    end
    ]]--
    return M
end
local modrequire = modrequire
importer_metadata[modrequire] = {name = 'modrequire', category = 'ModModule'}

function pkgrequire(name)
    local env = GetOuterEnvironment()
    assert( env )
    assert( type(env._PACKAGE) == "string" )

    local M = prefixed_import(env._PACKAGE, name)

    --[[
    if type(M) == "table" then
        AssertEnvironmentValidity( M )
    end
    ]]--

    return M
end
local pkgrequire = pkgrequire
importer_metadata[pkgrequire] = {name = 'pkgrequire', category = 'Package'}


importer_metadata[function(t) return t end] = {name = 'GetTable', category = 'Table'}

-- This should be hidden as soon as possible.
function TheKernel()
    return _M
end
local TheKernel = TheKernel
importer_metadata[TheKernel] = {name = 'TheKernel', category = 'TheKernel'}
AddVariableCleanup("TheKernel")

function GetTheMod()
    local M = wickerrequire 'api.themod'
    return M
end
local GetTheMod = GetTheMod
importer_metadata[GetTheMod] = {name = 'GetTheMod', category = 'TheMod'}


return importer_metadata
