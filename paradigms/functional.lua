--[[
-- Just a bunch of abstract nonsense.
--]]

--[[
Copyright (C) 2013  simplex

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.
]]--

local assert = assert
local error = error

local math = math

local table = table
local ipairs = ipairs
local pairs = pairs
local select = select
local unpack = unpack

local type = type
local tostring = tostring
local tonumber = tonumber

local getmetatable = getmetatable
local setmetatable = setmetatable
local getfenv = getfenv
local setfenv = setfenv


module(...)
local Lambda = _M

function IsFunctional(x)
	return type(x) == "function" or getmetatable(x) and getmetatable(x).__call
end
local IsFunctional = IsFunctional

function Identity(...)
	return ...
end

function Constant(x)
	return function()
		return x
	end
end

function ConstantList(...)
	local L = {...}
	return function()
		return unpack(L)
	end
end

Nil = Constant()

True = Constant(true)
False = Constant(false)

Zero = Constant(0)
One = Constant(1)
Omega = Constant(math.huge)

EmptyString = Constant("")

-- Something that is different from everything else.
-- The name is a reference to the Alexandroff Compactification construction in Topology.
PointAtInfinity = Constant({})

function IsEqualTo(a)
	return function(x)
		return x == a
	end
end

IsNil = IsEqualTo()


--[[
-- The functions that receive variadic lists will in general work correctly for empty lists.
-- With some of them, counting return values through select('#', ...) may not work, since they
-- may return a proper nil instead of returning nothing. Usual return checks work.
--]]


function Compose(f, g)
	assert( IsFunctional(f) )
	assert( IsFunctional(g) )
	return function(...)
		return f(g(...))
	end
end

function EvaluationMap(...)
	local L = {...}
	return function(f)
		f = f or Identity
		return f( unpack(L) )
	end
end

function IfThenElse(If, Then, Else)
	Then = Then or Nil
	Else = Else or Nil

	return function(...)
		if If(...) then
			return Then(...)
		else
			return Else(...)
		end
	end
end


function Head(x) -- (x, ...)
	return x
end

function Tail(x, ...)
	return ...
end


FirstOf = Head

function SecondOf(x, y)
	return y
end

function ThirdOf(x, y, z)
	return z
end

function LastOf(...)
	local n = select('#', ...)
	if n > 0 then
		return select(n, ...)
	end
end

function Nth(n)
	return function(...)
		return ( select(n, ...) )
	end
end

function NthOf(...)
	return Compose( EvaluationMap(...), Nth )
end

-- Normalizes indexes using the standard Lua convention for negative ones.
function NormalizeIndexes(i, j, n)
	i = i or 1

	if n then
		j = j or n
		if i < 0 then
			i = n + i + 1
		end
		if j < 0 then
			j = n + j + 1
		end
		j = math.min(j, n)
	end

	return i, j
end

function ShiftLeft(x, ...)
	return ...
end

function ShiftRotateLeft(x, ...)
	local t = {...}
	table.insert(t, x)
	return unpack(t)
end

Append = ShiftRotateLeft

function RemoveLastOf(...)
	local t = {...}
	table.remove(t)
	return unpack(t)
end

function ShiftRotateRight(...)
	local t = {...}
	local last = table.remove(t)
	return last, unpack(t)
end

function ShiftRight(...)
	return nil, ...
end

function FlipFirstTwo(a, b, ...)
	return b, a, ...
end

