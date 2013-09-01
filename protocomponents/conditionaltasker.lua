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

local myutils = wickerrequire 'utils'


local ProtoComponent = pkgrequire 'base'


local ConditionalTasker = Class(ProtoComponent, function(self)
	ProtoComponent._ctor(self)

	--[[
	-- Main configurable parameters.
	-- Defines class defaults.
	--]]
	
	-- How long a new task will take to complete, in seconds.
	self:SetFullDelay(math.huge)

	-- Condition for tasking.
	self:SetConditionFn(Lambda.True)

	-- Task completion callback.
	self:SetOnCompleteFn(Lambda.Nil)

	-- Receives the entity, the status of the start attempt,
	-- as well as one more (optional) extra return value from the condition.
	self:SetOnTryStartFn(Lambda.Nil)
	
	--[[
	-- End of main configurable parameters.
	--]]
	
	function self.TryStarter(inst)
		if Pred.IsOk(inst) and inst.components[self:GetComponentName()] then
			inst.components[self:GetComponentName()]:TryStart()
		end
	end
end)


function ConditionalTasker:new(inst)
	self.task = nil
	self.paused_delay = math.huge

	self.inst:DoTaskInTime(0, function(inst)
		if self:IsOkComponent() then
			self:TryStart()
		end
	end)
end


function ConditionalTasker:SetConditionFn(f)
	assert(f == nil or Pred.IsCallable(f))
	self.condition_fn = f
	return f
end

function ConditionalTasker:GetConditionFn()
	assert( self.condition_fn )
	return self.condition_fn
end

-- The return value is used as a boolean test for whether the tasker should immediately TryStart() again or not.
function ConditionalTasker:SetOnCompleteFn(f)
	assert(f == nil or Pred.IsCallable(f))
	self.oncomplete_fn = f
	return f
end

function ConditionalTasker:GetOnCompleteFn()
	assert( self.oncomplete_fn )
	return self.oncomplete_fn
end

-- Receives a boolean as a second argument indicating whether the start was successful or not
-- (i.e., if the condition passed or not)
-- Receives as a third parameter the second return value from the condition test (if any).
function ConditionalTasker:SetOnTryStartFn(f)
	assert(f == nil or Pred.IsCallable(f))
	self.ontrystart_fn = f
	return f
end

function ConditionalTasker:GetOnTryStartFn(f)
	assert( self.ontrystart_fn )
	return self.ontrystart_fn
end

function ConditionalTasker:SatisfiesCondition()
	return self:GetConditionFn()(self.inst)
end


function ConditionalTasker:HasTask()
	assert( Logic.IfAndOnlyIf(self:GetTargetTime(), not self.paused_delay) )
	assert( Logic.Implies(self.task, self:GetTargetTime()) )
	return self.task and true or false
end

function ConditionalTasker:GetTentativeRemainingTime()
	-- Just for the sanity checks.
	self:HasTask()
	return self.paused_delay or math.max(0, self:GetTargetTime() - GetTime())	
end

function ConditionalTasker:GetFactoredRemainingTime()
	return myutils.time.FactorTime( self:GetTentativeRemainingTime() )
end

function ConditionalTasker:GetFullDelay()
	return self.full_delay
end

function ConditionalTasker:SetFullDelay(delay)
	assert(Pred.IsPositiveNumber(delay))
	self.full_delay = delay
	return delay
end

function ConditionalTasker:GetTargetTime()
	return self.targettime
end

function ConditionalTasker:SetTargetTime(dt)
	assert(dt == nil or Pred.IsNumber(dt))
	self.targettime = dt
	return dt
end

function ConditionalTasker:OnComplete()
	if self:SatisfiesCondition() then
		if self:GetOnCompleteFn()(self.inst) then
			self:TryStart()
		end
	else
		self:TryStart()
	end
end


