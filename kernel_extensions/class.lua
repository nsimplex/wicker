local GClass = _G.Class

local assert, error = assert, error
local type = type

local rawget, rawset = rawget, rawset
local pairs, ipairs = pairs, ipairs
local next = next

local getmetatable, setmetatable = getmetatable, setmetatable

---

local Lambda = wickerrequire "paradigms.functional"

pkgrequire "uuids"

---

local AddPropertyTo = assert( AddPropertyTo )

---

assert( uuid )

local PROPERTY_KEY = uuid()
local ANCESTORS_KEY = uuid()
local PROXYCLASS_KEY = uuid()

local DUMMY_SELF_KEY = uuid()

---

local function get_dummy_object(class)
	local ret = rawget(class, DUMMY_SELF_KEY)
	if ret == nil then
		ret = setmetatable({}, class)
		rawset(class, DUMMY_SELF_KEY, ret)
	end
	return ret
end

local function get_prop_table(self)
	return self._
end

local function require_prop_table(self)
	local pvals = self._
	if pvals == nil then
		pvals = {}
		self._ = pvals
	end
	return pvals
end

local function default_get_prop(self, k)
	local pvals = get_prop_table(self)
	if pvals ~= nil then
		return pvals[k]
	end
end

local function default_set_prop(self, k, v)
	local pvals = require_prop_table(self)
	pvals[k] = v
end

local function wrap_property_setter(fn)
	return function(self, k, v)
		default_set_prop(self, k, v)
		return fn(self, k, v)
	end
end

