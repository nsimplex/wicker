--------------------------------------------------------------------------------
-- | 
-- Module      : wicker.init.dataops
-- Note        : 
-- 
-- Provides functions for copying data from tables.
-- 
--------------------------------------------------------------------------------

local assert = assert
local _G = assert( _G )

local _K = assert( _K )

local type = assert( _G.type )
local tostring = assert( _G.tostring )
local getmetatable = assert( _G.getmetatable )

---

local dataops = {}
_K.dataops = dataops

local ETC = uuid()
dataops.ETC = ETC

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--  The core function: filteredImport
--------------------------------------------------------------------------------

local reserved_metatables = {}

local function register_atomic_metatable(mt)
    reserved_metatables[mt] = true
end

register_atomic_metatable(_K.UUID_META)

-- Copies src, seen as a graph, into tgt, filtered by a given spec.
local internal_filteredImport
do
    local function importEntry(refmap, tgt, entry_filter_spec, k, v)
        assert(v ~= nil)

        local ty_v = type(v)
        local is_atomic = (ty_v ~= "table")

        if not is_atomic then
            local mt = getmetatable(v)
            if mt and reserved_metatables[mt] then
                is_atomic = true
            end
        end

        if not is_atomic then
            local sub_tgt = refmap[v]
            if sub_tgt == nil then
                sub_tgt = tgt[k]
                if type(sub_tgt) ~= "table" then
                    sub_tgt = {}
                end
                internal_filteredImport(refmap, sub_tgt, v, entry_filter_spec)
                refmap[v] = sub_tgt
            end
            tgt[k] = sub_tgt
            return
        else
            if type(entry_filter_spec) == "function" then
                entry_filter_spec = entry_filter_spec(tgt, k, v)
            end
            if entry_filter_spec then
                tgt[k] = v
            end
        end
    end

    internal_filteredImport = function(refmap, tgt, src, filter_spec)
        refmap[src] = tgt

        if src == tgt then return end

        local pairs = _K.pairs or _G.pairs

        local visited = {}

        local ty_filter_spec = type(filter_spec)

        local get_rest = ty_filter_spec ~= "table" and filter_spec ~= false

        if ty_filter_spec == "table" then
            for k, spec_v in pairs(filter_spec) do
                local k2 = k
                if type(k2) == "number" then
                    k2 = spec_v
                    spec_v = true
                    assert(k2 == ETC or type(k2) == "string")
                else
                    assert(k2 ~= ETC and type(k2) == "string")
                end
                if k2 == ETC then
                    get_rest = true
                else
                    visited[k2] = true
                    if spec_v then
                        importEntry(refmap, tgt, spec_v, k2, src[k2])
                    end
                end
            end
        end

        if get_rest then
            if filter_spec == nil or ty_filter_spec == "table" then
                filter_spec = true
            end
            for k, v in pairs(src) do
                if not visited[k] then
                    importEntry(refmap, tgt, filter_spec, k, v)
                end
            end
        end

        return tgt
    end
end

local function filteredImport(tgt, src, filter_spec)
    return internal_filteredImport({}, tgt, src, filter_spec)
end
dataops.filteredImport = filteredImport

local function filteredImporter(tgt, src)
    return function(...)
        return filteredImport(tgt, src, ...)
    end
end
dataops.filteredImporter = filteredImporter

local function filterImporter(filter_spec)
    return function(tgt, src)
        return filteredImport(tgt, src, filter_spec)
    end
end
dataops.filterImporter = filterImporter

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--  Derivative utilities
--------------------------------------------------------------------------------

local forcedMerge_filter = true

local function weakMerge_filter(t, k, v)
    return t[k] == nil
end

local function cleanMerge_filter(t, k, v)
    local oldv = t[k]
    if oldv ~= nil and oldv ~= v then
        return error("Merge is not clean on key '"..tostring(k).."'.")
    else
        return true
    end
end

---

local forcedMerge = filterImporter(forcedMerge_filter)
local weakMerge = filterImporter(weakMerge_filter)
local cleanMerge = filterImporter(cleanMerge_filter)

---

dataops.forcedMerge = forcedMerge
dataops.strongMerge = forcedMerge

dataops.weakMerge = weakMerge

dataops.cleanMerge = cleanMerge

---

cleanMerge(_K, dataops)

---

dataops.register_atomic_metatable = register_atomic_metatable

---

function dataops.makeExporter(env, default_tgt_env)
    default_tgt_env = default_tgt_env or _G
    env.export = function(tgt_env)
        tgt_env = tgt_env or default_tgt_env
        assert(type(tgt_env) == "table")
        return filteredImport(tgt_env, env, {
            export = false,
            ETC
        })
    end
end

---

return dataops