-- i and j are the positions to be flipped.
function Flip(i, j, ...)
	local t = {...}
	i, j = NormalizeIndexes(i, j, #t)
	t[i], t[j] = t[j], t[i]
	return unpack(t)
end

Transpose = Flip


local function BindHead(f, x)
	return function(...)
		return f(x, ...)
	end
end
_M.BindHead = BindHead

local function BindTail(f, ...)
	local Args = {...}
	return function(x)
		return f(x, unpack(Args))
	end
end
_M.BindTail = BindTail


BindFirst = BindHead

function BindSecond(f, y)
	return function(f, x, ...)
		return f(x, y, ...)
	end
end

function BindThird(f, z)
	return function(f, x, y, ...)
		return f(x, y, z, ...)
	end
end

function BindLast(f, x)
	return function(...)
		return f(Append(x, ...))
	end
end


local function Curry(f, n)
	if n <= 0 then return f end
	return function(x)
		return Curry( BindHead(f, x), n - 1 )
	end
end
_M.Curry = Curry

function Uncurry(f)
	return function(...)
		local g = f
		for _, x in ipairs{...} do
			g = g(x)
		end
		return g
	end
end


function Add(a, b)
	return (a or 0) + (b or 0)
end

function Multiply(a, b)
	return (a or 1) * (b or 1)
end

function NegateSign(a)
	return -a
end

UnaryMinus = NegateSign

function Invert(g)
	return 1/g
end


--[[
-- Table abstractions.
--]]

function Getter(t)
	return function(k)
		if k ~= nil then
			return t[k]
		end
	end
end

function Setter(t)
	return function(k, v)
		if k ~= nil then
			t[k] = v
			return v
		end
	end
end

function StackPusher(s)
	return function(v)
		if v ~= nil then
			table.insert(s, v)
			return v
		end
	end
end

StackInserter = StackPusher

function StackPopper(s)
	return function()
		return table.remove(s)
	end
end

StackRemover = StackPopper
StackEraser = StackPopper

function StackGetter(s)
	return function()
		return s[#s]
	end
end

QueuePusher = StackPusher
QueueInserter = QueuePusher

function QueueRemover(q)
	return function()
		return table.remove(q, 1)
	end
end

QueuePopper = QueueRemover
QueueEraser = QueueRemover

function QueueGetter(q)
	return function()
		return q[1]
	end
end


--[[
-- Iterator tools.
--]]
iterator = {}
Iterator = iterator
local Iterator = iterator

-- Builds an independent updater of iterator state, represented
-- by a table with at least the field var (the control variable value).
function Iterator.NewStateManager(state, var0)
	state.var = var0
	return function(var, ...)
		if var == nil then
			state.var = var0
			return
		else
			state.var = var
			return var, ...
		end
	end
end

function Iterator.GetStateManaged(f, s, var)
	local state = {}
	return Lambda.Compose( Iterator.NewStateManager(state, var), function(s)
		return f(s, state.var)
	end ), s, var
end

function Iterator.RawCompose(g, f, s, var)
	return Lambda.Compose(g, f), s, var
end

-- Do not compose with a function that may return nil if its first argument is not nil.
-- If doing so, the iterator can't be reused (because it will not reset).
function Iterator.Compose(g, f, s, var)
	return Iterator.RawCompose( g, Iterator.GetStateManaged(f, s, var) )
end

for _, pre in ipairs {'Raw', ''} do
	local primitive = assert( Iterator[pre .. 'Compose'] )
	Iterator[pre .. 'ComposeTo'] = function(g)
		return Lambda.BindHead( primitive, g )
	end
end

function Iterator.Filter(p, f, s, var)
	local function g(s, var)
		local rets = {f(s, var)}
		if rets[1] == nil then return end
		if p(unpack(rets)) then
			return unpack(rets)
		else
			-- Tail call
			return g(s, rets[1])
		end
	end

	return g, s, var
end

-- Appends the second to the first.
-- Semantically, it's like concatenation.
function Iterator.Append(f, s_f, var_f, g, s_g, var_g)
	local s = {s_f, s_g}

	-- Current state transition function.
	local current_trans_func

	local f_wrap
	local g_wrap

	local function f_control_shifter(s, var, ...)
		if var == nil then
			current_trans_func = g_wrap
			return g_wrap(s, var_g)
		else
			return var, ...
		end
	end

	local function g_control_shifter(var, ...)
		if var == nil then
			current_trans_func = f_wrap
			return
		else
			return var, ...
		end
	end

	f_wrap = function(s, var)
		return f_control_shifter( s, f(s[1], var) )
	end

	g_wrap = function(s, var)
		return g_control_shifter( g(s[2], var) )
	end

	current_trans_func = f_wrap

	return function(s, var)
		return current_trans_func(s, var)
	end, s, var_f
end

function Iterator.AppendTo(f, s, var)
	return function(g, s_g, var_g)
		return Iterator.Append(f, s, var, g, s_g, var_g)
	end
end

function Iterator.AppendFromGenerators(F, G)
	return function(...)
		local f, s_f, var_f = F(...)
		local g, s_g, var_g = G(...)

		return Iterator.Append(f, s_f, var_f, g, s_g, var_g)
	end
end

function Iterator.NestedAppend(ftable, gtable)
	local f, s_f, var_f = unpack(ftable)
	local g, s_g, var_g = unpack(gtable)

	return Iterator.Append(f, s_f, var_f, g, s_g, var_g)
end

-- Returns an empty iterator when called.
Iterator.Empty = Lambda.Constant( Lambda.Nil )

-- Nil produces an empty iterator.
function Iterator.Singleton(x)
	return function(s, var)
		if var == nil then
			return s
		end
	end, x
end

function Iterator.SingletonList(...)
	return function(s, var)
		if var == nil then
			return unpack(s)
		end
	end, {...}
end

-- Closed range.
-- Uses Lua conventions for negative numbers if a max is given.
function Iterator.PositiveIntegralRange(a, b, max)
	a, b = NormalizeIndexes(a, b, max)

	return function(b, var)
		var = var + 1
		if var <= b then
			return var
		end
	end, b, a - 1
end

function Iterator.ArraySlice(A, i, j)
	return Iterator.RawCompose( function(k) return k, A[k] end, Iterator.PositiveIntegralRange(i, j, #A) )
end

-- Removes an iterator's dependency on the `var' control variable.
-- This makes it a forward only iterator.
Iterator.RemoveFirstDependency = Iterator.GetStateManaged

-- Prevents the iterator from returning the first element in its return list (the `var' control variable).
Iterator.ShiftLeft = Iterator.ComposeTo(Lambda.ShiftLeft)

-- Swaps the first two elements of the return list of an iterator.
-- If such a list has less than two elements, nothing is done.
function Iterator.FlipFirstTwo(f, s, var)
	local ret0 = {f(s, var)}
	var = ret0[1]

	if var == nil then return Iterator.Empty() end

	if #ret0 == 1 then
		local g, s_g, var_g = Iterator.Singleton(var)
		return Iterator.Append( g, s_g, var_g, f, s, var )
	end

	local g, s_g, var_g = Iterator.SingletonList( Lambda.FlipFirstTwo(unpack(ret0)) )

	local h, s_h, var_h = Iterator.Compose( Lambda.FlipFirstTwo, f, s, var )

	return Iterator.Append( g, s_g, var_g, h, s_h, var_h )
end


--[[
-- Search and transformation.
-- Iterators are assumed to return 1 or 2 elements in the non-list versions.
--
-- If returning two, they are assumed to work like Lua's ipairs and pairs,
-- where the actual value is the second, and the first has less importance.
-- So they are flipped, for general convenience.
--
-- The list versions preserve everything (at the added overhead of creating
-- temporary tables to store the lists).
--]]

function GenerateConceptsFromIteration(IteratorGenerator, ret)
	ret = ret or {}

	assert( IsFunctional(IteratorGenerator) )

	if not ret.Find then
		local function Find(p, ...)
			for v, k in Iterator.FlipFirstTwo( IteratorGenerator(...) ) do
				if p(v, k) then
					return v, k
				end
			end
		end
		ret.Find = Find

		ret = GenerateConceptsFromSearching(Find, ret)
	end

	if not ret.ListFind then
		local function ListFind(p, ...)
			local f, s, var = IteratorGenerator(...)

			local E = Lambda.EvaluationMap( f(s, var) )

			while not E(IsNil) do
				if E(p) then
					return E()
				end
				E = Lambda.EvaluationMap( f(s, E(Lambda.FirstOf)) )
			end
		end
		ret.ListFind = ListFind

		assert( Lambda.IsFunctional(MapIntoIf) )

		MapIntoIf(
			function(v, k) return ret['List' .. k] == nil end,
			function(v, k) return v, ('List' .. k) end,
			ret,
			pairs( GenerateConceptsFromSearching(ListFind) )
		)
	end

	return ret
end

--[[
-- Generates derivative concepts from searching into ret.
-- We require only that the searching function takes the predicate as its
-- first argument.
--]]
function GenerateConceptsFromSearching(Find, ret)
	ret = ret or {}

	assert( IsFunctional(Find) )

	if not ret.Apply then
		local function Apply(f, ...)
			return Find(Compose(False, f), ...)
		end
		ret.Apply = Apply

		ret = GenerateConceptsFromApplying(Apply, ret)
	end

	return ret
end

---[[
-- Generates derivative concepts from applying into ret.
-- We require only that the apply function takes the map as its
-- first argument.
--]]
function GenerateConceptsFromApplying(Apply, ret)
	ret = ret or {}

	assert( IsFunctional(Apply) )

	local function ApplyIf(p, f, ...)
		return Apply(function(...)
			if p(...) then
				f(...)
			end
		end, ...)
	end
	ret.ApplyIf = ApplyIf

	local function MapInto(map, t, ...)
		local push = Lambda.StackPusher(t)
		Apply(function(v, k)
			if k ~= nil then
				local oldk = k
				v, k = map(v, k)
				t[k or oldk] = v
			else
				push(map(v))
			end
		end, ...)
		return t
	end
	ret.MapInto = MapInto

	local function CompactlyMapInto(map, t, ...)
		Apply( Lambda.Compose(Lambda.StackPusher(t), map), ...)
		return t
	end
	ret.CompactlyMapInto = CompactlyMapInto


	for _, output_mode in ipairs {'', 'Compactly'} do
		local regular_mapper_id = output_mode .. 'Map'
		local into_mapper_id = regular_mapper_id .. 'Into'

		local into_mapper = ret[into_mapper_id]
		assert( Lambda.IsFunctional(into_mapper) )

		local function regular_mapper(map, ...)
			return into_mapper(map, {}, ...)
		end
		ret[regular_mapper_id] = regular_mapper


		for _, output_pointer in ipairs {'Into', ''} do
			local mapper_id = regular_mapper_id .. output_pointer
			local conditional_mapper_id = mapper_id .. 'If'
			
			local mapper = ret[mapper_id]
			assert( Lambda.IsFunctional(mapper) )

			local function conditional_mapper(p, map, ...)
				return mapper(function(v, k)
					if p(v, k) then
						return map(v, k)
					end
				end, ...)
			end
			ret[conditional_mapper_id] = conditional_mapper

			local filter_id = output_mode .. 'Filter' .. output_pointer

			local function filter(p, ...)
				return conditional_mapper(p, Lambda.Identity, ...)
			end
			ret[filter_id] = filter
		end


		local into_filter_id = output_mode .. 'FilterInto'

		local into_filter = ret[into_filter_id]
		assert( Lambda.IsFunctional(into_filter) )

		ret[output_mode .. 'InjectIntoIf'] = into_filter
		ret[output_mode .. 'InjectInto'] = Lambda.BindHead( into_filter, Lambda.True )
	end
	local Map = ret.Map
	local CompactlyMap = ret.CompactlyMap

	
	local function Fold(folder, ...)
		local total = nil
		Apply(function(v)
			total = folder(v, total)
		end, ...)
		return total
	end
	local function FoldIf(p, folder, ...)
		return Fold(function(v, total)
			if p(v, total) then
				return folder(v, total)
			else
				return total
			end
		end, ...)
	end
	ret.Fold = Fold
	ret.FoldIf = FoldIf


	return ret
end


GenerateConceptsFromIteration(Identity, _M)


function ConceptualizeSingletonObject(object, ret)
	ret = ret or {}

	local meta = getmetatable(ret)
	if not meta then
		meta = {}
		setmetatable(ret, meta)
	end
	
	local oldindex = meta.__index

	-- Bad name, I know. This refers to the new __index metamethod.
	local newindex = function(t, k)
		if type(k) == "string" then
			local v = object[k]
			if Lambda.IsFunctional(v) then
				-- local w = v

				v = function(...)
					return object[k](object, ...)
				end

				t[k] = v

				--[[

				-- This is just to ensure smooth behaviour with the module loading functions
				-- that deal with environments. It isn't really needed. But it doesn't hurt,
				-- since for each key `k' we run this at most once (unless the entry is erased).

				while type(w) ~= "function" do
					w = getmetatable(w).__call
					assert( Lambda.IsFunctional(w) )
				end

				setfenv(v, getfenv(w))

				]]--
			end
			return v
		end
	end
	
	if oldindex then
		if type(oldindex) ~= "function" then
			local old_oldindex = oldindex
			oldindex = function(_, k)
					return old_oldindex[k]
			end
		end
		meta.__index = function(t, k)
			local v = newindex(t, k)
			if v ~= nil then
				return v
			else
				return oldindex(t, k)
			end
		end
	else
		meta.__index = newindex
	end

	return ret
end


function Error(...)
	local Args = {...}
	return function()
		return error( table.concat( CompactlyMap(tostring, ipairs(Args)) ), 2 )
	end
end

function Assert(p, ...)
	assert( Lambda.IsFunctional(p), "The assertion predicate should be functional." )
	local Args = {...}
	return function(...)
		local b = p(...)
		return assert( b, b or table.concat( CompactlyMap(tostring, ipairs(Args)) ) )
	end
end


-- Receives an iterator over functions.
-- Its return values will be flipped, according to the general convention adopted here.
function FunctionList(f, s, var)
	return function(...)
		Apply( EvaluationMap(...), f, s, var )
	end
end

-- The term fiber is used in its set theoretic sense.
-- Valid for iterators with a return value list of length 2.
function IteratorFiber(f, s, var)
	local fiber = {}

	for x, y in f, s, var do
		if y ~= nil then
			if fiber[y] then
				table.insert( fiber[y], x )
			else
				fiber[y] = {x}
			end
		end
	end

	return fiber
end

ArrayFiber = Compose( IteratorFiber, Iterator.ArraySlice )

function TableFiber(f, i, j)
	if i or j then
		return ArrayFiber(f, i, j)
	else
		return IteratorFiber( pairs(f) )
	end
end	


return _M
