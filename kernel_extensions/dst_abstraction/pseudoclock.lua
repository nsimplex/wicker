-----
--[[ Wicker ]] VERSION="3.0"
--
-- Last updated: 2013-11-29
-----

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

local Lambda = wickerrequire "paradigms.functional"

local PU = pkgrequire "pseudoutils"
local AL = wickerrequire "game.ambientlighting"

local TUNING = TUNING

---

local NUM_SEGS = 16

local PHASES = {"day", "dusk", "night"}

local PHASE_ORDER = table.invert(PHASES)

---

local function shiftPhase(phase, delta)
	return PHASES[(PHASE_ORDER[phase] + delta - 1) % #PHASES + 1]
end

local function OnClockSegsChanged(self, data)
	local s = self.segs
	s.day = data.day or 0
	s.dusk = data.dusk or 0
	s.night = data.night or 0
end

local function OnMoonPhaseChanged(self, data)
	self.moonphase = data
end

local redirectPhaseEvents = (function()
	-- Maps the old event name to the world watch id.
	local target_event_map = {
		daycomplete = "cycles",
	}
	for _, phase in ipairs(PHASES) do
		target_event_map[phase.."time"] = "is"..phase
	end

	return function(wrld)
		assert(IsDST())
		assert(wrld == TheWorld)

		_G.EntityScript.ListenForEvent = (function()
			local ListenForEvent = assert(_G.EntityScript.ListenForEvent)

			return function(inst, event, fn, source)
				source = source or inst
				if source ~= wrld then
					return ListenForEvent(inst, event, fn, source)
				end

				local watch_id = target_event_map[event]
				if watch_id then
					return inst:WatchWorldState(watch_id, fn)
				else
					return ListenForEvent(inst, event, fn, source)
				end
			end
		end)()

		_G.EntityScript.RemoveEventCallback = (function()
			local RemoveEventCallback = assert(_G.EntityScript.RemoveEventCallback)

			return function(inst, event, fn, source)
				source = source or inst
				if source ~= wrld then
					return RemoveEventCallback(inst, event, fn, source)
				end

				local watch_id = target_event_map[event]
				if watch_id then
					return inst:StopWatchingWorldState(watch_id, fn)
				else
					return RemoveEventCallback(inst, event, fn, source)
				end
			end
		end)()
	end
end)()

---

local PseudoClock = Class(function(self, inst)
	assert(IsDST(), "Attempt to create a PseudoClock object in singleplayer!")
	assert(inst == TheWorld)
	self.inst = inst

	redirectPhaseEvents(inst)

	self.segs = {day = nil, dusk = nil, night = nil}
	OnClockSegsChanged(self, {
		day = TUNING.DAY_SEGS_DEFAULT,
		dusk = TUNING.DUSK_SEGS_DEFAULT,
		night = TUNING.NIGHT_SEGS_DEFAULT,
	})
	self.inst:ListenForEvent("clocksegschanged", function(_, data) OnClockSegsChanged(self, data) end)

	self.moonphase = nil
	OnMoonPhaseChanged(self, "new")
	self.inst:ListenForEvent("moonphasechanged", function(_, data) OnMoonPhaseChanged(self, data) end)
end)

-- Just a utility table.
-- Methods set here are put in PseudoClock, except they raise an error when called if we are not the host.
local MasterPseudoClock = PU.NewMasterSetter(PseudoClock, "PseudoClock")

---

local PushWE = PU.PushWorldEvent
local PushWET = PU.PushWorldEventTrigger
local WSGet = PU.WorldStateGet
local WSGetter = PU.WorldStateGetter

local definePhaseMethods = PU.NewGenericMethodDefiner(PHASES)

---

local function getTotalEraTime(self)
	return self.segs[self:GetPhase()]*TUNING.SEG_TIME
end

local function getRemainingEraTime(self)
	return getTotalEraTime(self) - self:GetTimeInEra()
end

function PseudoClock:GetTimeLeftInEra()
	return getTotalEraTime(self) - self:GetTimeInEra()
end

---

--[[
function PseudoClock:Reset()
	--TODO
    self.numcycles = 0
    self:StartDay()
end
]]--

function PseudoClock:GetMoonPhase()
	return self.moonphase
end

function MasterPseudoClock:SetNormEraTime(percent)
	local t0 = self:GetTimeInEra()
	local total_t = getTotalEraTime(self)

	self.inst.components.clock:LongUpdate(total_t*percent - t0)
end

PseudoClock.GetTimeInEra = WSGetter("timeinphase")

function PseudoClock:GetNormEraTime()
	local total = getTotalEraTime(self)
	if total <= 0 then return 1 end

    return self:GetTimeInEra()/total
end

function PseudoClock:GetNormTime()
	local ret = 0

	local phase = self:GetPhase()
	local phase_pos = PHASE_ORDER[phase]

	for i = 1, phase_pos - 1 do
		ret = ret + self.segs[PHASES[i]]
	end
	ret = ret + self.segs[PHASES[phase_pos]]*self:GetNormEraTime()

	return ret/NUM_SEGS
end

function PseudoClock:CurrentPhaseIsAlways()
	return self.segs[self:GetPhase()] == NUM_SEGS
end

MasterPseudoClock.SetNightVision = Lambda.Nil

PseudoClock.IsNightVision = Lambda.False

definePhaseMethods(PseudoClock, "Is%s", function(self, phase)
	return self:GetPhase() == phase	
end)

PseudoClock.GetPhase = WSGetter("phase")

local function getShiftedPhase(self, delta)
	if self:CurrentPhaseIsAlways() then
		return self:GetPhase()
	else
		return shiftPhase(self:GetPhase(), delta)
	end
end

PseudoClock.GetNextPhase = Lambda.BindSecond(getShiftedPhase, 1)

PseudoClock.GetPrevPhase = Lambda.BindSecond(getShiftedPhase, -1)

MasterPseudoClock.MakeNextDay = PushWET("ms_nextcycle")

function MasterPseudoClock:MakeNextDusk()
	if self:IsDay() then
		return self:NextPhase()
	end
end

MasterPseudoClock.NextPhase = PushWET("ms_nextphase")

definePhaseMethods(PseudoClock, "Get%sSegs", function(self, phase)
	return self.segs[phase]
end)

function MasterPseudoClock:SetSegs(day, dusk, night)
	PushWE("ms_setclocksegs", {day = day, dusk = dusk, night = night}, self)
end

function MasterPseudoClock:DoLightningLighting(maxlight)
	PushWE("screenflash", maxlight or 1, self)
end

function MasterPseudoClock:LongUpdate(dt)
	return self.inst.components.clock:LongUpdate(dt)
end

function MasterPseudoClock:OnUpdate(dt)
	return self.inst.components.clock:OnUpdate(dt)
end

function PseudoClock:LerpAmbientColour(src, dest, time)
	return AL.LerpAmbientColour(src, dest, time)
end

definePhaseMethods(PseudoClock, "Get%sTime", function(self, phase)
	return self.segs[phase]*TUNING.SEG_TIME
end)

PseudoClock.GetNumCycles = WSGetter("cycles")

return PseudoClock
