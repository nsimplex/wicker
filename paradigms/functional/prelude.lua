local assert = assert
local error = error

local pairs, ipairs = pairs, ipairs

local type = type
local tostring = tostring

local getmetatable, setmetatable = getmetatable, setmetatable

local unpack = unpack

---

BindPackage "common"

local const = assert( const )
local id = assert( id )
local compose = assert( compose )

---

local function append_array(A, B)
	if B then
		A = A or {}
		local nA = #A
		for i = 1, #B do
			A[nA + i] = B[i]
		end
	end
	return A
end

local function merge_tables(t, ...)
	assert(type(t) == "table")
	local us = {...}
	for _, u in ipairs(us) do
		assert(type(u) == "table")
		for k, v in pairs(u) do
			t[k] = v
		end
	end
	return t
end

---

-- TODO: **redo** getmetatablin' and default typing and such.
local new_typeclass_meta = (function()
	-- __call = check_instance . getmetatable	
	local basic_meta = {
		__call = nil,
	}

	return function(tc)
		local meta = {}
		for k, v in pairs(basic_meta) do
			meta[k] = v
		end

		local spec = assert( tc.spec )
		
		meta.__index = spec
		meta.__newindex = spec

		return meta
	end
end)()

---

local MustImplement

---

local TypeClass = (function()
	local SATISFIES_KEY = {}

	local err_msgs = {}

	function err_msgs.MUSTIMPLEMENT_ERROR(k, instancename)
		return ("Missing implementation of '%s' in instance '%s'.")
			:format(tostring(k), tostring(instancename))
	end

	function err_msgs.MUSTIMPLEMENT_ERROR_FULL(k, instancename, tcname)
		return ("Missing implementation of '%s' in instance '%s' of '%s'.")
			:format(tostring(k), tostring(instancename), tostring(tcname))
	end

	function err_msgs.INCOMPLETE_MINIMAL(k, tcname)
		return ("Minimal implementation of typeclass '%s' does not provide required '%s'.")
			:format(tostring(tcname), tostring(k))
	end

	function err_msgs.NO_INSTANCE(instancename, tcname)
		return ("Failed to instantiate '%s' as '%s':")
			:format(tostring(instancename), tostring(tcname))
	end

	MustImplement = NewBooleanAlgebra(function(funcname)
		return function(self)
			if self[funcname] then
				return true
			else
				return false, {err_msgs.MUSTIMPLEMENT_ERROR(funcname, self.name)}
			end
		end
	end, {
		fold = function(z, msgs)
			if msgs then
				return append_array(z or {}, msgs)
			end
		end,
	})

	return function(...)
		local constraints = {...}
		return curry(function(tname, spec0)
			assert( type(spec0) == "table" )

			local minimal = nil

			local spec = {}
			for k, v in pairs(spec0) do
				if k == "MINIMAL" or k == 1 then
					minimal = v
				else
					spec[k] = v
				end
			end

			-- This requires any instances to define a name.
			spec.name = false

			local TC = {
				name = tname,
				constraints = constraints,
				spec = spec,
				minimal = minimal,
			}

			local instance_set = setmetatable({}, {__mode = "k"})

			local function falsify_instance(self)
				local pairs, ipairs = pairs, ipairs

				local errors = nil

				if instance_set[self] then
					return
				end

				if minimal then
					local status, minerrors = minimal(self)
					if not status then
						assert( minerrors )
						return minerrors
					end
				end

				for _, c in ipairs(TC.constraints) do
					errors = append_array(errors, c.falsify_instance(self))
				end
				for k, default in pairs(spec) do
					if not self[k] then
						if default then
							if type(default) == "table" then
								self[k] = default[1](self)
							else
								self[k] = function(...)
									return default(self, ...)
								end
							end
						else
							if not minimal then
								errors = append_array(errors,
									{err_msgs.MUSTIMPLEMENT_ERROR_FULL(k, self.name, tname)})
							else
								-- This is a logic error on the typeclass
								-- specification, so we raise it now.
								return error(err_msgs.INCOMPLETE_MINIMAL(k, tname), 0)
							end
						end
					end
				end

				if not errors then
					instance_set[self] = true
				end

				return errors
			end
			TC.falsify_instance = falsify_instance

			local function maybe_instance(...)
				local self = merge_tables(...)

				local errors = falsify_instance(self)
				if errors then
					assert( #errors > 0 )
					table.insert(errors, 1, err_msgs.NO_INSTANCE(self.name, tname))
					return false, table.concat(errors, "\n")
				else
					return true, self
				end
			end
			TC.maybe_instance = maybe_instance

			local instance = function(...)
				local status, self = maybe_instance(...)
				if not status then
					return error(self, 2)
				else
					return self
				end
			end
			TC.instance = instance

			setmetatable(TC, new_typeclass_meta(TC))

			return TC
		end)
	end
end)()

---

_M.MustImplement = MustImplement
local _ = MustImplement

---

Functor = TypeClass() "Functor" {
	-- fmap :: (a -> b) -> (f a -> f b)
	fmap = false,
	-- apply :: (f a, b) -> f b
	apply = function(self, fa, b)
		return self.fmap(const(b))(fa)
	end,
	-- curried_apply :: f a -> b -> f b
	curried_apply = function(self, fa)
		local apply = self.apply
		return function(b)
			return apply(fa, b)
		end
	end,
	-- void :: f a -> f ()
	void = {function(self)
		return self.fmap(Nil)
	end},
}
local Functor = Functor

---

Monad = TypeClass(Functor) "Monad" {
	-- pure :: a -> m a
	pure = false,
	-- bind :: (a -> m b) -> m a -> m b
	bind = false,
}
local Monad = Monad

function Monad:curried_bind(f)
	return function(a)
		return self.bind(f, a)
	end
end

-- sequence :: m a -> m b -> m b
function Monad:sequence(ma, mb)
	return self.bind(const(mb), ma)
end

-- join :: m (m a) -> m a
function Monad:join(mma)
	return self.bind(id, mma)
end

---

CoMonad = TypeClass(Functor) "CoMonad" {
	---
	-- MINIMAL: extract, (duplicate | extend)
	--
	MINIMAL = _"extract" * (_"duplicate" + _"extend"),

	-- extract :: w a -> a
	extract = false,

	-- duplicate :: w a -> w (w a)
	duplicate = {function(self)
		return self.extend(id)
	end},
	-- extend :: (w a -> b) -> (w a -> w b)
	extend = function(self, f)
		return compose(self.fmap(f), self.duplicate)
	end,
}

---

Array = Functor.instance {
	name = "Array",
	fmap = function(f)
		return function(A)
			local B = {}
			local j = 0
			for i, v in ipairs(A) do
				v = f(v, i)
				if v ~= nil then
					j = j + 1
					B[j] = v
				end
			end
			return B
		end
	end,
	apply = function(A, x)
		local B = {}
		for i = 1, #A do
			B[i] = x
		end
		return B
	end,
	void = IONil,
}

Table = Functor.instance {
	name = "Table",
	fmap = function(f)
		return function(t)
			local u = {}
			for k, v in pairs(t) do
				u[k] = f(v, k)
			end
			return u
		end
	end,
	apply = function(t, x)
		local u = {}
		for k in pairs(t) do
			u[k] = x
		end
		return u
	end,
	void = IONil,
}

---

Tuple = {
	name = "Tuple",

	fmap = function(f)
		return function(X)
			return { f(unpack(X)) }
		end
	end,

	apply = function(X, ...)
		return {...}
	end,

	void = IONil,

	pure = function(...)
		return {...}
	end,

	bind = function(f, X)
		return f(unpack(X))
	end,

	sequence = function(X, Y)
		return Y
	end,

	extract = unpack,

	duplicate = function(wa)
		return {wa}
	end,

	extend = function(f)
		return function(wa)
			return {f(wa)}
		end
	end,
}

Functor.instance	(Tuple)
Monad.instance		(Tuple)
CoMonad.instance	(Tuple)

---

Unit = {
	name = "Unit",

	fmap = const(Nil),
	apply = Nil,
	void = Nil,
	pure = Nil,
	bind = const(Nil),
	sequence = Nil,

}
local Unit = Unit

Functor.instance	(Unit)
Monad.instance		(Unit)

---