function ConditionalTasker:GetDebugString()
	local t

	if not self:SatisfiesCondition() then
		t = {'(inactive)'}
	else
		t = {}

		if self:HasTask() then
			table.insert(t, '(active at ')
			table.insert(t, tostring(self:GetFactoredRemainingTime()))
			table.insert(t, ' remaining)')
		else
			if self:GetTargetTime() then
				table.insert(t, '(background updating at ')
			else
				table.insert(t, '(paused at ')
			end
			table.insert(t, tostring(self:GetFactoredRemainingTime()))
			table.insert(t, ' remaining)')
		end
	end

	return table.concat(t)
end

function ConditionalTasker:StartTask()
	if
		not self:HasTask()
		and self:GetTargetTime() < math.huge
		and self:IsOkComponent()
--		and not self.inst:IsAsleep()
	then
		self:DebugSay('StartTask()')
		self.task = self.inst:DoTaskInTime(self:GetTentativeRemainingTime(), function()
			if self:IsOkComponent() then
				self:OnComplete()
			end
		end)
	end
end

function ConditionalTasker:StopTask()
	if self:HasTask() then
		self:DebugSay('StopTask()')
		self.task:Cancel()
		self.task = nil
	end
end

function ConditionalTasker:Unpause()
	-- Just for the sanity checks.
	self:HasTask()

	if not self:GetTargetTime() then
		assert( Pred.IsNonNegativeNumber(self.paused_delay) )
		self:SetTargetTime(GetTime() + self.paused_delay)
		self.paused_delay = nil
		self:StartTask()
	end
end

function ConditionalTasker:Pause()
	-- Just for the sanity checks.
	self:HasTask()

	if self:GetTargetTime() then
		self:DebugSay( 'Pause()' )

		self:StopTask()
		self.paused_delay = math.max(0, self:GetTargetTime() - GetTime())
		self:SetTargetTime(nil)
	end
end

function ConditionalTasker:Reboot(daily)
	self:DebugSay('Reboot()', daily and ' DAILY' or nil)

	self:Pause()

	if self:SatisfiesCondition() then
		if self.paused_delay <= 0 then
			self:OnComplete()
		else
			if self.paused_delay == math.huge then
				self.paused_delay = self:GetFullDelay()
			end
			self:Unpause()
		end
	else
		self.paused_delay = math.huge
	end

	if self:Debug() then
		self:Say( self:GetDebugString() )
	end
end


function ConditionalTasker:TryStart()
	if not self:IsOkComponent() then return end

	local b, data = self:SatisfiesCondition()
	self:DebugSay('TryStart() ', b and "passed" or "failed")

	self:GetOnTryStartFn()(self.inst, b, data)

	self:Reboot()
end

ConditionalTasker.Stop = ConditionalTasker.Pause

function ConditionalTasker:DoDelta(dt)
	if self:Debug() then
		self:Say( 'DoDelta(', myutils.time.FactorTime(dt), ')' )
	end
	self:Pause()
	self.paused_delay = math.max(0, self.paused_delay - dt)
	self:Reboot()
	return dt
end

function ConditionalTasker:LongUpdate(dt)
	self:DoDelta(dt)
end

function ConditionalTasker:OnEntityWake()
	self:DebugSay('OnEntityWake()')
	self:Reboot()
end

function ConditionalTasker:OnEntitySleep()
	self:DebugSay('OnEntitySleep()')
	self:Reboot()
end


local function dump_measure(x)
	assert(Pred.IsNonNegativeNumber(x))
	return x == math.huge and -1 or x
end

local function load_measure(x)
	if x == nil or Pred.IsNonNegativeNumber(x) then
		return x
	else
		return math.huge
	end
end

function ConditionalTasker:OnSave()
	self:DebugSay('OnSave()')

	self:Pause()

	local data = {
		conditional_tasker_paused_delay = dump_measure(self.paused_delay),
	}

	self:Reboot()

	return data
end

function ConditionalTasker:OnLoad(data)
	self:DebugSay('OnLoad()')

	self:Stop()

	if data then
		self.paused_delay = math.min(load_measure(data.conditional_tasker_paused_delay) or math.huge, self:GetFullDelay())
	end

	self:TryStart()
end


return ConditionalTasker
