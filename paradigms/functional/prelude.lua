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

	function err_msgs.INCOMPLETE_MINIMAL(tcname)
		return ("Minimal implementation of typeclass '%s' does not provide all required methods.")
			:format(tostring(tcname))
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

	local function arglist_tostring(...)
		local args = {...}
		local n = select("#", ...)
		for i = 1, n do
			args[i] = tostring(args[i])
		end
		return table.concat(args, ", ")
	end

	local function generic_check_spec(masterself, slaveself, spec, iname, tname, itergen)
		-- print("generic_check_spec("..arglist_tostring(masterself, slaveself, spec, iname, tname, itergen)..")")

		itergen = itergen or publicpairs

		local errors = nil

		for k, default in itergen(spec) do
			if not slaveself[k] then
				if default then
					if not errors then
						if type(default) == "table" then
							slaveself[k] = default[1](masterself)
						else
							slaveself[k] = function(...)
								return default(masterself, ...)
							end
						end
					end
				else
					errors = append_array(errors,
						{err_msgs.MUSTIMPLEMENT_ERROR_FULL(k, iname, tname)})
				end
			end
		end

		return errors
	end

	local function check_spec(self, ...)
		return generic_check_spec(self, self, ...)
	end

	local metaitergen = matchedpairs "^__"

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

			local function extend_metatable(self)
				local metaspec = spec.__meta
				if not metaspec then return end

				local meta = require_metatable(self)

				local mname = "getmetatable("..tostring(self.name)..")"

				return generic_check_spec(self, meta, metaspec, mname, tname, metaitergen)
			end

			local instance_set = setmetatable({}, {__mode = "k"})

			local function falsify_instance(self)
				local pairs, ipairs = pairs, ipairs

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
					local errors = c.falsify_instance(self)
					if errors then
						return errors
					end
				end

				local errors

				errors = check_spec(self, spec, self.name, tname)
				if errors then
					if minimal then
						local err = err_msgs.INCOMPLETE_MINIMAL(tname)
						err = table.concat(append_array({err}, errors), "\n")
						-- This is a logic error on the typeclass
						-- specification, so we raise it now.
						return error(err, 0)
					end
					return errors
				end

				errors = extend_metatable(self)
				if errors then
					return errors
				end

				assert(not errors)
				instance_set[self] = true

				return nil
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
	---
	-- MINIMAL: fmap | varfmap
	--
	MINIMAL = _"fmap" + _"varfmap",


	-- fmap :: (a -> b) -> (f a -> f b)
	fmap = {function(self)
		return self.varfmap
	end},
	-- Version of fmap for variadic functions.
	-- varfmap :: ((a, ...) -> b) -> (f a, ...) -> f b
	varfmap = function(self, f)
		local fmap = self.fmap
		return function(fa, ...)
			local extra = {...}
			local function g(a)
				return f(a, unpack(extra))
			end
			return fmap(g)(fa)
		end
	end,


	__meta = {
		__pow = function(self, f)
			return self.fmap(f)
		end,
	},


	-- apply :: (f a, b) -> f b
	apply = function(self, fa, ...)
		return self.fmap(const(...))(fa)
	end,
	-- curried_apply :: f a -> b -> f b
	curried_apply = function(self, fa)
		local apply = self.apply
		return function(...)
			return apply(fa, ...)
		end
	end,
	-- void :: f a -> f ()
	void = {function(self)
		return self.fmap(Nil)
	end},
}
local Functor = Functor

---

Monoid = TypeClass() "Monoid" {
	-- mempty :: a
	mempty = false,
	-- mappend :: (a, a) -> a
	mappend = false,

	__concat = {function(self)
		return self.mappend
	end},
}

---

Monad = TypeClass(Functor) "Monad" {
	-- pure :: a -> m a
	pure = false,
	-- bind :: ((a -> m b), m a) -> m b
	bind = false,
}
local Monad = Monad

function Monad:curried_bind(f)
	return function(a)
		return self.bind(f, a)
	end
end

-- sequence :: (m a, m b) -> m b
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
	varfmap = function(f)
		return function(A, ...)
			local B = {}
			local j = 0
			for i, v in ipairs(A) do
				v = f(v, ...)
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
	varfmap = function(f)
		return function(t, ...)
			local u = {}
			for k, v in pairs(t) do
				u[k] = f(v, ...)
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
	varfmap = function(f)
		return function(X, ...)
			local Y = {}
			local nX = #X
			local extra = {...}
			local nextra = #extra

			for i = 1, nX do
				Y[i] = X[i]
			end
			for i = 1, nextra do
				Y[nX + i] = extra[i]
			end

			return f(unpack(Y))
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

-- |
-- The type 'Hom a' corresponds to all functions of the form '(...) -> a',
-- that is, all variadic functions with values in a.
local Hom = {
    name = "Hom",

    fmap = curry(compose)
    void = bind(compose, Nil)
}

Hom.pure = const
Hom.bind = compose
Hom.sequence = function(ma, mb)
    return function(...)
        ma(...)
        return mb(...)
    end
end

Hom.mempty = Nil
Hom.mappend = Hom.sequence

Functor.instance    (Hom)
Monad.instance      (Hom)
Monoid.instance     (Hom)

---

-- |
-- We identify 'IO a' with 'Hom a', viewing it as the type of variadic Lua
-- functions possibly having some side effect and having values in 'a'.
IO = Hom
