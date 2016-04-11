--------------------------------------------------------------------------------
-- | 
-- Module      : wicker.init.init_modules.package.management
-- Note        : 
-- 
-- Parametric tools for environment based package loading and importing.
-- 
--------------------------------------------------------------------------------

local assert = assert
local _K = assert( _K )
local _G = assert( _G )

local error = assert( error )

local type = assert( type )
local tostring = assert( tostring )
local pcall = assert( pcall )

---

modprobe_init "layering"
modprobe_init "corelib"
modprobe_init "metatablelib"
modprobe_init "auxlib"

---

local pacman = _make_inner_kernel_env()
_K.pacman = pacman

---

local GetOuterEnvironment = assert( _GetOuterEnvironment )
local IsCallable = assert( IsCallable )
local IsPublicString = assert( IsPublicString )
local InjectNonPrivatesIntoTable = assert( InjectNonPrivatesIntoTable )

---

-- | This is up here mainly to document the fields in the 'metadata' table.
local function validate_importer_metadata(importer, metadata)
    assert( IsCallable(importer) )

    assert(type(metadata) == "table")
    assert(type(metadata.name) == "string")
    assert(type(metadata.category) == "string")
    assert(metadata.lowpriority == nil or type(metadata.lowpriority) == "boolean")
end

---

local function push_importer_error(metadata, what)
    if type(what) == "string" then
        what = "'" .. what .. "'"
    else
        what = tostring(what or "")
    end
    local name = metadata and metadata.name or "???"
    return error(  ("The %s(%s) call didn't return a table"):format( name, what), 3  )
end


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--  Prototypes
--
--  Here we define higher order functions taking an importer function and
--  returning a wrapper that implements a certain operation (usually assuming
--  its operand is an environment table) over the value returned by said
--  importer.
--------------------------------------------------------------------------------


local management_prototypes = {}

local function normalize_args(env, what)
    if type(env) == "table" and env._PACKAGE then
        return env, what
    else
        return GetOuterEnvironment(), env
    end
end

-- Copies the loaded package.
function management_prototypes.Inject(importer, metadata)
    return function(env, what)
        env, what = normalize_args(env, what)

        local M = importer(what)
        if type(M) ~= "table" then
            push_importer_error(metadata, what)
        end

        InjectNonPrivatesIntoTable( env, pairs(M) )
    end
end

-- Binds the loaded package, by default using AttachMetaIndex from
-- metatablelib.
--
-- Only public string keys (i.e., strings not starting with '_') from the
-- parent environment are exposed.
function management_prototypes.Bind(importer, metadata)
    local function create_index(M)
        return function(_, k)
            if IsPublicString(k) then
                return M[k]
            end
        end
    end

    return function(env, what)
        env, what = normalize_args(env, what)

        local M = importer(what)
        if type(M) ~= "table" then
            push_importer_error(metadata, what)
        end

        AttachMetaIndex( env, create_index(M), metadata.lowpriority )

        return M
    end
end

-- Replaces the environment of the calling function with the loaded
-- environment.
function management_prototypes.Become(importer, metadata)
    return function(what)
        local M = importer(what)
        if type(M) ~= "table" then
            push_importer_error(metadata, what)
        end
        local env, i = GetOuterEnvironment()
        assert( type(i) == "number" )
        assert( i >= 2 )
        local status, err = pcall(setfenv, i + 1, M)
        if not status then
            return error(err, 2)
        end
        return M
    end
end


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--  The _register_importer function.
--------------------------------------------------------------------------------

local function _register_importer_at(t, importer, metadata, filter)
    validate_importer_metadata(importer, metadata)

    local filterset
    if filter then
        filterset = {}
        for i = 1, #filter do
            filterset[filter[i]] = true
        end
    end

    for action, prototype in pairs(management_prototypes) do
        if not filterset or filterset[action] then
            local k = action..metadata.category
            local v = prototype(importer, metadata)

            t[k] = v
        end
    end
end

pacman._register_importer_at = _register_importer_at

local function _register_importer(...)
    return _register_importer_at(pacman, ...)
end

pacman._register_importer = _register_importer
assert( _K._register_importer == _register_importer )


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--  Registering default importers
--------------------------------------------------------------------------------

_register_importer(require, {
    name = "require",
    category = "Module",
})

local function GetTable(t)
    return t
end
_register_importer(GetTable, {
    name = "GetTable",
    category = "Table",
})
assert(BindTable)
assert(BecomeTable)
assert(InjectTable)

local function GetGlobal()
    return _G
end
_register_importer(GetGlobal, {
    name = "GetGlobal",
    category = "Global",
    lowpriority = true,
})
assert(BindGlobal)
assert(BecomeGlobal)
assert(InjectGlobal)

local function GetTheUser()
    return wickerrequire "api.theuser"
end
_K.GetTheUser = GetTheUser
_register_importer(GetTheUser, {
    name = "GetTheUser",
    category = "TheUser",
}, {
    "Bind",
    "Become",
})
assert(BindTheUser)
assert(BecomeTheUser)
assert(not InjectTheUser)

local function GetTheMod()
    return wickerrequire "api.themod"
end
_K.GetTheMod = GetTheMod
_register_importer(GetTheMod, {
    name = "GetTheMod",
    category = "TheMod",
}, {
    "Bind",
    "Become",
})
assert(BindTheMod)
assert(BecomeTheMod)
assert(not InjectTheMod)

-- This receives special treatment.
local TheKernel = const(_K)
_register_importer(TheKernel, {
    name = "TheKernel",
    category = "TheKernel",
}, {
    "Bind",
})
assert(BindTheKernel)
assert(not InjectTheKernel)
assert(not BecomeTheKernel)

---

return pacman()
