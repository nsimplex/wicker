--------------------------------------------------------------------------------
-- | 
-- Module      : wicker.init
-- Note        : The point of entrance to the wicker framework
-- 
-- This is the main point of access to the wicker framework, and can be loaded
-- in many ways. Any function conforming to the interface of either require or
-- dofile may be used in loading this file, and hence wicker.
--
-- The only requirement is that the environment in which this file runs has a
-- key _G or GLOBAL storing the global environment.
-- 
--------------------------------------------------------------------------------


-- We assume this is nil iff we weren't require'd (or equivalent).
local module_path = (...)

-- This will append ".init" if it is missing.
local real_module_path = module_path

--

-- Returns the global environment followed by assert.
local function get_essential_values()
	local function crash()
		({})[nil] = nil
	end

	local _G = _G or GLOBAL or crash()
	local assert = _G.assert or crash()

	return _G, assert
end

_G, assert = get_essential_values()
local _G, assert = _G, assert

local error = assert( _G.error )

local type = assert( _G.type )

local debug = assert( _G.debug )
local string = assert( _G.string )
local string_match = assert( string.match )
local string_find = assert( string.find )
local string_gsub = assert( string.gsub )
local tostring = assert( _G.tostring )
local table_concat = assert( _G.table.concat )

local getmetatable = assert( _G.getmetatable )
local setmetatable = assert( _G.setmetatable )

---

-- | 
-- This holds the wicker kernel, the core environment inherited by every other
-- wicker module environment.
local _K = { _G = _G }

local kernel = _K
-- I'm using 'kernel' just to avoid spelling 'KKK'.
kernel._K = _K
kernel.kernel = _K

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--  Lua version detection and caching
--------------------------------------------------------------------------------

local _VERSION = assert( _G._VERSION )
_K._VERSION = _VERSION

-- | Format: is greater than or equal to <version>.
_K.IS_GE_LUA51 = true
_K.IS_GE_LUA52 = true
_K.IS_GE_LUA53 = true

-- greater than
_K.IS_GT_LUA53 = false

if _VERSION < "Lua 5.2" then
    if _VERSION < "Lua 5.1" then
        error("Unsupported Lua version: ".._VERSION)
    end
    _K.IS_GE_LUA52 = false
    _K.IS_GE_LUA53 = false
elseif _VERSION < "Lua 5.3" then
    _K.IS_GE_LUA53 = false
elseif _VERSION > "Lua 5.3" then
    _K.IS_GT_LUA53 = true
end

-- equality tests
_K.IS_LUA51 = (_K.IS_GE_LUA51 and not _K.IS_GE_LUA52)
_K.IS_LUA52 = (_K.IS_GE_LUA52 and not _K.IS_GE_LUA53)
_K.IS_LUA53 = (_K.IS_GE_LUA53 and not _K.IS_GT_LUA53)

_K.IS_LUAJIT = (_G.rawget(_G, "jit") ~= nil)

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--  Basic utilities
--------------------------------------------------------------------------------

-- This is just to allow for distinguishing an uuid from an ordinary table.
local UUID_META = {}
_K.UUID_META = UUID_META

-- | Returns a universally unique identifier for the current Lua State.
local function uuid()
    return setmetatable({}, UUID_META)
end
_K.uuid = uuid

local FAILED_RUNNING = false
local function _panic(message, level)
	level = level or 1
	if level > 0 then
		level = level + 1
	end
	FAILED_RUNNING = true
	error(tostring(message), level)
end
_K._panic = _panic

-- | Returns a function that when called triggers an error.
local function Error(...)
    local args = {...}
    return function()
        local sargs = {}
        for i = 1, #args do
            sargs[i] = tostring(args[i])
        end
        return _K.error(table_concat(sargs))
    end
end
_K.Error = Error

