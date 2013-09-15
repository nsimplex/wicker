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

--@@WICKER ENVIRONMENT BOOTUP
local _modname = assert( (assert(..., 'This file should be loaded through require.')):match('^[%a_][%w_%s]*') , 'Invalid path.' )
module( ..., require(_modname .. '.wicker.booter') )
--@@END ENVIRONMENT BOOTUP


local factored_time_meta = {
	__tostring = function(t)
		if t.h > 0 then
			return tostring(t.h) .. 'h' .. tostring(t.m) .. 'm' .. tostring(t.s) .. 's'
		end
		if t.m > 0 then
			return tostring(t.m) .. 'm' .. tostring(t.s) .. 's'
		end
		return tostring(t.s) .. 's'
	end
}

-- Factors and rounds time (given in seconds) into hours, minutes and seconds.
function FactorTime(dt)
	local s, m, h
	s = math.floor(dt)
	m = math.floor(s/60)
	s = s % 60
	h = math.floor(m/60)
	m = m %60
	return setmetatable(
		{h = h, m = m, s = s},
		factored_time_meta
	)
end

return _M
