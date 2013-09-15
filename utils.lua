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

string = pkgrequire 'utils.string'
table = pkgrequire 'utils.table'
algo = pkgrequire 'utils.algo'
time = pkgrequire 'utils.time'
filesystem = pkgrequire 'utils.filesystem'
io = pkgrequire 'utils.io'
game = pkgrequire 'utils.game'

return _M
