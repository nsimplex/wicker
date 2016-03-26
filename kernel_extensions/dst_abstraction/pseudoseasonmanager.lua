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

local TUNING = TUNING

local is_rog = IsRoG()

-- It doesn't matter if the game mode itself is SW or not.
local is_sw = IsSW()

---

local SEASON_NAMES
if is_sw then
	SEASON_NAMES = {"autumn", "winter", "spring", "summer", "mild", "wet", "green", "dry"}
elseif is_rog then
	SEASON_NAMES = {"autumn", "winter", "spring", "summer"}
else
	SEASON_NAMES = {"summer", "winter"}
end

local LIGHTNING_MODES_PRETTYNAME_MAP = {
	rain = "WhenRaining",
	snow = "WhenSnowing",
	any = "WhenPrecipitating", -- "any" is the new "precip"
	always = "Always",
	never = "Never",
}

---

local function translateWeatherEvents()
	local wrapSnowLevel = PU.NewTableWrapper("snow")

	local event_map = {
		rainstart = {"startrain"},
		rainstop = {"stoprain"},
		snowstart = {"startsnow"},
		snowstop = {"stopsnow"},

		snowcoverchange = {"snowlevel", map = wrapSnowLevel},
	}

	PU.TranslateWorldEvents(event_map)
end

local function translateSeasonEvents()
	local wrapSeason = PU.NewTableWrapper("season")

	local event_map = {
		seasonChange = {"season", map = wrapSeason},
	}

	PU.TranslateWorldEvents(event_map)
end

translateWeatherEvents()
translateSeasonEvents()

---

local SeasonBase
if IsSingleplayer() then
	SeasonBase = require "components/seasonmanager"
else
	SeasonBase = require "components/seasons"
end

local PseudoSeasonManager = PU.PseudoClass("PseudoSeasonManager", SeasonBase, function(self)
	--assert(IsDST(), "Attempt to create a PseudoSeasonManager object in singleplayer!")
	
	local inst = TheWorld ~= nil and TheWorld or assert( self.targetself.inst )
	assert(TheWorld == nil or inst == TheWorld)

	self.inst = inst
end)
local PseudoSM = PseudoSeasonManager

-- Just a utility table.
-- Methods set here are put in PseudoSeasonManager, except they raise an error when called if we are not the host.
local MasterPseudoSeasonManager = PU.NewMasterSetter(PseudoSeasonManager, "PseudoSeasonManager")
local MasterPseudoSM = MasterPseudoSeasonManager

local API = PU.NewAPI(PseudoSeasonManager)
local MasterAPI = PU.NewMasterSetter(API, "PseudoSeasonManager")

---

local PushWE = PU.PushWorldEvent
local PushWET = PU.PushWorldEventTrigger
local WSGet = PU.WorldStateGet
local WSGetter = PU.WorldStateGetter

local defineSeasonMethods = PU.NewGenericMethodDefiner(SEASON_NAMES)
local defineLightningModeMethods = PU.NewGenericMethodDefiner(LIGHTNING_MODES_PRETTYNAME_MAP)

local setSeason = PushWET("ms_setseason")
local setSeasonMode = PushWET("ms_setseasonmode")

---

-- TODO: change this when caves are supported in DST.
API.SetCaves = Lambda.Error("Caves are not supported yet.")

MasterAPI.SetMoiustureMult = PushWET("ms_setmoisturescale")
MasterAPI.SetMoistureMult = MasterAPI.SetMoiustureMult

defineSeasonMethods(MasterAPI, "Endless%s", function(self, season, pre_length, rampup)
	-- pre_length and rampup are currently hardcoded constants in
	-- components/seasons.lua, so the parameters are ignored.
	
	setSeason(self, season)
	setSeasonMode(self, "endless")
end)

defineSeasonMethods(MasterAPI, "Always%s", function(self, season)
	setSeason(self, season)
	setSeasonMode(self, "always")
end)

MasterAPI.Cycle = Lambda.BindSecond(setSeasonMode, "cycle")

MasterAPI.AlwaysWet = PushWET("ms_setprecipitationmode", "always")

MasterAPI.AlwaysDry = PushWET("ms_setprecipitationmode", "never")

function MasterAPI:OverrideLightningDelays(min, max)
	PushWE("ms_setlightningmode", {min = min, max = max})
end

function MasterAPI:DefaultLightningDelays()
	PushWE("ms_setlightningmode", {})
end

defineLightningModeMethods(MasterAPI, "Lightning%s", PushWET("ms_setlightningmode"))

local argsToSeasonTable
if is_rog or is_sw then
	argsToSeasonTable = function(autumn, winter, spring, summer)
		return {
			autumn = autumn,
			winter = winter,
			spring = spring,
			summer = summer,
		}
	end
else
	argsToSeasonTable = function(summer, winter)
		return {
			summer = summer,
			winter =  winter,
		}
	end
end

function MasterAPI:SetSeasonLengths(...)
	PushWE("ms_setseasonlengths", argsToSeasonTable(...), self)
end

function MasterAPI:SetSegs(...)
	PushWE("ms_setseasonclocksegs", argsToSeasonTable(...), self)
end

API.GetCurrentTemperature = WSGetter("temperature")

API.GetDaysLeftInSeason = WSGetter("remainingdaysinseason")

API.GetDaysIntoSeason = WSGetter("elapseddaysinseason")

API.GetSeasonString = WSGetter("season")

function API:GetPercentSeason()
	return self:GetDaysIntoSeason()/self:GetSeasonLength()
end

function MasterAPI:ForcePrecip()
	PushWE("ms_forceprecipitation", true)
end

function MasterAPI:ForceStopPrecip()
	PushWE("ms_forceprecipitation", false)
end

MasterAPI.DoLightningStrike = PushWET("ms_sendlightningstrike")

API.GetPOP = WSGetter("pop")

API.GetPrecipitationRate = WSGetter("precipitationrate")

API.GetMoistureLimit = WSGetter("moistureceil")

defineSeasonMethods(MasterAPI, "Start%s", PushWET("ms_setseason"))

-- Not a complete equivalence.
function MasterAPI:StartPrecip()
	self:ForcePrecip()
	self.inst.components.weather:OnUpdate(0)
end

do
	local len_strs = {}
	for _, season in ipairs(SEASON_NAMES) do
		len_strs[season] = season.."length"
	end

	function API:GetSeasonLength()
		return WSGet(len_strs[self:GetSeason()], self)
	end
end

defineSeasonMethods(API, "Is%s", function(self, season)
	return self:GetSeason() == season
end)

API.GetSnowPercent = WSGetter("snowlevel")

MasterAPI.Advance = PushWET("ms_advanceseason")

function API:GetTemperature()
	return self:GetCurrentTemperature()
end

MasterAPI.Retreat = PushWET("ms_retreatseason")

-- Not a complete equivalence.
function MasterAPI:StopPrecip()
	self:ForceStopPrecip()
	self.inst.components.weather:OnUpdate(0)
end

API.IsRaining = WSGetter("israining")

API.GetSeason = WSGetter("season")

API.OnUpdate = Lambda.Nil
API.LongUpdate = Lambda.Nil

if IsSingleplayer() then
	for k, v in pairs(SeasonBase) do
		print(tostring(k), " ==> ", tostring(v))
	end
	API.Invert(SeasonBase)
end

return PseudoSeasonManager
