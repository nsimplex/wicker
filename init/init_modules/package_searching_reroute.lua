--------------------------------------------------------------------------------
-- | 
-- Module      : wicker.init.init_modules.package_searching_reroute
-- Note        : 
-- 
-- 
-- 
--------------------------------------------------------------------------------

local assert = assert

local _K, _G = assert(_K), assert(_G)

local table = assert( table )
local tostring = assert( tostring )

---

modprobe_init "invariants"
modprobe_init "corelib"
modprobe_init "standard_requirers"

---

local const = assert( const )

local id1 = assert( id1 )

local userrequire = assert( userrequire )

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--  The main function: NewMappedSearcher
--------------------------------------------------------------------------------

-- | 
-- Returns a searcher (as in, an entry for package.searchers) which maps its
-- input through 'input_map', fetches it through 'target_importer' and returns
-- 'output_map' called over it, which should return a function (to be called
-- by _G.require).
--
local function NewMappedSearcher(target_importer, input_map, output_map)
    local package = target_importer.package

    return function(name)
        local mapped_name = name and input_map(name)
        if mapped_name then
            if package.loaded[mapped_name] then
                return function() return package.loaded[mapped_name] end
            end
            local M, err = target_importer.try_require(mapped_name)
            if M ~= nil then
                return output_map(M, mapped_name)
            else
                -- Then 'err' is an error message.
				assert(err ~= nil, "Logic error.")
                return tostring(err)
            end
        end
    end
end

--[[
local function NewPrefixFilter(prefix)
    return function(name)
        if name:find(prefix, 1, true) == 1 then
            return name
        end
    end
end

local function NewPrefixAdder(prefix)
    return function(name)
        return prefix..name
    end
end
]]--

local user_rerouter = NewMappedSearcher(
    userrequire,
    id1,
    const
)
table.insert(_G.package.loaders, user_rerouter)
