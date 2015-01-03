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

local PHASE_ORDER = PU.InvertTable(PHASES)

---

local function translatePhaseEvents()
	-- To be used with the old "daytime" and similar events.
	local wrapCycleData = PU.NewTableWrapper("day")

	local function getCycleData()
		return wrapCycleData(GetPseudoClock():GetNumCycles())
	end

	local event_map = {
		daycomplete = {"cycles", map = wrapCycleData},
	}
	for _, phase in ipairs(PHASES) do
		event_map[phase.."time"] = {"is"..phase, map = getCycleData}
	end

	PU.TranslateWorldEvents(event_map)
end

translatePhaseEvents()

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

---

local ClockBase = require "components/clock"
local PseudoClock = PU.PseudoClass("PseudoClock", ClockBase, function(self)
	--assert(IsDST(), "Attempt to create a PseudoClock object in singleplayer!")

	local inst = TheWorld ~= nil and TheWorld or assert( self.targetself.inst )

	assert(TheWorld == nil or inst == TheWorld)

	self.inst = inst

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

local API = PU.NewAPI(PseudoClock)
local MasterAPI = PU.NewMasterSetter(API, "PseudoClock")

---

local PushWE = PU.PushWorldEvent
local PushWET = PU.PushWorldEventTrigger
local WSGet = PU.WorldStateGet
local WSGetter = PU.WorldStateGetter

local definePhaseMethods = PU.NewGenericMethodDefiner(PHASES)

---

local function aging_method(fn)
	if not IsDST() then
		return fn
	end

	return function(self, ...)
		local cycle0 = self:GetNumCycles()
		local norm0 = self:GetNormTime()

		fn(self, ...)

		local cycle = self:GetNumCycles()
		local norm = self:GetNormTime()

		local norm_dt = (cycle + norm) - (cycle0 + norm0)
		local dt = norm_dt*TUNING.TOTAL_DAY_TIME

		for _, player in ipairs(_G.AllPlayers) do
			local age = player.components.age
			if age then
				TheMod:DebugSay("Aging player [", player, "] by ", norm_dt, " days.")
				age:LongUpdate(dt)
			end
		end
	end
end

---

local function getTotalEraTime(self)
	return self.segs[self:GetPhase()]*TUNING.SEG_TIME
end

local function getRemainingEraTime(self)
	return getTotalEraTime(self) - self:GetTimeInEra()
end

function API:GetTimeLeftInEra()
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

function API:GetMoonPhase()
	return self.moonphase
end

function MasterAPI:SetNormEraTime(percent)
	local t0 = self:GetTimeInEra()
	local total_t = getTotalEraTime(self)

	self:LongUpdate(total_t*percent - t0)
end

function API:GetTimeInEra()
	return self:GetNormEraTime()*getTotalEraTime(self)
end

PseudoClock.GetNormEraTime = WSGetter("timeinphase")API.GetNormEraTime = WSGetter("timeinphase")

PseudoClock.GetNormTime = WSGetter("time")API.GetNormTime = WSGetter("time")

function API:CurrentPhaseIsAlways()
	return self.segs[self:GetPhase()] == NUM_SEGS
end

MasterAPI.SetNightVision = Lambda.Nil

API.IsNightVision = Lambda.False

definePhaseMethods(API, "Is%s", function(self, phase)
	return self:GetPhase() == phase	
end)

PseudoClock.GetPhase = WSGetter("phase")API.GetPhase = WSGetter("phase")

local function getShiftedPhase(self, delta)
	if self:CurrentPhaseIsAlways() then
		return self:GetPhase()
	else
		return shiftPhase(self:GetPhase(), delta)
	end
end

PseudoClock.GetNextPhase = Lambda.BindSecond(getShiftedPhase, 1)API.GetNextPhase = Lambda.BindSecond(getShiftedPhase, 1)

PseudoClock.GetPrevPhase = Lambda.BindSecond(getShiftedPhase, -1)API.GetPrevPhase = Lambda.BindSecond(getShiftedPhase, -1)

MasterAPI.MakeNextDay = aging_method(function(self)
	local cycles = self:GetNumCycles()
	PushWE("ms_nextcycle", nil, self)
	PushWE("cycleschanged", cycles + 1, self)
	self.inst.net.components.clock:LongUpdate(0.5*TUNING.SEG_TIME)
end)

function MasterAPI:MakeNextDusk()
	if self:IsDay() then
		return self:NextPhase()
	end
end

local internal_NextPhase = aging_method(function(self)
	local next_phase = self:GetNextPhase()
	PushWE("ms_nextphase", nil, self)
	PushWE("phasechanged", next_phase, self)
end)

function MasterAPI:NextPhase()
	if self:GetPhase() == PHASES[#PHASES] then
		return self:MakeNextDay()
	else
		return internal_NextPhase(self)
	end
end

definePhaseMethods(API, "Get%sSegs", function(self, phase)
	return self.segs[phase]
end)

function MasterAPI:SetSegs(day, dusk, night)
	PushWE("ms_setclocksegs", {day = day, dusk = dusk, night = night}, self)
end

function MasterAPI:DoLightningLighting(maxlight)
	PushWE("screenflash", maxlight or 1, self)
end

MasterAPI.LongUpdate = aging_method(function(self, dt)
	return self.inst.net.components.clock:LongUpdate(dt)
end)

MasterAPI.OnUpdate = aging_method(function(self, dt)
	return self.inst.net.components.clock:OnUpdate(dt)
end)

function API:LerpAmbientColour(src, dest, time)
	return AL.LerpAmbientColour(src, dest, time)
end

definePhaseMethods(API, "Get%sTime", function(self, phase)
	return self.segs[phase]*TUNING.SEG_TIME
end)

API.GetNumCycles = WSGetter("cycles")

if IsSingleplayer() then
	API.Invert(ClockBase)
end

return PseudoClock
