--------------------------------------------------------------------------------
-- | 
-- Module      : wicker.init.requirer
-- Note        : 
-- 
-- This module provides require-like functionality under a specified environment.
-- 
--------------------------------------------------------------------------------

local is_being_required = ((...) ~= nil)

---

-- Returns the global environment followed by assert.
local function get_essential_values()
	local function crash()
		({})[nil] = nil
	end

	local _G = _G or GLOBAL or crash()
	local assert = _G.assert or crash()

	return _G, assert
end

local _G, assert = get_essential_values()

---

local error = assert( _G.error )

local type = assert( _G.type )
local tostring = assert( _G.tostring )

---

-- | This is the module table.
local _M = {}

if not is_being_required then
    local myenv = env or _ENV or _G

    if myenv.Requirer then
        return myenv.Requirer
    end

    myenv.Requirer = _M
end

---

-- | This will hold the wicker kernel.
local _K = nil

-- | This sets the wicker kernel. It can only be called once.
local function SetKernel(k)
    if _K ~= nil then
        error( "Wicker kernel already set.", 2 )
    end
    _K = k
end
_M.SetKernel = SetKernel

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--  Searchers
--
--  Here, 'self' is a table with an entry 'self.package' behaving
--  like'_G.package'.
--------------------------------------------------------------------------------

local function expand_env(env, ...)
    if type(env) == "function" then
        env = env(...)
    end
    assert(type(env) == "table")
    return env
end

local function preload_searcher(self, name, env)
	local ret = self.package.preload[name]
	if ret ~= nil then
        _K.raw_setfenv(ret, expand_env(env, name, self))
		return ret
	else
		return "no field package.preload['"..name.."']"
	end
end


local function default_searcher(self, name, env)
    local fs = assert( _K.fs )
    local file_exists = assert( fs.file_exists )
    local loadfile = assert( _K.loadfile )

    name = fs.normalize_module_path_to_native(name)

    local failed_paths = {}
    local nfails = 0

    for pathspec in self.package.path:gmatch("[^;]+") do
        local path = pathspec:gsub("%?", name, 1)
        if file_exists(path) then
            local fn, err = loadfile(path, nil, expand_env(env, name, self))
            if type(fn) ~= "function" then
                err = tostring(err or fn or "Unknown error")
                return error(err, 3)
            end
            return fn
        else
            nfails = nfails + 1
            failed_paths[nfails] = path
        end
    end

    for i = 1, nfails do
        local path = failed_paths[i]
        failed_paths[i] = "\tno file '" .. path .. "'"
    end

    return _G.table.concat(failed_paths, "\n")
end

---

local function close_method(self, f)
    return function(...)
        return f(self, ...)
    end
end

local function close_methods(self, f, ...)
    if f ~= nil then
        return close_method(self, f), close_methods(self, ...)
    end
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--  Custom require
--
--  It receives a table with entries like _G.package as its first parameter,
--  followed by a string description of modules and finally the module path
--  (the 'name' variable). Any extra arguments are passed verbatim to the
--  searchers.
--------------------------------------------------------------------------------

local function set_package_loaded(package, name, val)
    for namevar in _K.fs.module_path_variants(name) do
        package.loaded[namevar] = val
    end
    assert( package.loaded[name] == val or val ~= val )
    return val
end

local function custom_require(package, mod_desc, name, ...)
    local ret = package.loaded[name]
    if not ret then
        mod_desc = tostring(mod_desc or "module")

        assert(type(name) == "string")

		local fail_pieces = {}
        local nfails = 0

        local searchers = assert(package.searchers or package.loaders)

        for i = 1, #searchers do
            local searcher = searchers[i]
			local fn = searcher(name, ...)
			if type(fn) == "function" then
				ret = fn(name)
				if ret == nil then
					ret = package.loaded[name]
                    if ret == nil then
                        ret = true
                    end
				end
                return set_package_loaded(package, name, ret)
			elseif type(fn) == "string" then
                nfails = nfails + 1
                fail_pieces[nfails] = fn
			end
		end

		_G.table.insert(fail_pieces, 1, ("%s '%s' not found:"):format(mod_desc, name))
		return error(_G.table.concat(fail_pieces, "\n"), 3)
	end

    return ret
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--  The Requirer "class"
--
--  It implements require functionality in a __call metamethod-enabled table,
--  which contains all of its operational data (searchers, loaded package
--  cache, etc.).
--
--  It also holds an environment used for the loaded files.
--------------------------------------------------------------------------------