local VarExists = (function()
    local rawget = assert( _G.rawget )
    local pcall = assert( _G.pcall )

    local function indextable(t, k)
        return t[k]
    end

    local function get_global(k)
        return rawget(_G, k)
    end

    return function(name, env)
        if env == nil or env == _G then
            return get_global(name) ~= nil
        end

        local status, val = pcall(indextable, env, name)

        return status and val ~= nil
    end
end)()
_K.VarExists = VarExists


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--  Basic filesystem utilities
--------------------------------------------------------------------------------

local fs = {}
_K.fs = fs

local file_exists = _G.rawget(_G, "kleifileexists")
if not file_exists then
    file_exists = function(path)
        local fh = _G.io.open(path, "r")
        if fh then
            fh:close()
            return true
        else
            return false
        end
    end
end
fs.file_exists = file_exists
fs.fileexists = file_exists

-- Native directory separator.
local NATIVE_DIR_SEP = _G.package.config:sub(1,1)
fs.NATIVE_DIR_SEP = NATIVE_DIR_SEP

-- Directory separator used as standard.
local STD_DIR_SEP
if NATIVE_DIR_SEP == "/" or NATIVE_DIR_SEP == "\\" then
    STD_DIR_SEP = "/"
else
    STD_DIR_SEP = NATIVE_DIR_SEP
end
fs.STD_DIR_SEP = STD_DIR_SEP
fs["/"] = STD_DIR_SEP

-- Directory separators. This includes the pattern for a Lua module separator
-- (".").
local DIR_SEPS = "/\\"
if not DIR_SEPS:find(NATIVE_DIR_SEP, 1, true) then
    DIR_SEPS = NATIVE_DIR_SEP..DIR_SEPS
end
fs.DIR_SEPS = DIR_SEPS

-- Non-standard directory separators.
local NON_STD_DIR_SEPS = DIR_SEPS:gsub(STD_DIR_SEP, "", 1)
fs.NON_STD_DIR_SEPS = NON_STD_DIR_SEPS

-- Concatenates path elements.
local function catpath(...)
    return table_concat({...}, STD_DIR_SEP)
end
fs.catpath = catpath

-- Concatenates module path elements.
local function catmodpath(...)
    return table_concat({...}, ".")
end
fs.catmodpath = catmodpath
fs.catmodulepath = catmodpath

-- Receives a pattern and returns a function which takes a string and returns
-- what comes before and after the final instance of said pattern.
--
-- If there is no match, nil is returned.
local function split_at_last(patt)
    assert(type(patt) == "string")
    local fullpatt = "^(.*)"..patt.."(.-)$"

    return function(str)
        return string_match(str, fullpatt)
    end
end

-- Splits a path into its directory and file name components.
local split_path = (function()
    local splitter = split_at_last("["..DIR_SEPS.."]+")

    return function(path)
        local dname, fname = splitter(path)
        if not dname then
            -- cwd
            dname = "."
            fname = path
        elseif dname == "" then
            -- root
            dname = src:sub(1, 1)
        end
        return dname, fname
    end
end)()
fs.split_path = split_path
fs.split = split_path

-- Splits a module path into its package and module name components.
local split_module_path = (function()
    local splitter = split_at_last("[."..DIR_SEPS.."]")

    return function(path)
        local pname, mname = splitter(path)
        if not pname then
            mname = path
        end
        return pname, mname
    end
end)()

fs.split_module_path = split_module_path

-- See Data.Bifunctor (Haskell).
local function splitter_bimap(splitter)
    local function first(path)
        local dname, fname = splitter(path)
        return dname
    end

    local function second(path)
        local dname, fname = splitter(path)
        return fname
    end

    return first, second
end

fs.dirname, fs.basename = splitter_bimap(split_path)

fs.pkgname, fs.modulename = splitter_bimap(split_module_path)
fs.pkgname = split_module_path

-- Replaces directory separators with the given string.
local function normalize_path_with(repl)
    local pattern = "["..DIR_SEPS.."]+"
    return function(path)
        return string_gsub(path, pattern, repl)
    end
end

-- Replaces directory separators and "." with the given string.
local function normalize_module_path_with(repl)
    local pattern = "[."..DIR_SEPS.."]+"
    return function(path)
        return string_gsub(path, pattern, repl)
    end
