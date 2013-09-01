--[[
-- Defines the concept of a component prototype.
-- A component prototype is a class whose objects are component classes.
--
-- The constructor of the instantiated classes should be a field called "new".
--
-- All instantiated component classes inherit from BasicComponent below.
-- Actual inheritance should be done at the prototype level.
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

--@@ENVIRONMENT BOOTUP
local _modname = assert( (assert(..., 'This file should be loaded through require.')):match('^[%a_][%w_%s]*') , 'Invalid path.' )
module( ..., require(_modname .. '.booter') )

--@@END ENVIRONMENT BOOTUP


local Lambda = wickerrequire 'paradigms.functional'
local Logic = wickerrequire 'paradigms.logic'

local Pred = wickerrequire 'lib.predicates'

local Debuggable = wickerrequire 'gadgets.debuggable'

local myutils = wickerrequire 'utils'


--[[
-- Base class for instantiated components.
--]]


-- Normalizes into a table with entries "short" and "full".
local function NormalizeName(name)
	local t = {}
	if Pred.IsWordable(name) then
		t.short = tostring(name):lower()
		t.full = name
	else
		assert( Pred.IsIndexable(name) )
		assert( Pred.IsWordable(name.short) )
		assert( Logic.Implies(name.full, Pred.IsWordable(name.full)) )

		t.short = tostring(name.short):lower()
		t.full = name.full or tostring(name.short)
	end
	return t
end


local debug_prefix_meta = {
	__tostring = function(self)
		return self[1]:GetComponentFullName()
	end,
}

local BasicComponent
-- "Abstract class". Only NamedBasicComponent can be used directly.
-- self[BasicComponent] should be a table resulting from the normalization above.
BasicComponent = Class(Debuggable, function(self, inst)
	self.inst = inst

	assert( Pred.IsTable(self[BasicComponent]) )

	Debuggable._ctor(self, setmetatable({self}, debug_prefix_meta), true)
end)

Pred.IsBasicComponent = Pred.IsInstanceOf(BasicComponent)


--[[
-- The name-related methods above can be called both on an object and on the class itself. 
--]]

function BasicComponent:GetComponentName()
	return self[BasicComponent].short
end

function BasicComponent:GetComponentFullName()
	return self[BasicComponent].full
end

-- Note that this changes the name for the whole class!
function BasicComponent:SetComponentFullName(name)
	assert( Pred.IsWordable(name) )
	self[BasicComponent].full = name
	return name
end

function BasicComponent:IsAttached()
	return self.inst.components[self:GetComponentName()]
end

function BasicComponent:IsValidComponent()
	return self.inst:IsValid() and self:IsAttached()
end

function BasicComponent:IsOkComponent()
	return Pred.IsOk(self.inst) and self:IsAttached()
end


local function NewNamedBasicComponent(name_table)
	local C = Class(BasicComponent, BasicComponent._ctor)
	C[BasicComponent] = name_table
	return C
end


local function subClassOf(sub, super)
	while sub ~= super do
		if sub == nil then return false end
		sub = sub._base
	end
	return true
end


--[[
-- Base class for component prototypes.
--]]

-- The constructor actually gets called on the instantiated class, and not on ProtoComponent objects.
local ProtoComponent = Class(function(self)
	assert( not Pred.IsProtoComponent(self) )
	assert( subClassOf(self, BasicComponent) )
end)

Pred.IsProtoComponent = Pred.IsInstanceOf(ProtoComponent)


-- Set of fields that shouldn't be copied on instantiation.
ProtoComponent.fixed_fields = {
	fixed_fields = true,
	new = true,
	Instantiate = true,
	ForcefullyInstantiate = true,
}


-- This is a bit paranoid, since using '/' as a separator is unlikely to change in the
-- game's internals.
local get_loaded_cmp
local set_loaded_cmp
do
	local seps = {'/', '\\', '.'}
	-- Here we just ensure the current OS's dir sep was included.
	do
		local native_sep = package.config:sub(1, 1)
		if not Logic.ThereExists(Logic.IsEqualTo(native_sep), ipairs(seps)) then
			table.insert(seps, native_sep)
		end
	end

	get_loaded_cmp = function(name)
		for _, s in ipairs(seps) do
			local C = package.loaded["components" .. s .. name]
			if C and C ~= true and not C._PACKAGE then return C end
		end
	end

	set_loaded_cmp = function(name, C)
		for _, s in ipairs(seps) do
			package.loaded["components" .. s .. name] = C
		end
	end
end


-- This is just for error checking.
local instantiated = setmetatable({}, {__mode = "k"})


-- This should be called by the subclass, not by objects.
local function Instantiate(self, force, name, ...)
	do
		local m = self
		while m ~= ProtoComponent do
			m = m._base
			assert( m ~= nil )
		end
	end

	local name_table = NormalizeName(name)

	if not force then
		local C = get_loaded_cmp(name_table.short)
		if C then
			assert( instantiated[C], "Didn't instantiate " .. name_table.full .. "!" )
			return C
		end
	end


	local NamedBasicComponent = NewNamedBasicComponent(name_table)

	local custom_ctor

	local C = Class(NamedBasicComponent, function(self, inst, ...)
		NamedBasicComponent._ctor(self, inst, name_table)
		custom_ctor(self, inst, ...)
	end)

	local new_fields = {}


	local function is_fixed_field(k)
		return ProtoComponent.fixed_fields[k]
			or self.fixed_fields[k]
			or (C and C.fixed_fields and C.fixed_fields[k])
	end

	
	for k, v in pairs(self) do
		if v ~= ProtoComponent[k] and not is_fixed_field(k) and C[k] == nil then
			C[k] = v
			new_fields[k] = true
		end
	end


	self._ctor(C, ...)


	custom_ctor = C.new or self.new or Lambda.Nil


	-- Now we do the overrides and remove extra fields if necessary, due to possible increments in fixed_fields.
	
	if C.fixed_fields then
		for k in pairs(C.fixed_fields) do
			if new_fields[k] then
				C[k] = nil
				new_fields[k] = nil
			end
		end
		C.fixed_fields = nil
	end


	set_loaded_cmp(name_table.short, C)
	instantiated[C] = true

	return C
end

function ProtoComponent:Instantiate(name, ...)
	return Instantiate(self, false, name, ...)
end

function ProtoComponent:ForcefullyInstantiate(name, ...)
	return Instantiate(self, true, name, ...)
end

return ProtoComponent
