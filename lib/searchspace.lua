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

local TheSim = TheSim
local FindValidPositionByFan = FindValidPositionByFan


--@@WICKER ENVIRONMENT BOOTUP
local _modname = assert( (assert(..., 'This file should be loaded through require.')):match('^[%a_][%w_%s]*') , 'Invalid path.' )
module( ..., require(_modname .. '.wicker.booter') )
--@@END ENVIRONMENT BOOTUP


local Lambda = wickerrequire 'paradigms.functional'

local Pred = wickerrequire 'lib.predicates'

local myutils = wickerrequire 'utils'


FindAllEntities = myutils.game.FindAllEntities
FindSomeEntity = myutils.game.FindSomeEntity


Annulus = Class(function(self, center, r, R, rng, tries)
	self.center = center
	self.r = r
	self.R = R
	self.rng = rng or math.random
	self.tries = tries or 16
end)

function Annulus:Search(f)
	local function test_at_offset(dv)
		return f(self.center + dv)
	end

	for _=1, self.tries do
		local offset = FindValidPositionByFan(
			2*math.pi*math.random(), -- No, math.random shouldn't be self.rng. An annulus is radially symmetric.
			self.r + (self.R - self.r)*self.rng(),
			8,
			test_at_offset
		)
		if offset then return self.center + offset end
	end
end


return _M