local NewClassMetatable = (function()
	local function is_iteratable_key(k)
		return k ~= "_"
	end

	local iteratable_next = Lambda.iterator.SimpleFilter(is_iteratable_key, next)

	local function iteratable_pairs(obj)
		return iteratable_next, obj, nil
	end

	local function get(t, k, ...)
		if k == nil then return nil end

		local v = t[k]
		if v == nil then
			return get(t, ...)
		else
			return v
		end
	end

	local function parse_prop_spec(spec)
		if type(spec) ~= "table" then
			return
		end

		local default = get(spec, 1, "default")
		local getter = get(spec, "get", "getter")
		local setter = get(spec, "set", "setter")

		if default == nil and getter == nil and setter == nil then
			return
		end

		local k = next(spec)
		if default ~= nil then
			k = next(spec)
		end
		if getter ~= nil then
			k = next(spec, k)
		end
		if setter ~= nil then
			k = next(spec, k)
		end

		if k ~= nil then
			return
		end

		return default, getter, setter
	end

	local class_metadata = {}

	local function get_class_metadata(class)
		local ret = class_metadata[class]
		if ret == nil then
			ret = {}
			class_metadata[class] = ret
		end
		return ret
	end
	
	local function first_default_property_init(class)
		local mdata = get_class_metadata(class)

		if mdata.default_property_init then return end
		mdata.default_property_init = true

		if not class.__next then
			class.__next = iteratable_next
		end
		if not class.__pairs then
			class.__pairs = iteratable_pairs
		end
	end

	local function has_default_property_values(class)
		local mdata = class_metadata[class]
		return mdata and mdata.default_property_values
	end

	local function add_property(class, k, default, getter, setter)
		local props = rawget(class, PROPERTY_KEY)

		props[k] = {default, get = getter, set = setter}

		local dummyself = get_dummy_object(class)
		AddPropertyTo(dummyself, k, getter, setter)

		if default ~= nil then
			get_class_metadata(class).default_property_values = true
		end
	end

	local function readonly_setter(t, k, v)
		local msg = ("Attempt to set readonly property '%s' in table %s.")
			:format(tostring(k), tostring(t))
		return error(msg, 2)
	end

	local function writeonly_getter(t, k)
		local msg = ("Attempt to get writeonly property '%s' in table %s.")
			:format(tostring(k), tostring(t))
		return error(msg, 2)
	end

	local function expand_getter_setter(getter, setter)
		local has_default_prop = false

		if setter == nil or setter == false then
			setter = readonly_setter
		end

		if getter == true or getter == nil then
			getter = default_get_prop
			setter = wrap_property_setter(setter)
			has_default_prop = true
		elseif getter == false then
			getter = writeonly_getter
		end

		return getter, setter, has_default_prop
	end

	local function class_newindex(class, k, v)
		local default, getter, setter = parse_prop_spec(v)

		if default ~= nil or getter ~= nil or setter ~= nil then
			local has_default_prop
			getter, setter, has_default_prop = expand_getter_setter(getter, setter)

			add_property(class, k, default, getter, setter)

			if has_default_prop then
				first_default_property_init(class)
			end

			return true
		else
			-- Implement access control?
			rawset(class, k, v)
		end
	end

	local basic_mt = {
		__newindex = class_newindex,
		__call = function(class, ...)
			local obj = {}
			setmetatable(obj, class)
			local v = class._ctor(obj, ...)
			if v ~= nil then
				obj = v
			end
			if obj ~= nil and has_default_property_values(class) then
				local props = rawget(class, PROPERTY_KEY)
				for k, spec in pairs(props) do
					local dflt = spec[1]
					if dflt ~= nil then
						spec.set(obj, k, dflt)
					end
				end
			end
			return obj
		end,
	}

	local function memoize_method(methodname, method, arity)
		local cached_method, cached_clear =
			memoize_inplace(methodname, arity)(method)

		local function method2(self, ...)
			local mastercache = require_prop_table(self)
			return cached_method(mastercache, self, ...)
		end

		local function clear2(self)
			local mastercache = require_prop_table(self)
			return cached_clear(mastercache)
		end

		return method2, cached2
	end

	local function new_const_var(class, k, v, arity)
		if type(v) ~= "function" then
			class[k] = {default = v}
		else
			class[k] = {get = memoize_method(k, v, arity)}
		end
	end

	local function const_var_factory(arity)
		return function(class, k, v)
			return new_const_var(class, k, v, arity)
		end
	end

	local DIRTY_KEY = {}

	local function get_dirty_data(self)
		return rawget(self, DIRTY_KEY)
	end

	local function require_dirty_data(self)
		local data = rawget(self, DIRTY_KEY)
		if data == nil then
			data = {}
			rawset(self, DIRTY_KEY, data)
		end
		return data
	end

	local function get_methods_dirty_data(self)
		local data = get_dirty_data(self)
		if data ~= nil then
			return data[data]
		end
	end

	local function require_methods_dirty_data(self)
		local data = require_dirty_data(self)
		local methods_data = data[data]
		if methods_data == nil then
			methods_data = {}
			data[data] = methods_data
		end
		return methods_data
	end

	local function get_last_dirty(self)
		local data = get_dirty_data(self)

		if not (data and data.last_dirty) then
			return 0
		end

		return data.last_dirty
	end

	-- Timestamp of the last method cleaned.
	local function get_last_clean(self)
		local data = get_dirty_data(self)

		if not (data and data.last_clean) then
			return 0
		end

		return data.last_clean

	end

	local function get_method_last_clean(self, methodname)
		local methods_data = get_methods_dirty_data(self)
		if methods_data then
			return methods_data[methodname] or -math.huge
		end
	end

	local function make_method_clean(self, methodname)
		local data = require_dirty_data(self)

		local timestamp = get_last_dirty(self)

		local methods_data = require_methods_dirty_data(self)
		methods_data[methodname] = timestamp

		data.last_clean = timestamp
	end

	local function make_dirty(self)
		local data = require_dirty_data(self)
		data.last_dirty = get_last_clean(self) + 1
	end

	local function is_method_dirty(self, methodname)
		local methods_data = get_dirty_data(self)
		
		local last_clean = methods_data and methods_data[methodname]

		return not last_clean or last_clean < get_last_dirty(self)
	end

	local function new_quasiconst_var(class, k, v, arity)
		if type(v) ~= "function" then
			return new_const_var(class, k, v, arity)
		end

		local cache_get, cache_clear = memoize_method(k, v, arity)

		local function doget(self, ...)
			if is_method_dirty(self, k) then
				cache_clear(self)
				make_method_clean(self, k)
			end
			return cache_get(self, ...)
		end

		class[k] = {get = doget}
	end

	local function quasiconst_var_factory(arity)
		return function(class, k, v)
			return new_quasiconst_var(class, k, v, arity)
		end
	end

	local common_methods = {
		MakeDirty = make_dirty,
	}
	local function make_methods(class)
		local methods = {}
		for k, v in pairs(common_methods) do
			methods[k] = v
		end

		methods.const = metatable.newaccessor(const_var_factory(0))
		rawset(methods.const, "arity_cache", {})
		getmetatable(methods.const).__call = memoize_1ary_inplace("arity_cache", function(arity)
			return const_var_factory(arity or 0)
		end)

		methods.quasiconst = metatable.newaccessor(quasiconst_var_factory(0))
		rawset(methods.quasiconst, "arity_cache", {})
		getmetatable(methods.quasiconst).__call = memoize_1ary_inplace("arity_cache", function(arity)
			return quasiconst_var_factory(arity or 0)
		end)

		return methods
	end

	return function(class)
		local mt = {}
		for k, v in pairs(basic_mt) do
			mt[k] = v
		end

		mt.__index = make_methods(class)

		return mt
	end
end)()

