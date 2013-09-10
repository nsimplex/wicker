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

function AddSaveIndexPostInit(fn)
	require 'saveindex'

	AddGlobalClassPostConstruct("saveindex", "SaveIndex", fn)

	local instance = rawget(_G, "SaveGameIndex")
	if instance then
		fn(instance)
	end
end


TheMod:EmbedHook("SaveIndex", AddSaveIndexPostInit, "post")


return AddSaveIndexPostInit