end

local normalize_module_path = normalize_module_path_with(".")
fs.normalize_module_path = normalize_module_path

local normalize_file_path = normalize_path_with(STD_DIR_SEP)
fs.normalize_file_path = normalize_file_path

local normalize_module_path_to_native = normalize_module_path_with(NATIVE_DIR_SEP)
fs.normalize_module_path_to_native = normalize_module_path_to_native


-- Takes a list of path separator characters and a normalize_XYZ_with style
-- function..
--
-- Returns a function that a path and returns an iterator over each possible
-- directory separator all-or-nothing replacements over it.
local function new_path_variant_iterator(seps, normalize_with)
    local coroutine = assert( _G.coroutine )

    local normalizers = {}
    local n = 0
    for c in seps:gmatch(".") do
        n = n + 1
        normalizers[n] = normalize_with(c)
    end

    local function co_body(path)
        assert( type(path) == "string" )
        coroutine.yield(path)
        for i = 1, n do
            local f = normalizers[i]
            local path2 = assert( f(path) )
            if path2 ~= path then
                coroutine.yield(path2)
            end
        end
    end

    return function(path)
        return coroutine.wrap(co_body), path
    end
end

local path_variants =
    new_path_variant_iterator(DIR_SEPS, normalize_path_with)
fs.path_variants = path_variants

local module_path_variants =
    new_path_variant_iterator("."..DIR_SEPS, normalize_module_path_with)
fs.module_path_variants = module_path_variants

-- Takes a module path and returns an iterator over each possible (all or
-- nothing) directory separator replacement over it.
local path_variants = (function()
    local coroutine = assert( _G.coroutine )

    local normalizers = {}
    local n = 0
    for c in DIR_SEPS:gmatch("[^%%]") do
        n = n + 1
        normalizers[n] = normalize_path_with(c)
    end

    local function co_body(path)
        assert( type(path) == "string" )
        coroutine.yield(path)
        for i = 1, n do
            local f = normalizers[i]
            local path2 = assert( f(path) )
            if path2 ~= path then
                coroutine.yield(path2)
            end
        end
    end

    return function(path)
        return coroutine.wrap(co_body), path
    end
end)()
fs.path_variants = path_variants

-- Splits a path at its file extension. In case there isn't one, the argument
-- is returned verbatim followed by nil.
local remove_ext = (function()
    local splitter = split_at_last "%."
    return function(path)
        local preext, ext = splitter(path)
        if not preext or preext == "" then
            -- no extension
            -- the second clause accounts for hidden Unix files with no ext.
            return path, nil
        end
        return preext, ext
    end
end)()
fs.remove_ext = remove_ext

---

-- Directory and file name of this file's path.
local dir_name, file_name = (function()
    local src = assert( debug.getinfo(1, "S").source )
    src = assert( src:match("^@(.+)$") )
    return split_path(src)
end)()

local WICKER_ROOT = dir_name
fs.WICKER_ROOT = WICKER_ROOT

local file_name_without_ext = remove_ext(file_name)

---

for k, v in _G.pairs(fs) do
    _K[k] = v
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--  File loading and function environment manipulation.
--------------------------------------------------------------------------------

local _G_loadfile = assert( _G.loadfile )

local loadfile
if _K.IS_GE_LUA52 then
    loadfile = _G_loadfile
else
    local setfenv = assert( _G.setfenv )

    -- Discards the mode parameter.
    loadfile = function(srcpath, mode, env)
        local fn, err = _G_loadfile(srcpath)
        if fn then
            setfenv(fn, env)
            return fn
        else
            return fn, err
        end
    end
end
_K.loadfile = loadfile

-- The functions 'raw_getfenv' and 'raw_setfenv' should behave like their Lua
-- 5.1 non-"raw_" counterparts, except they're only required to accept a
-- function as their first argument (and not necessarily stack indices). 

if _K.IS_LUA51 then
    _K.raw_getfenv = assert( _G.getfenv )
    _K.raw_setfenv = assert( _G.setfenv )
