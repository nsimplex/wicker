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



--@@ENVIRONMENT BOOTUP
local _modname = assert( (assert(..., 'This file should be loaded through require.')):match('^[%a_][%w_%s]*') , 'Invalid path.' )
module( ..., require(_modname .. '.booter') )
--@@END ENVIRONMENT BOOTUP


BindWickerModule 'paradigms.logic'


require 'entityscript'


IsWorldgen = assert( IsWorldgen )
IsWorldGen = assert( IsWorldGen )

function Less(a, b)
	return a < b
end

function LessOrEqual(a, b)
	return a <= b
end

Greater = LambdaNot(LessOrEqual)

GreaterOrEqual = LambdaNot(Less)

function IsType(t)
	return function(x)
		return type(x) == t
	end
end

IsFunction = IsType "function"
IsNumber = IsType "number"
IsBoolean = IsType "boolean"
IsString = IsType "string"
IsTable = IsType "table"
IsNil = IsType "nil"

function IsPrivate(x)
	return x:match('^_')
end

IsPublic = LambdaNot(IsPrivate)

for _, access in ipairs {'Private', 'Public'} do
	_M['Is' .. access .. 'String'] = LambdaAnd( IsString, _M['Is' .. access] )
end

function IsPositive(x)
	return x > 0
end

function IsNegative(x)
	return x < 0
end

IsNonNegative = LambdaNot(IsNegative)
IsNonPositive = LambdaNot(IsPositive)

function IsInteger(n) return IsNumber(n) and n == math.floor(n) end

for _,v in ipairs {"Positive", "Negative", "NonNegative", "NonPositive"} do
	_M["Is" .. v .. "Number"] = LambdaAnd(IsNumber, _M["Is" .. v])
	_M["Is" .. v .. "Integer"] = LambdaAnd(IsInteger, _M["Is" .. v])
end

function IsInClosedRange(a, b)
	return function(x)
		return a <= x and x <= b
	end
end

IsProbability = LambdaAnd( IsNumber, IsInClosedRange(0, 1) )

function IsObject(x)
	return type(x) == "table" and getmetatable(x) and x.is_a
end

function IsInstanceOf(C)
	return function(x)
		return IsObject(x) and x:is_a(C)
	end
end

IsObjectOf = IsInstanceOf

function IsClassOf(x)
	if IsObject(x) then
		return function(C)
			return x:is_a(C)
		end
	else
		return IsEqualTo(type(x))
	end
end

IsTypeOf = IsClassOf

function HasMetaMethod(method)
	local mname = '__' .. method
	return function(x)
		local m = getmetatable(x)
		return m and m[mname]
	end
end

IsCallable = LambdaOr( IsFunction, HasMetaMethod("call") )

IsStringable = LambdaOr( IsString, HasMetaMethod("tostring") )
IsWordable = IsStringable

IsIndexable = LambdaOr( IsTable, HasMetaMethod("index") )
IsNewIndexable = LambdaOr( IsTable, HasMetaMethod("newindex") )


IsEntityScript = IsInstanceOf(EntityScript)

IsVector3 = IsInstanceOf(Vector3)
IsPoint = IsInstanceOf(Point)

function IsValidPoint(pt)
	local tile = GetGroundTypeAtPosition(pt)
	return not ( tile == GROUND.IMPASSABLE or tile >= GROUND.UNDERGROUND )
end

function IsOk(inst)
	return inst:IsValid() and not inst:IsInLimbo()
end

IsOkEntity = LambdaAnd( IsEntityScript, IsOk )

if not IsWorldgen() then
	PrefabExists = _G.PrefabExists
end

return _M
