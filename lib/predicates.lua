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

local _M = _M

---

AddCheckersProvider(function(testname)
    return _M["Is"..testname]
end)


for _, k in ipairs{
		"Less", "Greater",
		"LessThan", "GreaterThan",
		"LessOrEqual", "GreaterOrEqual",
		"LessOrEqualTo", "GreaterOrEqualTo",
	} do
	_M[k] = Lambda[k]
	_M["Is"..k] = Lambda["Is"..k]
end


local is_type_cache = {
	["nil"] = Lambda.IsNil,
}
local function is_type(ty)
	local ret = is_type_cache[ty]
	if ret == nil then
		ret = function(x)
			return type(x) == ty
		end
		is_type_cache[ty] = ret
	end
	return ret
end

IsFunction = is_type "function"
IsNumber = is_type "number"
IsBoolean = is_type "boolean"
IsString = is_type "string"
IsTable = is_type "table"
IsNil = Lambda.IsNil

function IsType(ty)
	return is_type_cache[ty] or Lambda.False
end

IsPublicString = assert( IsPublicString )
IsPrivateString = assert( IsPrivateString )

function IsPositive(x)
	return x > 0
end

function IsNegative(x)
	return x < 0
end

IsNonNegative = Lambda.Not(IsNegative)
IsNonPositive = Lambda.Not(IsPositive)

function IsInteger(n) return IsNumber(n) and n%1 == 0 end

for _,v in ipairs {"Positive", "Negative", "NonNegative", "NonPositive"} do
	_M["Is" .. v .. "Number"] = Lambda.And(IsNumber, _M["Is" .. v])
	_M["Is" .. v .. "Integer"] = Lambda.And(IsInteger, _M["Is" .. v])
end

function IsInClosedRange(a, b)
	return function(x)
		return a <= x and x <= b
	end
end

IsProbability = Lambda.And( IsNumber, IsInClosedRange(0, 1) )

-- Returns the metamethod if it exists.
HasMetaMethod = assert( metatable.getmetamethod )

IsCallable = Lambda.IsFunctional
IsFunctional = Lambda.IsFunctional

IsStringable = Lambda.Or( IsString, HasMetaMethod("tostring") )
IsWordable = IsStringable

IsIndexable = Lambda.Or( IsTable, HasMetaMethod("index") )
IsNewIndexable = Lambda.Or( IsTable, HasMetaMethod("newindex") )




IsCallableTable = Lambda.And(IsTable, HasMetaMethod("call"))

function IsArrayOf(p)
	return Lambda.And(IsTable, Lambda.Compose(Lambda.BindFirst(ForAll, p), ipairs))
end

function IsObject(x)
	return type(x) == "table" and type(x.is_a) == "function"
end

function IsClass(x)
	return IsCallableTable(x) and type(rawget(x, "_ctor")) == "function"
end

IsInstanceOf = (function()
	local getmetatable = getmetatable

	local cache = setmetatable({}, {__mode = "k"})

	return function(C)
		local is_instance_of_C = cache[C]
		if is_instance_of_C == nil then
			local is_superclass_of = setmetatable({}, {__mode = "k"})

			is_instance_of_C = function(x)
				local m = getmetatable(x)
				if m == nil then return false end

				local is_superclass_of_x = is_superclass_of[m]
				if is_superclass_of_x == nil then
					is_superclass_of_x = (IsObject(x) and x:is_a(C)) and true or false
					is_superclass_of[m] = is_superclass_of_x
				end

				return is_superclass_of_x
			end

			cache[C] = is_instance_of_C
		end
		return is_instance_of_C
	end
end)()

IsObjectOf = IsInstanceOf

function IsClassOf(x)
	if IsObject(x) then
		local cache = setmetatable({}, {__mode = "k"})

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

IsValidEntity = Lambda.And( IsEntityScript, IsValid )
IsOkEntity = Lambda.And( IsEntityScript, IsOk )

if not IsWorldgen() then
	PrefabExists = _G.PrefabExists
else
	PrefabExists = Lambda.True
end

function IsPrefab(prefab)
	local cache = {}
	local is_prefab = cache[prefab]
	if is_prefab == nil then
		is_prefab = function(inst)
			return inst.prefab == prefab
		end
		cache[prefab] = is_prefab
	end
	return is_prefab
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
	return Lambda.And( IsEntityScript, IsPrefab(prefab) )
end

function IsEntityWithTag(tag)
	return Lambda.And( IsEntityScript, HasTag(tag) )
end

function IsEntityWithTags(tags)
	return Lambda.And( IsEntityScript, HasTags(tags) )
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