else
    -- See: http://leafo.net/guides/setfenv-in-lua52-and-above.html

    local getupvalue = assert( debug.getupvalue )
    local upvaluejoin = assert( debug.upvaluejoin )

    _K.raw_getfenv = function(fn)
        assert( type(fn) == "function" )

        local getupvalue = getupvalue

        local upname, upval
        local i = 1
        repeat
            upname, upval = getupvalue(fn, i)
            if upname == "_ENV" then
                return upval
            end
            i = i + 1
        until upname == nil
    end

    _K.raw_setfenv = function(fn, env)
        assert( type(fn) == "function" )

        local getupvalue = getupvalue

        local upname
        local i = 1
        repeat
            upname = getupvalue(fn, i)
            if upname == "_ENV" then
                local function dummy()
                    return env
                end

                upvaluejoin(fn, i, dummy, 1)

                return
            end
            i = i + 1
        until upname == nil
    end
end


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Importing boot/requirer.lua. 
--------------------------------------------------------------------------------

local local_Requirer
do
    local parent_info = debug.getinfo(2, "f")

    -- The parent function. We assume this is the function which loaded (and
    -- is now executing) this file's main chunk.
    local parent_f = parent_info and parent_info.func

    if module_path == nil then
        -- We assume parent_f has a dofile-like interface.
        parent_f = parent_f or assert(modimport or _G.dofile)

        parent_f( catpath(WICKER_ROOT, "init", "requirer.lua" ) )

        local_Requirer = assert( Requirer )
    else
        -- We assume parent_f has a require-like interface.
        parent_f = parent_f or assert( _G.require )

        local mypkg, myname = split_module_path(module_path)
        if myname:lower() ~= file_name_without_ext:lower() then
            mypkg = module_path
        end

        local_Requirer = assert( parent_f(mypkg..".init.requirer") )
    end
end
local Requirer = assert( local_Requirer )
_K.Requirer = Requirer

-- TODO: mark wicker and wicker.init as initialized in all of the relevant
-- package.loaded's.

Requirer.SetKernel( _K )

local krequire = Requirer( _K, dir_name, "kernel module" )
_K.krequire = krequire

krequire.SetPackageLoaded("init", _K)
krequire.SetPackageLoaded(".", _K)
krequire.SetPackageLoaded("", _K)


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--  Defining the basic module-like functions used to wrap all main chunks.
--------------------------------------------------------------------------------

-- Note that _PACKAGE does not include a trailing separator.
local function bless_super_basic_module(env, package, name)
    assert( type(name) == "string", "String expected as module name." )

	env._M = env
    env._ENV = env
	env._NAME = name
	env._PACKAGE = fs.pkgname(name) or ""

    env._G = _G
    env.assert = assert

    package.loaded[name] = env

	return env
end

local function super_basic_module(package, name)
    return bless_super_basic_module({}, package, name)
end
_K.super_basic_module = super_basic_module

--[[
local wicker_module = (function()
    local __index
    local __newindex
    if _K.IS_LUA51 then
        local _G_getfenv = assert( _G.getfenv )
        local _G_setfenv = assert( _G.setfenv )

        __index = function(env, k)
            if k == "_ENV" then
                local v = _G_getfenv(2)
                return v
            else
                return _K[k]
            end
        end

        __newindex = function(env, k, v)
            if k == "_ENV" then
                _G_setfenv(2, v)
                return true
            end
        end
    else
        __index = _K
        __newindex = nil
    end

    local basic_meta = {
        __index = __index,
        __newindex = __newindex,
    }

    return function(name)
        local env = super_basic_module(name)

        local 
    end
end)()
]]--


---

assert(_K._G == _G)
bless_super_basic_module(_K, krequire.package, "init.kernel")
assert(_K._G == _G)

---


krequire "init.timing"
assert(_K._G == _G)

local dataops = krequire "init.dataops"
assert(_K._G == _G)

local kdebug = krequire "init.debug"
assert(_K._G == _G)

assert(kdebug.error == _K.error)
error = assert(_K.error)

