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


---
-- @description Implements a Debuggable class, to be used as a superclass in inheritance.
--
-- The Debuggable class inherits from Configurable.
-- Instead of the traditional "verbosity level" approach, a layered, object-oriented
-- approach to togglable verbosity is used:
-- <ol>
-- <li> If the object has a non-nil debug flag set through SetDebugFlag, it is used; </li>
-- <li> Otherwise, if the object's class has a non-nil _DEBUG field, it is used; </li>
-- <li> Otherwise, self:GetConfig("DEBUG") is used. </li>
-- </ol>


local Lambda = wickerrequire 'paradigms.functional'
local Logic = wickerrequire 'lib.logic'

local Pred = wickerrequire 'lib.predicates'

local io = wickerrequire 'utils.io'

local Configurable = wickerrequire 'gadgets.configurable'

---

local Debuggable

---

local prefix_metatable = {
	__tostring = function(self)
		if self.inst ~= nil then
			return string.format("%s [%s]", tostring(self[1]), tostring(self[2].inst))
		else
			return tostring(self[1])
		end
	end,
}

---
-- @description The Debuggable class. Inherits from Configurable.
--
-- @class table
Debuggable = Class(Configurable, function(self, prefix, show_inst)
	Configurable._ctor(self)

	prefix = prefix or ""
	assert( Pred.IsWordable(prefix) )

	if show_inst ~= false then
		prefix = setmetatable({
			prefix,
			self,
		}, prefix_metatable)
	end

	local Notifier, Sayer, Fmter = io.NewNotifier(prefix, 1)

	---
	-- Prints a message with source file/line number information.
	--
	-- @name Debuggable:Notify
	function self:Notify(...)
		return Notifier(...)
	end

	---
	-- Prints a message directly.
	--
	-- @name Debuggable:Say
	function self:Say(...)
		return Sayer(...)
	end

	---
	-- Formats a sequence of arguments into a message to be said
	-- by this object (nolineprint'ing it is the same as Say'ing
	-- that sequence of arguments).
	function self:Format(...)
		return Fmter(...)
	end
	self.format = self.Format

	local debug_flag = nil

	---
	-- Returns the debug flag.
	--
	-- @name Debuggable:GetDebugFlag
	function self:GetDebugFlag()
		return debug_flag
	end

	---
	-- Sets the debug flag.
	--
	-- @name Debuggable:SetDebugFlag
	function self:SetDebugFlag(v)
		debug_flag = v
		return v
	end
end)

Pred.IsDebuggable = Pred.IsInstanceOf(Debuggable)

-- Clears the Configurable __call metamethod.
Debuggable.__call = nil

---
-- Alias of SetDebugFlag.
function Debuggable:SetDebugging(b)
	self:SetDebugFlag(b)
end

Debuggable.SetDebug = Debuggable.SetDebugging

---
-- Returns whether the object is debugging, according to the layered logic.
function Debuggable:IsDebugging()
	if self:GetDebugFlag() ~= nil then
		return self:GetDebugFlag() and true or false
	end
	local m = getmetatable(self)
	if m._DEBUG ~= nil then return m._DEBUG and true or false end
	return self:GetConfig('DEBUG') and true or false
end

Debuggable.IsDebug = Debuggable.IsDebugging
Debuggable.Debugging = Debuggable.IsDebugging
Debuggable.Debug = Debuggable.IsDebugging

function Debuggable:EnableDebugging()
	self:SetDebugging(true)
end

function Debuggable:DisableDebugging()
	self:SetDebugging(false)
end

---
-- Removes the object's debug flag.
function Debuggable:DefaultDebugging()
	self:SetDebugging(nil)
end

---
-- Calls Debuggable:Notify() if debugging.
function Debuggable:DebugNotify(...)
	if self:IsDebugging() then
		self:Notify(...)
	end
end

---
-- Calls Debuggable:Say() if debugging.
function Debuggable:DebugSay(...)
	if self:IsDebugging() then
		self:Say(...)
	end
end
B

function Debuggable:Warn(...)
	self:Say("WARNING: ", ...)
end

function Debuggable:DebugWarn(...)
	if self:IsDebugging() then
		self:Warn(...)
	end
end

function Debuggable:GetDebugString()
	return self:Format()
end

Debuggable.__tostring = Debuggable.GetDebugString

return Debuggable
