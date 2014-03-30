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


local Lambda = wickerrequire 'paradigms.functional'

require 'entityscript'


BindWickerModule 'lib.logic'


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
IsNil = Lambda.IsNil


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
	return type(x) == "table" and type(x.is_a) == "function"
end

function IsInstanceOf(C)
	local getmetatable = getmetatable

	local cache = {}

	return function(x)
		local m = getmetatable(x)
		if m == nil then return false end

		local cached_res = cache[m]
		if cached_res == nil then
			cached_res = (IsObject(x) and x:is_a(C)) and true or false
			cache[m] = cached_res
		end

		return cached_res
	end
end

IsObjectOf = IsInstanceOf

function IsClassOf(x)
	if IsObject(x) then
		local cache = {}

		return function(C)
			if C == nil then return false end

			local cached_res = cache[C]
			if cached_res == nil then
				cached_res = x:is_a(C) and true or false
				cache[C] = cached_res
			end
			
			return cached_res
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


IsCallable = Lambda.IsFunctional
IsFunctional = Lambda.IsFunctional

IsStringable = LambdaOr( IsString, HasMetaMethod("tostring") )
IsWordable = IsStringable

IsIndexable = LambdaOr( IsTable, HasMetaMethod("index") )
IsNewIndexable = LambdaOr( IsTable, HasMetaMethod("newindex") )


-------------------------------------------------------------


IsWorldGen = assert( IsWorldGen )
AtWorldGen = IsWorldGen

IsVector3 = IsInstanceOf(Vector3)
IsPoint = IsInstanceOf(Point)
IsEntityScript = IsInstanceOf(EntityScript)

function IsValid(inst)
	return inst:IsValid()
end

function IsOk(inst)
	return inst:IsValid() and not inst:IsInLimbo()
end

IsValidEntity = LambdaAnd( IsEntityScript, IsValid )
IsOkEntity = LambdaAnd( IsEntityScript, IsOk )

if not IsWorldgen() then
	PrefabExists = _G.PrefabExists
end

function IsPrefab(prefab)
	return function(inst)
		return inst.prefab == prefab
	end
end

function IsPrefabEntity(prefab)
	return LambdaAnd( IsEntityScript, IsPrefab(prefab) )
end


AddSelfPostInit(function()
	wickerrequire "game.gamepredicates"
end)
