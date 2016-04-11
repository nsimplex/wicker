--------------------------------------------------------------------------------
-- | 
-- Module      : wicker.init.init_modules.standard_requirers
-- Note        : 
-- 
-- Defines the standard require-like functions for user code. Also defines the
-- generators for their environments.
-- 
--------------------------------------------------------------------------------

local assert = assert

local _K = assert( _K )
local _G = assert( _G )

local Requirer = assert( Requirer )
local krequire = assert( krequire )

local super_basic_module = assert( super_basic_module )

---

local pairs = assert( pairs )
local ipairs = assert( ipairs )
local next = assert( next )

---

modprobe_init "invariants"
modprobe_init "package_management"
modprobe_init "corelib"
modprobe_init "metatablelib"

---

local AssertEnvironmentValidity = assert(AssertEnvironmentValidity)

local GetUsercodeRoot = assert(GetUsercodeRoot)
assert(GetModcodeRoot == GetUsercodeRoot)

local IsCallable = assert(IsCallable)

local BindTheKernel = assert(BindTheKernel)
local BindTable = assert(BindTable)

local _register_importer = assert(_register_importer)
local _register_importer_at = assert(_register_importer_at)


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--  Forward declarations
--------------------------------------------------------------------------------

-- | Parent environment of all user environments, which means all user
-- environments have access to its variables. The user can override this with
-- a custom env root (which will usually inherit from the original USERROOT
-- itself).
local USERROOT

--| '_USER' is a proxy to USERROOT as an upvalue. So if USERROOT is
-- reassigned, we dynamically adapt.
local _USER

local function RegisterUserEnvironment(r)
    USERROOT = AssertEnvironmentValidity(r)
    return r
end
_K.RegisterUserEnvironment = RegisterUserEnvironment
_K.RegisterModEnvironment = RegisterUserEnvironment

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--  The environment binders
--------------------------------------------------------------------------------

local function WickerBind(env)
    BindTheKernel(env)
    return AssertEnvironmentValidity(env)
end
_K.WickerBind = WickerBind

local function UserBind(env)
    BindTable(env, USERROOT)
    return AssertEnvironmentValidity(env)
end
_K.UserBind = UserBind
_K.ModBind = UserBind

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--  The environment generators
--------------------------------------------------------------------------------

local function initialize_module(env)
    env._USER = _USER
    env._MOD = _USER
    return env
end

local pkgrequire_metadata = {
    name = "pkgrequire",
    category = "Package",
}

local function self_postinit_error()
    return error("AddSelfPostInit may only be called while the file is being loaded!", 2)
end

local function build_basic_module_self_postinit_wrapper(env)
    local self_postinits = {}
    local n_self_postinits = 0

    assert(env.AddSelfPostInit == nil or env.AddSelfPostInit == self_postinit_error)

    function env.AddSelfPostInit(fn)
        assert(IsCallable(fn))
        assert(self_postinits ~= nil)

        n_self_postinits = n_self_postinits + 1
        self_postinits[n_self_postinits] = fn
    end

    local function run_self_postinits(ret, ...)
        assert(self_postinits ~= nil)

        local ret0 = ret

        if ret == nil then
            ret = env
        end
        for i = 1, n_self_postinits do
            local fn = self_postinits[i]
            fn(ret, env)
        end
        self_postinits = nil
        n_self_postinits = 0
        env.AddSelfPostInit = self_postinit_error

        return ret0, ...
    end

    local function wrapper_fn(chunk)
        return function(...)
            return run_self_postinits(chunk(...))
        end
    end

    return wrapper_fn
end

local function basic_module(importer, name)
    local env = super_basic_module(importer.package, name)
    local _PACKAGE = assert(env._PACKAGE)

    local pkg_prefix
    if _PACKAGE == "" then
        pkg_prefix = ""
    else
        pkg_prefix = _PACKAGE.."."
    end

    initialize_module(env)

    local pkgrequire = importer.fork_from_root(pkg_prefix)

    env.pkgrequire = pkgrequire
    _register_importer_at(env, pkgrequire, pkgrequire_metadata)

    local wrapper_fn = build_basic_module_self_postinit_wrapper(env)

    return env, wrapper_fn
end

local function new_wicker_env(name, importer)
     return WickerBind(basic_module(importer, name))
end

USERROOT = new_wicker_env("user", krequire)

-- This makes _USER a proxy to USERROOT as an upvalue. So if USERROOT is
-- reassigned, we dynamically adapt.
_USER = setmetatable({}, {
    __index = function(_, k)
        return USERROOT[k]
    end,
    __newindex = function(self, k, v)
        USERROOT[k] = v
        return true
    end,
    __pairs = function()
        return pairs(USERROOT)
    end,
    __next = function(_, k)
        return next(USERROOT, k)
    end,
    __ipairs = function()
        return ipairs(USERROOT)
    end,
    __len = function()
        return #USERROOT
    end,
})

initialize_module(_K)

-- | This enables cyclic referencing ('_USER._USER._USER.(...)').
initialize_module(USERROOT)

local function new_user_env(name, importer)
    return UserBind(basic_module(importer, name))
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--  The requirers
--------------------------------------------------------------------------------

-- TODO: local generation of BindPkg stuff.

local wickerrequire = krequire.fork(nil, "wicker module")
wickerrequire.SetEnvironment(new_wicker_env)
_K.wickerrequire = wickerrequire

local userrequire = Requirer(new_user_env, GetUsercodeRoot(), "user module")
_K.userrequire = userrequire

local modrequire = userrequire.fork(nil, "mod module")
_K.modrequire = modrequire


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--  Exporting
--------------------------------------------------------------------------------

_register_importer(wickerrequire, {
    name = "wickerrequire",
    category = "WickerModule",
})

_register_importer(userrequire, {
    name = "userrequire",
    category = "UserModule",
})

_register_importer(modrequire, {
    name = "modrequire",
    category = "ModModule",
})
