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

local assert = assert
local error = error
local type = type
local pairs = pairs
local ipairs = ipairs
local rawget = rawget
local getmetatable = getmetatable


BindWickerModule 'lib.logic'


for _, k in ipairs{
		"Less", "Greater",
		"LessThan", "GreaterThan",
		"LessOrEqual", "GreaterOrEqual",
		"LessOrEqualTo", "GreaterOrEqualTo",
	} do
	_M[k] = Lambda[k]
	_M["Is"..k] = Lambda["Is"..k]
end


local is_type_cache = {}
local function is_type(t)
	local ret = function(x)
		return type(x) == t
	end
	is_type_cache[t] = ret
	return ret
end

IsFunction = is_type "function"
IsNumber = is_type "number"
IsBoolean = is_type "boolean"
IsString = is_type "string"
IsTable = is_type "table"
IsNil = Lambda.IsNil

is_type_cache["nil"] = Lambda.IsNil

function IsType(t)
	return is_type_cache[t]
end


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

function IsInteger(n) return IsNumber(n) and n%1 == 0 end

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

-- Returns the metamethod if it exists.
function HasMetaMethod(method)
	local mname = "__"..method
	return function(x)
		local m = getmetatable(x)
		return m and rawget(m, mname)
	end
end

IsCallableTable = LambdaAnd(IsTable, HasMetaMethod("call"))

function IsArrayOf(p)
	return LambdaAnd(IsTable, Lambda.Compose(Lambda.BindFirst(ForAll, p), ipairs))
end

function IsObject(x)
	return type(x) == "table" and type(x.is_a) == "function"
end

function IsClass(x)
	return IsCallableTable(x) and type(rawget(x, "_ctor")) == "function"
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


IsCallable = Lambda.IsFunctional
IsFunctional = Lambda.IsFunctional

IsStringable = LambdaOr( IsString, HasMetaMethod("tostring") )
IsWordable = IsStringable

IsIndexable = LambdaOr( IsTable, HasMetaMethod("index") )
IsNewIndexable = LambdaOr( IsTable, HasMetaMethod("newindex") )


-------------------------------------------------------------


IsVector3 = IsInstanceOf(Vector3)
IsPoint = IsInstanceOf(Point)

if not IsWorldgen() then
	require "entityscript"
	EntityScript = _G.EntityScript
end

if IsWorldgen() or not EntityScript then
	IsEntityScript = Lambda.False
else
	IsEntityScript = IsInstanceOf(EntityScript)
end

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

function HasTag(tag)
	return function(inst)
		return inst:HasTag(tag)
	end
end

function HasTags(tags)
	return function(inst)
		for _, tag in ipairs(tags) do
			if not inst:HasTag(tag) then
				return false
			end
		end
		return true
	end
end

function IsPrefabEntity(prefab)
	return LambdaAnd( IsEntityScript, IsPrefab(prefab) )
end

function IsEntityWithTag(tag)
	return LambdaAnd( IsEntityScript, HasTag(tag) )
end

function IsEntityWithTags(tags)
	return LambdaAnd( IsEntityScript, HasTags(tags) )
end


function ToPredicate(p)
	if p == nil then
		return Lambda.True
	end
	if type(p) == "string" then
		return IsPrefab(p)
	end
	assert( IsCallable(p), "Predicate expected" )
	return p
end


AddSelfPostInit(function()
	wickerrequire "game.gamepredicates"
end)
