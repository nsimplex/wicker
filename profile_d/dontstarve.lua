local assert = assert

local _K = assert( _K )

local _G = assert( _G )
local error = assert( error )

local coroutine = assert( coroutine )

---

local function dflt_boot_params(modenv)
    return {
        id = modenv.modinfo.id,

        modcode_root = "code",

        debug = true, 
    }
end

local function apply_default_boot_params(boot_params, modenv)
    boot_params = weakMerge(boot_params or {}, dflt_boot_params(modenv))

    local MODROOT = assert(modenv.MODROOT)

    boot_params.usercode_root =
        MODROOT..boot_params.modcode_root
    boot_params.modcode_root = nil

    return boot_params
end

---

local COMMON_DSMODULES = {
    "constants",
    "instrospection",
    "platform_detection",
    "pseudo_packages",
}

---

local function apply_game_tweaks(modenv)
    local getmetatable = assert(getmetatable)
    local setmetatable = assert(setmetatable)

    require "vector3"

    -- This optimizes vector operations a bit since it prevents the
    -- reallocations of the vector's table hash part from sizes
    -- 0 -> 1 -> 2 -> 4
    local Vector3 = assert(_G.Vector3)

    local vec3_meta = shallow_copy(assert(getmetatable(Vector3)))
    vec3_meta.__call = function(RealVector3, x, y, z)
        return setmetatable({
            x = x or 0,
            y = y or 0,
            z = z or 0,
        }, RealVector3)
    end
    setmetatable(Vector3, vec3_meta)
end

---

local function check_pristine(boot_params)
    for k in pairs(boot_params) do
        assert(type(k) == "string")
        assert(not k:lower():find "mod")
    end
end

---

local function wrap_print(print)
    local tostring = assert(tostring)
    local table_concat = assert(table.concat)
    local select = assert(select)

    return function(...)
        local n = select("#", ...)
        if n == 0 then
            return print ""
        elseif n == 1 then
            return print(tostring(...))
        else
            local sargs = {...}
            for i = 1, n do
                sargs[i] = tostring(sargs[i])
            end
            return print(table_concat(sargs, "\t"))
        end
    end
end

---

return krequire("profile_d.common")(function(resume_kernel)
    -- Waits for the user to provide input.
    local modenv, boot_params = coroutine.yield()

    assert(modenv, "Please provide the mod environment as the first argument to the dontstarve profile.")
    
    local modname = assert(modenv.modname)
    local MODROOT = assert(modenv.MODROOT)

    apply_default_boot_params(boot_params, modenv)

    ---

    check_pristine(boot_params)
    apply_game_tweaks(modenv)

    _K.Point = assert( _G.Point )
    _K.Vector3 = assert( _G.Vector3 )

    _K.env = modenv
    _K.modenv = modenv

    _K.print = wrap_print(rawget(_G, "nolineprint") or _G.print)
    _K.nolineprint = _K.print

    function _K.GetModDirectoryName()
        return modenv.modname
    end

    -- Waits for init to reply.
    local TheUser = assert( coroutine.yield( resume_kernel(boot_params) ) )

    local TheMod = TheUser
    _K.TheMod = TheUser
    
    local dsmodprobe = NewModProber("dsmodules.", "Don't Starve kernel module")
    _K.dsmodprobe = dsmodprobe

    for _, module_name in ipairs(COMMON_DSMODULES) do
        dsmodprobe(module_name)
    end

    local function get_modenv()
        return modenv
    end

    local use = Requirer( get_modenv, MODROOT, "mod file" )
    _K.use = use

    local function extend_modenv()
        assert(modenv.GLOBAL == _G)
        modenv._G = _G
        modenv.TheMod = TheMod
        modenv.use = use
        modenv.wickerrequire = assert( wickerrequire )
        modenv.modrequire = assert( modrequire )
    end

    while true do
        embedEnvSomehow(modenv)
        extend_modenv()
        -- Listens for further modenv input from the user.
        modenv = coroutine.yield( TheMod )
    end
end)
