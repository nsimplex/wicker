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


local assert = assert
local _K = assert( _K )

local WICKER_ROOT = assert( WICKER_ROOT )

---

local usercode_root = require_boot_param "usercode_root"
local user_id = require_boot_param "id"

---

function AssertEnvironmentValidity(env)
    assert( env.GetUserKey == nil or env.GetUserKey() == GetUserKey(), env._NAME )
    assert( env.TheUser == nil or _K.TheUser == nil or env.TheUser == _K.TheUser, env._NAME )

    assert( env.GetModKey == nil or env.GetModKey() == GetModKey(), env._NAME )
    assert( env.TheMod == nil or _K.TheMod == nil or env.TheMod == _K.TheMod, env._NAME )
    assert( modenv == nil or env.modname == nil or env.modname == modenv.modname, env._NAME )
end


-- Returns a unique key.
GetUserKey = (function()
    local k = {}
    return function()
        return k
    end
end)()
GetModKey = GetUserKey

function GetWickerRoot()
    return WICKER_ROOT
end
GetWickerStem = GetWickerRoot

function GetUsercodeRoot()
    return usercode_root
end
GetModcodeRoot = GetUsercodeRoot

function GetUserId()
    return user_id
end
GetModId = GetUserId