krequire "init.checks"
assert(_K._G == _G)

local stdlib = krequire "init.stdlib"
assert(_K._G == _G)

local kernel_thread = krequire.force "init.kernel"
assert(type(kernel_thread) == "thread")

local function resume_thread(thread, id, ...)
    local status, ret = coroutine.resume(thread, ...)
    if not status then
        local msg = tostring(ret).."\a"..id.." THREAD"
        return _panic(kdebug.traceback(thread, msg), 0)
    end
    return ret
end

local function resume_kernel(...)
    return resume_thread(kernel_thread, "WICKER KERNEL", ...)
end

local function profile_module(profile)
    return "profile_d."..profile
end

local function resume_profile(profile, ...)
    local profile_thread = krequire(profile_module(profile))
    assert(type(profile_thread) == "thread")

    local Profile = profile:upper()

    return resume_thread(profile_thread, "WICKER PROFILE "..Profile, ...)
end

local BOOTSTRAPPED = false

local function bootstrap(profile, ...)
    assert(not BOOTSTRAPPED)
    BOOTSTRAPPED = true

    -- We start up the profile.
    resume_profile(profile, resume_kernel)

    -- Now we feed it the user input.
    resume_profile(profile, ...)

    local TheUser = nil

    assert(TheUser)

    _K.RunUserPostInits()

    -- Finally, we feed it the 'TheUser' object.
    return resume_profile(profile, TheUser)
end

local function start_profile(profile, ...)
    local is_actual_start = not krequire.package_loaded(profile_module(profile))

    if is_actual_start then
        return bootstrap(profile, ...)
    else
        return resume_profile(profile, ...)
    end
end

-- local wickerrequire = krequire.fork(nil, "wicker module")
-- _K.wickerrequire = wickerrequire

local function detect_profile()
    local rawget = assert( _G.rawget )

    if rawget(_G, "kleifileexists") then
        return "dontstarve"
    else
        return "pure"
    end
end

local function do_start_wicker(profile, ...)
    if type(profile) ~= "string" then
        return start_profile(detect_profile(), profile, ...)
    else
        return function(...)
            return start_profile(profile, ...)
        end
    end
end

if module_path == nil then
    start_wicker = do_start_wicker
end

do return start_wicker end

---------------------------------------------------------------------------------


do return end

assert( _K.krequire == nil )

---------------------------------------------------------------------------------

local error = assert( _G.error )
local require = assert( _G.require )
local coroutine = assert( _G.coroutine )
local type = assert( _G.type )
local math = assert( _G.math )
local table = assert( _G.table )
local pairs = assert( _G.pairs )
local ipairs = assert( _G.ipairs )
local tostring = assert( _G.tostring )
local setfenv = assert( _G.setfenv )
local debug = assert( _G.debug )






setfenv(1, super_basic_module(...))


local FAILED_RUNNING = false

local function fail(message, level)
	level = level or 1
	if level > 0 then
		level = level + 1
	end
	FAILED_RUNNING = true
	return error(tostring(message), level)
end

local preprocess_boot_params = (function()
	local default_boot_params = {
		debug = false,

		import = require,

		package = assert( _G.package ),

		modcode_root = nil,

		id = nil,

		overwrite_env = true,
	}

	return function(raw_boot_params)
		local boot_params = {}

		for k, v in pairs(default_boot_params) do
			boot_params[k] = v
		end
		for k, v in pairs(raw_boot_params) do
			boot_params[k] = v
		end

		if type(boot_params.modcode_root) ~= "string" then
			return fail("String expected as boot parameter 'modcode_root'.", 3)
		end

		if type(boot_params.id) ~= "string" then
			return fail("String expected as boot parameter 'id'", 3)
		end

		if not boot_params.modcode_root:match("[%./\\]$") then
			boot_params.modcode_root = boot_params.modcode_root.."."
		end

		if type(boot_params.import) == "table" and boot_params.import.package then
			boot_params.package = boot_params.import.package
		end

		return boot_params
	end
end)()

---


---

