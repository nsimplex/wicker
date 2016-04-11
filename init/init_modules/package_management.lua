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

-- Maps importer functions to their metadata.
local importer_metadata = {}

-- | The exposed version of this function "multiplies" the new importer with
-- the available management prototypes.
--
-- This is up here mainly to document the fields in the 'data' table.
local function raw_register_importer(importer, data)
    assert( IsCallable(importer) )

    assert(type(data) == "table")
    assert(type(data.name) == "string")
    assert(type(data.category) == "string")
    assert(data.lowpriority == nil or type(data.lowpriority) == "boolean")

    if importer_metadata[importer] ~= nil then
        error("Importer '"..data.name.."' already registered.")
    end

    importer_metadata[importer] = data
end

---

local function push_importer_error(importer, what)
    if type(what) == "string" then
        what = "'" .. what .. "'"
    else
        what = tostring(what or "")
    end
    return error(  ("The %s(%s) call didn't return a table"):format( importer_metadata[importer].name, what), 3  )
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
function management_prototypes.Inject(importer)
    assert( IsCallable(importer) )

    assert( type(importer_metadata[importer].name) == "string" )

    return function(env, what)
        env, what = normalize_args(env, what)

        local M = importer(what)
        if type(M) ~= "table" then
            push_importer_error(importer, what)
        end

        InjectNonPrivatesIntoTable( env, pairs(M) )
    end
end

-- Binds the loaded package, by default using AttachMetaIndex from
-- metatablelib.
--
-- Only public string keys (i.e., strings not starting with '_') from the
-- parent environment are exposed.
function management_prototypes.Bind(importer)
    assert( IsCallable(importer) )

    local push_error

    local metadata = importer_metadata[importer]
    if metadata == nil then
        push_error = function()
            return error("Call didn't return a table.")
        end
    else
        assert( type(metadata.name) == "string" )
        push_error = push_importer_error
    end

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
            push_error(importer, what)
        end

        AttachMetaIndex( env, create_index(M), metadata.lowpriority )

        return M
    end
end

-- Replaces the environment of the calling function with the loaded
-- environment.
function management_prototypes.Become(importer)
    assert( IsCallable(importer) )
    assert( type(importer_metadata[importer].name) == "string" )

    return function(what)
        local M = importer(what)
        if type(M) ~= "table" then
            push_importer_error(importer, what)
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

local function _register_importer(importer, data)
    raw_register_importer(importer, data)

    for action, prototype in pairs(management_prototypes) do
        local k = action..data.category
        local v = prototype(importer)

        pacman[k] = v
        assert( _K[k] == v )
    end
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

local function GetGlobal()
    return _G
end
_register_importer(GetGlobal, {
    name = "GetGlobal",
    category = "Global",
    lowpriority = true,
})

local function GetTheUser()
    return wickerrequire "api.theuser"
end
_K.GetTheUser = GetTheUser
_register_importer(GetTheUser, {
    name = "GetTheUser",
    category = "TheUser",
})

local function GetTheMod()
    return wickerrequire "api.themod"
end
_K.GetTheMod = GetTheMod
_register_importer(GetTheMod, {
    name = "GetTheMod",
    category = "TheMod",
})

-- This receives special treatment.
local TheKernel = const(_K)
raw_register_importer(TheKernel, {
    name = "TheKernel",
    category = "TheKernel",
})
pacman.BindTheKernel = management_prototypes.Bind(TheKernel)

---

return pacman()