-- Metatable of requirer objects.
local requirer_meta = {
    __call = function(self, name)
        return custom_require(self.package, self.mod_desc,
            self.module_name_map(name), self.GetEnvironment())
    end,
}

local function multiply_code_root(code_root)
    local PATH_SUFFIXES = {
        "?.lua",
        _K.fs.catpath("?", "init.lua"),
    }

    local patts = {}
    for i = 1, #PATH_SUFFIXES do
        patts[i] = _K.fs.catpath(code_root, PATH_SUFFIXES[i])
    end
    return _G.table.concat(patts, ";")
end

local function id1(x) return x end

local function compose1(f, g)
    return function(x)
        return f(g(x))
    end
end

-- Returns a memoized function that concatenates the received string with a
-- prefix.
--
-- This could be a weak table, but the number of modules was assumed to be low
-- enough to make strong references preferable.
local function new_prefixer(prefix)
    assert(prefix == nil or type(prefix) == "string")

    if not prefix or #prefix == 0 then
        return id1
    end

    local cache = {}
    return function(str)
        local ret = cache[str]
        if ret == nil then
            ret = prefix..str
            cache[str] = ret
        end
        return ret
    end
end

-- Wraps a table equivalent to _G.package into a Requirer object. This is
-- simply the body of the Requirer constructor stripped of the creation of a
-- package table itself.
local function wrapPackageTable(pristine_package, env, code_root, mod_desc)
	env = env or _G
    mod_desc = mod_desc or "module"

    assert(type(package) == "table")
    assert(type(env) == "table")
    assert(type(mod_desc) == "string")

    local self = {}

    --- 

    -- FIXME: make sure this was readded somehow.
	--- self.package.path = MODROOT .. "?.lua",

	self.package = {}
    for k, v in pairs(pristine_package) do
        self.package[k] = v
    end
    
    self.package.path = self.package.path or _G.package.path
    self.package.preload = self.package.preload or {}
    self.package.loaded = self.package.loaded or {}

    self.package.searchers = {
        close_methods(self, preload_searcher, default_searcher)
    }
    self.package.loaders = self.package.searchers

    ---

    self.mod_desc = mod_desc

    ---

    self.require = self

    function self.force_require(name, ...)
        self.package.loaded[name] = nil
        return self.require(name, ...)
    end
    self.force = self.force_require

    self.module_name_map = id1

    function self.package_loaded(name)
        return self.package.loaded[self.module_name_map(name)]
    end

    ---

    local function setPackageLoaded(name, val)
        return set_package_loaded(self.package, name, val)
    end
    self.SetPackageLoaded = setPackageLoaded

    local function setCodeRoot(r)
        assert(type(r) == "string")
        self.package.path = multiply_code_root(r)
    end
    self.SetCodeRoot = setCodeRoot

    local function setPrefix(p)
        self.module_name_map = new_prefixer(p)
    end
    self.SetPrefix = setPrefix

    local function appendPrefix(p)
        self.module_name_map =
            compose1(self.module_name_map, new_prefixer(p))
    end
    self.AppendPrefix = appendPrefix

    local function prependPrefix(p)
        self.module_name_map =
            compose1(new_prefixer(p), self.module_name_map)
    end
    self.PrependPrefix = prependPrefix

    local function getEnvironment()
        return env
    end
    self.GetEnvironment = getEnvironment

    local function setEnvironment(newenv)
        assert(type(newenv) == "table")
        env = newenv
    end
    self.SetEnvironment = setEnvironment

    ---

    local function fork(child_prefix, child_mod_desc)
        child_mod_desc = child_mod_desc or mod_desc
        local child =
            wrapPackageTable(self.package, env, code_root, child_mod_desc)
        if child_prefix then
            child.AppendPrefix(child_prefix)
        end
        return child
    end
    self.fork = fork


    if path_prefix then
        setPathPrefix(path_prefix)
    end


    return _G.setmetatable(self, requirer_meta)
end

---

local function Requirer(...)
    return wrapPackageTable({}, ...)
end
_M.Requirer = Requirer

_M.is_requirer = function(x)
    return _G.getmetatable(x) == requirer_meta
end
_M.IsRequirer = _M.is_requirer

---

--[[
local ModRequirer = Class(Requirer, function(self)
	Requirer._ctor(self, _M)
end)

function ModRequirer:GetModEnvironment()
	return self:GetDefaultEnvironment()
end
ModRequirer.GetModEnv = ModRequirer.GetModEnvironment

function ModRequirer:GetModInfo()
	return self:GetModEnvironment().modinfo
end
]]--

---

return _G.setmetatable(_M, {
    __call = function(_, ...)
        return Requirer(...)
    end,
})
