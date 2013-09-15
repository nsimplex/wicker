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

--@@WICKER ENVIRONMENT BOOTUP
local _modname = assert( (assert(..., 'This file should be loaded through require.')):match('^[%a_][%w_%s]*') , 'Invalid path.' )
module( ..., require(_modname .. '.wicker.booter') )
--@@END ENVIRONMENT BOOTUP


local Lambda = wickerrequire 'paradigms.functional'

Connectives = {
--	{name = 'True', arity = 0},
--	{name = 'False', arity = 0},
	{name = 'Not', arity = 1},
	{name = 'Or', arity = 2},
	{name = 'And', arity = 2},
	{name = 'Implies', arity = 2},
	{name = 'IfAndOnlyIf', arity = 2},
}

function ToBoolean(x)
	return x and true or false
end
ToBool = ToBoolean

--[[
-- Propositional calculus on atoms (booleans).
--]]

True = Lambda.True
False = Lambda.False

function Not(p)
	return not p
end

function Or(p, q)
	return p or q
end

function And(p, q)
	return p and q
end

function Implies(p, q)
	return not p or q
end

function IfAndOnlyIf(p, q)
	return Implies(p, q) and Implies(q, p)
end

function AreEqual(a, b)
	return a == b
end

IsEqualTo = Lambda.IsEqualTo

--[[
-- Propositional calculus on predicates (functions).
--]]

LambdaTrue = Lambda.Constant(True)
LambdaFalse = Lambda.Constant(False)

function LambdaNot(p)
	return function(...)
		return not p(...)
	end
end

function LambdaBinaryAnd(p, q)
	return function(...)
		return p(...) and q(...)
	end
end

function LambdaBinaryOr(p, q)
	return function(...)
		return p(...) or q(...)
	end
end

function LambdaImplies(p, q)
	return LambdaBinaryOr( LambdaNot(p), q )
end

function LambdaIfAndOnlyIf(p, q)
	return function(...)
		local pv, qv = p(...), q(...)
		return IfAndOnlyIf(pv, qv)
	end
end

SatisfiedBy = Lambda.EvaluationMap

--[[
-- First-order logic on predicates and advanced constructions.
--]]

function ThereExists(p, f, s, var)
	return Lambda.Find(p, f, s, var) ~= nil
end

function ForAll(p, f, s, var)
	return not ThereExists(LambdaNot(p), f, s, var)
end

function LambdaAssociativeOr(...)
	local Predicates = {...}

	return function(...)
		return ThereExists( SatisfiedBy(...), ipairs(Predicates) )
	end
end

function LambdaAssociativeAnd(...)
	local Predicates = {...}

	return function(...)
		return ForAll( SatisfiedBy(...), ipairs(Predicates) )
	end
end

-- For efficiency, we branch out.
function LambdaOr(...)
	if select('#', ...) == 2 then
		return LambdaBinaryOr(...)
	else
		return LambdaAssociativeOr(...)
	end
end

function LambdaAnd(p, q, ...)
	local n = select('#', ...)

	if p and q and n == 0 then
		return LambdaBinaryAnd(p, q)
	else
		return LambdaAssociativeAnd(p, q, ...)
	end
end



for _, op in ipairs(Connectives) do
	if not Lambda[op.name] then
		Lambda[op.name] = assert( _M['Lambda' .. op.name] )
	end
end

return _M
