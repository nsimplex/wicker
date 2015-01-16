--[[
-- Implements an event chain with side-effects.
--
-- EventChain is a functional object that takes an inst followed by a trigger and a variadic list of parameters.
-- The trigger should be an event name (a string), or a table whose first entry is a string and the second one is
-- the source EntityScript. A listener will be attached to this event.
-- The callback will do the following to each remaining argument of the variadic list:
-- If it is a table, treat the first entry as a string in the logic below, and use the second entry as a source.
-- If it is a string, treat it as an event name and delay execution until it happens.
-- If it is a number, treat it as a numerical delay and wait that many seconds (asynchronously, not preserved between saves).
-- It is a function, run it on inst and on self (in that order). If the function returns false or nil, break.
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



local Lambda = wickerrequire 'paradigms.functional'

local myutils = wickerrequire 'utils'
local Pred = wickerrequire 'lib.predicates'

local Debuggable = wickerrequire 'gadgets.debuggable'


local EventChain = Class(Debuggable, function(self, trigger, ...)
	Debuggable._ctor(self, "EventChain over", true)

	if Pred.IsTable(trigger) then
		self.source = trigger[2]
		trigger = trigger[1]
		assert(Pred.IsInstanceOf(EntityScript)(self.source))
	end

	assert(Pred.IsString(trigger))
	self.trigger = trigger

	self.Args = {...}

	self.enabled = false
	self.active = false

	self.startfn = nil
	self.finishfn = nil
	self.cancelfn = nil

	self.callback = function(source)
		if self.active then return end
		self.active = true
		if self.startfn then self.startfn(self.inst, self) end
		self:ApplyEventChaser(1)
	end
end)

function EventChain:Copy()
	local c = EventChain(self.trigger, unpack(self.Args))
	c.startfn = self.startfn
	c.finishfn = self.finishfn
	c.cancelfn = self.cancelfn
	return c
end

function EventChain:Append(x)
	table.insert(self.Args, x)
	return x
end

function EventChain:SetStartFn(f)
	self.startfn = f
	return f
end

function EventChain:SetFinishFn(f)
	self.finishfn = f
	return f
end

function EventChain:SetCancelFn(f)
	self.cancelfn = f
	return f
end

function EventChain:GetInst()
	return self.inst
end

function EventChain:IsAttached()
	return self:GetInst() and true or false
end

function EventChain:Attach(inst)
	if self:IsAttached() then
		self:Detach()
	end
	self.inst = inst
	return self
end

function EventChain:Detach()
	self:Disable()
	self.inst = nil
	return self
end

function EventChain:IsEnabled()
	assert( Pred.Implies(self.enabled, self:IsAttached()) )
	return self.enabled
end

function EventChain:Enable()
	if not self:IsEnabled() then
		self.inst:ListenForEvent(self.trigger, self.callback, self.source)
	end
	self.enabled = true
	return self
end

function EventChain:Disable()
	self:Cancel()
	if self:IsEnabled() then
		self.inst:RemoveEventCallback(self.trigger, self.callback, self.source)
	end
	self.enabled = false
	return self
end

function EventChain:IsActive()
	assert( Pred.Implies(self.active, self:IsEnabled()) )
	return self.active
end

function EventChain:Cancel()
	if self.cancelfn and self:IsActive() then
		self.cancelfn(self.inst, self)
	end
	self.active = false
	return self
end

function EventChain:ApplyEventChaser(i)
	if not self:IsActive() then return end

	i = i or 1

	local arg = self.Args[i]
	if not arg then
		self.active = false
		return not self.finishfn or self.finishfn(self.inst, self)
	end

	self:DebugSay('ApplyEventChaser(', i, ')')

	local source = self.source

	if Pred.IsTable(arg) then
		source = arg[2]
		arg = arg[1]
		assert(Pred.IsString(arg))
		assert(Pred.IsInstanceOf(EntityScript)(source))
	end

	if Pred.IsString(arg) then
		myutils.game.ListenForEventOnce(self.inst, arg, function()
			self:ApplyEventChaser(i + 1)
		end, source)
	elseif Pred.IsCallable(arg) then
		if arg(self.inst, self) then
			return self:ApplyEventChaser(i + 1)
		else
			self:Cancel()
		end
	elseif Pred.IsNumber(arg) then
		self.inst:DoTaskInTime(arg, function() return self:ApplyEventChaser(i + 1) end)
	else
		self:Detach()
		return error("Invalid type `" .. type(arg) .. "' in self.Arg[" .. tostring(i) .. "].")
	end
end

return EventChain
