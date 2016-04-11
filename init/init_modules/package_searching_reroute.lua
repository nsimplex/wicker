local assert = assert
local ipairs = ipairs
local table = table
local type = type
local getfenv = getfenv
local setfenv = setfenv


local GetWickerBooter = assert( GetWickerBooter )
local GetModBooter = assert( GetModBooter )


local modcode_root = boot_params.modcode_root
local import = assert( boot_params.import )
local package = assert( boot_params.package )
assert( type(package) == "table" )
local searchers = assert( package.searchers or package.loaders )
assert( type(searchers) == "table" )
assert( type(package.loaded) == "table" )


local is_object_import = type(import) == "table" and import.package == package


local alias_searchers = (function()
    if not is_object_import then
        return function()
            local ret = {}
            for _, fn in ipairs(searchers) do
                table.insert(ret, fn)
            end
            return ret
        end
    else
        return function()
            local ret = {}
            for _, fn in ipairs(searchers) do
                table.insert(ret, function(name)
                    return fn(import, name)
                end)
            end
            return ret
        end
    end
end)()


local function NewMappedSearcher(input_map, output_map)
    local current_searchers = alias_searchers()

    return function(...)
        local Args = {...}
        local name = table.remove(Args)
        local mapped_name = input_map(name)
        if mapped_name then
            if package.loaded[mapped_name] then
                return function() return package.loaded[mapped_name] end
            end
            for _, searcher in ipairs(current_searchers) do
                local fn = searcher(mapped_name)
                if type(fn) == "function" then
                    return output_map(fn, mapped_name)
                end
            end
            return "\tno file '" .. mapped_name .. "'"
        end
    end
end

local function NewBootBinder(get_booter)
    local function self_postinit_error()
        return error("AddSelfPostInit may only be called while the file is being loaded!", 2)
    end

    return function(fn)
        return function(name, ...)
            local self_postinits = {}

            local function add_self_postinit(post_fn)
                table.insert(self_postinits, post_fn)
            end

            local _M = module(name)

            get_booter()(_M)
            setfenv(fn, _M)

            _M.AddSelfPostInit = add_self_postinit

            local ret = fn(name, ...)
            if ret == nil then
                ret = _M
            end
            package.loaded[name] = ret

            for _, post_fn in ipairs(self_postinits) do
                post_fn()
            end

            _M.AddSelfPostInit = self_postinit_error

            return ret
        end
    end
end


local function NewPrefixFilter(prefix)
    return function(...)
        local name = table.remove{...}
        if name:find(prefix, 1, true) == 1 then
            return name
        end
    end
end

local function NewPrefixAdder(prefix)
    return function(...)
        local name = table.remove{...}
        return prefix..name
    end
end

local function PreloadRerouter(fn, name)
    return function(...)
        setfenv(fn, getfenv(1))
        local ret = fn(...)
        package.preload[name] = function() return ret end
        return ret
    end
end

local wicker_searcher = NewMappedSearcher(
    NewPrefixFilter(wicker_stem),
    NewBootBinder(GetWickerBooter)
)
local mod_searcher = NewMappedSearcher(
    NewPrefixFilter(modcode_root),
    NewBootBinder(GetModBooter)
)


table.insert(searchers, 1, mod_searcher)

-- DO NOT move this above the preceding searchers insertion.
local mod_rerouter = NewMappedSearcher(
    NewPrefixAdder(modcode_root),
    PreloadRerouter
)
table.insert(_G.package.loaders, mod_rerouter)
table.insert(searchers, 1, wicker_searcher)
