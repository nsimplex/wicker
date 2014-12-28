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

local NewClassMetatable = (function()
	local basic_mt = {
		__call = function(class, ...)
			local obj = {}
			setmetatable(obj, class)
			local v = class._ctor(obj, ...)
			if v ~= nil then
				obj = v
			end
			return obj
		end,
	}

	local function parse_prop_spec(spec)
		if type(spec) ~= "table" then
			return
		end

		local getter = spec.get or spec.getter
		local setter = spec.set or spec.setter

		if not (getter or setter) then
			return
		end

		local k = next(spec)
		if getter then
			k = next(spec, k)
		end
		if setter then
			k = next(spec, k)
		end

		if k ~= nil then
			return
		end

		return getter, setter
	end

	local function add_property(class, k, getter, setter)
		local props = rawget(class, PROPERTY_KEY)
		props[k] = {get = getter, set = setter}

		local dummyself = get_dummy_object(class)
		AddPropertyTo(dummyself, k, getter, setter)
	end

	basic_mt.__newindex = function(class, k, v)
		local getter, setter = parse_prop_spec(v)
		if getter or setter then
			add_property(class, k, getter, setter)
			return true
		else
			-- Implement access control?
			rawset(class, k, v)
		end
	end

	return function(class)
		local mt = {}
		for k, v in pairs(basic_mt) do
			mt[k] = v
		end
		return mt
	end
end)()

---

function is_a(self, D)
	local C = getmetatable(self)
	if C == D then return true end

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

local Class = function(baseclass, ctor)
	if type(ctor) ~= "function" then
		ctor, baseclass = baseclass, nil
	end
	assert(baseclass == nil or type(baseclass) == "table")
	assert(type(ctor) == "function")

	local C = GClass(baseclass, ctor)
	setmetatable(C, nil)
	C.RedirectSetters = nil

	assert(C._base == baseclass)

	function C.__index(self, k)
		return C[k]
	end
	C.__newindex = rawset

	C.is_a = is_a

	---

	local inherited_props = {}

	if baseclass ~= nil then
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
	end

	---

	rawset(C, PROPERTY_KEY, {})

	---

	setmetatable(C, NewClassMetatable(C))

	---

	for k, v in pairs(inherited_props) do
		C[k] = v
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
			TheMod:Say("targetself.get. self = ", self)
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

kernel.Class = Class
kernel.ProxyClass = ProxyClass
