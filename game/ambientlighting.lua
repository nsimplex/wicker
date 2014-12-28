local _M = _M


local getPhaseChangeAmbientSetter = memoize_0ary(function()
	assert(IsDST())
	local wrld = assert(TheWorld)
	local getinfo = debug.getinfo
	--local string_find = string.find
	local getfenv = getfenv
	local _G = _G

	local AmbientLighting = require "components/ambientlighting"

	local wanted_source = getinfo(AmbientLighting._ctor, "S").source

	for _, fn in ipairs(wrld.event_listeners.phasechanged[wrld]) do
		if getfenv(fn) == _G then
			local info = getinfo(fn, "S")
			if info.source == wanted_source then
				return fn
			end
		end
	end

	return error("Unable to find the OnPhaseChanged from components/ambientlighting.lua through introspection.")
end)

local getPhaseAndCaveColours = memoize_0ary(function()
	assert(IsDST())
	local Reflection = wickerrequire "game.reflection"

	local OnPhaseChanged = getPhaseChangeAmbientSetter()

	local phase, cave
	for i, name, val in Reflection.Upvalues(OnPhaseChanged) do
		if name == "PHASE_COLOURS" then
			phase = val
		elseif name == "CAVE_COLOUR" then
			cave = val
		end
	end

	if not phase then
		return error("Unable to find PHASE_COLOURS from components/ambientlighting.lua through introspection.")
	end
	if not cave then
		return error("Unable to find CAVE_COLOUR from components/ambientlighting.lua through introspection.")
	end

	return {
		PHASE_COLOURS = phase,
		CAVE_COLOUR = cave,
	}
end)

local function getPseudoPhaseName()
	return _M
end

local getCustomColourTable = memoize_0ary(function()
	local phasecavecolours = getPhaseAndCaveColours()

	if TheWorld:HasTag("cave") then
		return phasecavecolours.CAVE_COLOUR	
	end
	
	local phasecolours = phasecavecolours.PHASE_COLOURS
	local pseudophase = getPseudoPhaseName()

	local ret = phasecolours[pseudophase]
	if not ret then
		ret = {colour = Point(), time = 0}
		phasecolours[pseudophase] = ret
	end

	return ret
end)

if not IsDST() then
	function LerpAmbientColour(src, dest, time)
		local clock = _G.GetClock()
		if not src then
			src = clock.currentColour
		end
		clock:LerpAmbientColour(src, dest, time)
	end
else
	function LerpAmbientColour(src, dest, time)
		if src and time > 0 then
			LerpAmbientColour(nil, src, 0)
		end

		local custom = getCustomColourTable()
		custom.colour = dest
		custom.time = time

		getPhaseChangeAmbientSetter()(TheWorld, getPseudoPhaseName())
	end
end

function SetAmbientColour(c)
	return LerpAmbientColour(nil, c, 0)
end

if not IsDST() then
	function SetPhaseColour(phase, c)
		GetPseudoClock()[phase.."Colour"] = c
	end
else
	function SetPhaseColour(phase, c)
		local phasecavecolours = getPhaseAndCaveColours()
		if phase == "cave" then
			phasecavecolours.CAVE_COLOUR.colour = c
		else
			phasecavecolours.PHASE_COLOURS[phase].colour = c
		end
	end
end

function SetCaveColour(c)
	return SetPhaseColour("cave", c)
end