local kernel, TheMod

local function ptraceback(message, lvl)
	return TheMod:Say(traceback(message, (lvl or 1) + 1))
end

local function bootstrap(env, boot_params)
	local package = boot_params.package

	local function basic_module(name)
		local t = super_basic_module(name)
		package.loaded[name] = t
		setfenv(2, t)
		return t
	end

	local kernel_bootstrapper = boot_params.import(_PACKAGE .. 'boot.kernel')(_G, basic_module)
	assert( type(kernel_bootstrapper) == "thread" )

	local function resume_kernel(...)
		local status, ret = coroutine.resume(kernel_bootstrapper, ...)
		if not status then
			local msg = tostring(ret).."\aWICKER KERNEL THREAD"
			return fail(traceback(kernel_bootstrapper, msg), 0)
		end
		return ret
	end

	kernel = resume_kernel(boot_params)
	kernel.traceback = traceback
	kernel.ptraceback = ptraceback

	local binder = resume_kernel(_PACKAGE)

	assert( coroutine.status(kernel_bootstrapper) == "dead" )


	binder(_M)


	kernel.TheKernel = nil
	TheKernel = nil


	local modrequire, wickerrequire = assert(modrequire), assert(wickerrequire)


	TheMod = (function()
		local mod_builder = GetTheMod()
		assert( type(mod_builder) == "function" )

		local TheMod = mod_builder(boot_params)

		function TheMod:modrequire(...)
			return modrequire(...)
		end

		function TheMod:wickerrequire(...)
			return wickerrequire(...)
		end

		local TheModConcept = GetTheMod()

		assert( TheMod ~= TheModConcept )
		assert( TheMod == TheModConcept.TheMod )

		kernel.TheMod = TheMod
		kernel.TheModConcept = TheModConcept

		kernel.RunModPostInits()

		return TheMod
	end)()
end

local function extend_self()
	local kernel_extender = wickerrequire "kernel_extensions"
	kernel_extender(kernel)

	local api_extender = wickerrequire "api_extensions"
	api_extender()
end

local process_mod_environment = (function()
	local first_run = true

	-- Additions to kernel from mod environments.
	local kernel_env_additions = {}

	return function(env, overwrite)
		kernel.InjectNonPrivatesIntoTableIf(function(k, v)
			local kl = k:lower()
			if (kernel[k] == nil or (overwrite and kernel_env_additions[k])) and v ~= env and not k:match('^Add') and not kl:match('modname') then
				kernel_env_additions[k] = true
				return true
			end
		end, kernel, pairs(env))

		assert( modinfo, 'The mod environment has no modinfo!' )
		assert( MODROOT, 'The mod environment has no MODROOT!' )

		assert( type(modinfo.id) == "string", "Mods without a modinfo.id cannot be used with wicker." )

		if overwrite or kernel.modenv == nil then
			kernel.modenv = env
		end

		if kernel.modname == nil then
			kernel.modname = env.modname
		end

		kernel.Modname = kernel.Modname or kernel.modinfo.name or kernel.modname


		AssertEnvironmentValidity(_M)


		if not TheMod.modinfo then
			TheMod.Modname = Modname
			TheMod.version = modinfo.version
			TheMod.author = modinfo.author

			TheMod.modinfo = modinfo
		end

		TheMod:SlurpEnvironment(env, overwrite)

		if first_run then
			extend_self()
			first_run = false
		end
	end
end)()


return function(env, raw_boot_params)
	if FAILED_RUNNING then return end

	assert( type(raw_boot_params) == "table", "Boot parameters table expected." )

	if kernel == nil then
		bootstrap(env, preprocess_boot_params(raw_boot_params))
		assert( kernel )
		assert( TheMod )
	end

	AssertEnvironmentValidity(_M)

	local overwrite_env = raw_boot_params.overwrite_env
	if overwrite_env == nil then
		overwrite_env = true
	end
	
	process_mod_environment(env, raw_boot_params.overwrite_env)

	AssertEnvironmentValidity(_M)

	return TheMod
end