---

function is_a(self, D)
	local C = getmetatable(self)
	if C == D then return true end
	if C == nil or type(self) ~= "table" then return false end

	local proxy_target = rawget(self, PROXYCLASS_KEY)

	if proxy_target ~= nil then
		if proxy_target:is_a(D) then
			return true
		end
	end

	local ancestors = rawget(C, ANCESTORS_KEY)

	if ancestors ~= nil then
		return ancestors[D]
	else
		if C._base then
			return get_dummy_object(C._base):is_a(D)
		end
	end

	return false
end

local function parse_class_args(baseclass, ctor, props)
	if type(ctor) ~= "function" then
		baseclass, ctor, props = nil, baseclass, ctor
	end

	if props == nil then
		props = {}
	end

	assert(baseclass == nil or type(baseclass) == "table")
	assert(type(ctor) == "function")
	assert(type(props) == "table")

	return baseclass, ctor, props
end

local Class = function(baseclass, ctor, props, ...)
	baseclass, ctor, props = parse_class_args(baseclass, ctor, props)

	local C = GClass(baseclass, ctor, nil, ...)
	setmetatable(C, nil)
	C.RedirectSetters = nil

	assert(C._base == baseclass)

	function C.__index(self, k)
		return C[k]
	end
	C.__newindex = rawset

	C.is_a = is_a

	---

	if baseclass ~= nil then
		local inherited_props = {}

		local ancestors = {}

		local baseprops, baseancestors = rawget(baseclass, PROPERTY_KEY), rawget(baseclass, ANCESTORS_KEY)

		if baseprops ~= nil then
			inherited_props = baseprops
		end

		if baseancestors ~= nil then
			for B in pairs(baseancestors) do
				ancestors[B] = true
			end
			ancestors[baseclass] = true
		else
			local ancestor = baseclass
			repeat
				ancestors[ancestor] = true
				ancestor = ancestor._base
			until ancestor == nil
		end

		rawset(C, ANCESTORS_KEY, ancestors)

		---

		for k, v in pairs(inherited_props) do
			C[k] = v
		end
	end

	---

	rawset(C, PROPERTY_KEY, {})

	---
	
	setmetatable(C, NewClassMetatable(C))

	---
	
	if props ~= nil then
		for k, setter in pairs(props) do
			C[k] = {setter = setter}
		end
	end

	---

	return C
end

local PROXYMETHOD_CACHE = uuid()

local function ProxyMethod(self, fn)
	local cache = rawget(self, PROXYMETHOD_CACHE)
	if cache == nil then
		cache = setmetatable({}, {__mode = "k"})
		rawset(self, PROXYMETHOD_CACHE, cache)
	end

	local gn = cache[fn]
	if gn == nil then
		gn = function(maybeself, ...)
			if maybeself == self then
				local targetself = assert( rawget(self, PROXYCLASS_KEY) )
				maybeself = targetself
			end
			return fn(maybeself, ...)
		end
		cache[fn] = gn
	end
	return gn
end

local function proxy_index(self, k)
	local v = rawget(self, PROXYCLASS_KEY)[k]
	if type(v) == "function" then
		return ProxyMethod(self, v)
	end
	return v
end

local function proxy_newindex(self, k, v)
	rawget(self, PROXYCLASS_KEY)[k] = v
	return true
end

local function redirect_setters(class)
	AttachMetaNewIndexTo(get_dummy_object(class), proxy_newindex)
end

local function ProxyClass(targetclass, ...)
	local C = Class(...)

	local old_ctor = C._ctor
	function C._ctor(self, targetself, ...)
		if targetself == nil then
			return error("Target object of proxy object cannot be nil.", 3)
		end
		rawset(self, PROXYCLASS_KEY, targetself)
		assert( self.targetself == targetself, "Logic error." )
		return old_ctor(self, ...)
	end

	C.targetself = {
		get = function(self)
			return rawget(self, PROXYCLASS_KEY)
		end,
		set = Lambda.Error("targetself cannot be set."),
	}

	AttachMetaIndexTo(get_dummy_object(C), proxy_index, true)

	function C.RedirectSetters()
		redirect_setters(C)
		C.RedirectSetters = Lambda.Nil
	end

	return C
end

kernel.is_a = is_a

kernel.Class = Class
kernel.ProxyClass = ProxyClass
