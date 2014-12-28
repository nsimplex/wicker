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

local _G = _G

---

local factored_time_meta = {
	__tostring = function(t)
		if t.d > 0 then
			return ("%dd%02dh%02dm%02ds"):format(t.d, t.h, t.m, t.s)
		end
		if t.h > 0 then
			return ("%dh%02dm%02ds"):format(t.h, t.m, t.s)
		end
		if t.m > 0 then
			return ("%dm%02ds"):format(t.m, t.s)
		end
		return ("%ds"):format(t.s)
	end
}

-- Factors and rounds time (given in seconds) into hours, minutes and seconds.
function FactorTime(dt)
	local s, m, h, d
	s = math.floor(dt)
	m = math.floor(s*(1/60))
	s = s % 60
	h = math.floor(m*(1/60))
	m = m % 60
	d = math.floor(h*(1/24))
	h = h % 24
	return setmetatable(
		{d = d, h = h, m = m, s = s},
		factored_time_meta
	)
end
Factor = FactorTime

local function basic_time_formatter(fmt)
	return function()
		return os.date(fmt)
	end
end
if IsWorldgen() then
	TimeFormatter = basic_time_formatter
else
	local FMT_TICK_THRESHOLD = 15

	function TimeFormatter(fmt)
		local get_str = basic_time_formatter(fmt)

		local next_tick = -math.huge
		local str = nil

		return function()
			local tick = _G.GetTick()
			if tick >= next_tick then
				str = get_str()
				next_tick = tick + FMT_TICK_THRESHOLD
			end
			return str
		end
	end
end
