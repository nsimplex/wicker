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

local io = wickerrequire 'utils.io'

local Configurable = wickerrequire 'gadgets.configurable'

local Debuggable

Debuggable = Class(Configurable, function(self, prefix, show_inst)
	Configurable._ctor(self)

	prefix = prefix or ""

	if show_inst or show_inst == nil and self.inst then
		prefix = setmetatable(
			{
				prefix = prefix,
			},
			{
				__tostring = function(t)
					return tostring(t.prefix) .. ' [' .. tostring(self.inst) .. ']'
				end
			}
		)
	end

	local Notifier, Sayer = io.NewNotifier(prefix, 1)

	function self:Notify(...)
		Notifier(...)
	end

	function self:Say(...)
		Sayer(...)
	end

	local debug_flag = nil

	function self:GetDebugFlag()
		return debug_flag
	end

	function self:SetDebugFlag(v)
		debug_flag = v
		return v
	end
end)

Pred.IsDebuggable = Pred.IsInstanceOf(Debuggable)

function Debuggable:SetDebugging(b)
	self:SetDebugFlag(b)
end

Debuggable.SetDebug = Debuggable.SetDebugging

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

function Debuggable:DefaultDebugging()
	self:SetDebugging(nil)
end

function Debuggable:DebugNotify(...)
	if self:IsDebugging() then
		self:Notify(...)
	end
end

function Debuggable:DebugSay(...)
	if self:IsDebugging() then
		self:Say(...)
	end
end

return Debuggable
