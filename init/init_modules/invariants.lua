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
local _G = assert( _G )

local WICKER_ROOT = assert( WICKER_ROOT )

---

local usercode_root = require_boot_param "usercode_root"
local user_id = require_boot_param "id"

---

function AssertEnvironmentValidity(env)
    assert( env._M == env )
    assert( env._ENV == env )
    assert( env._K == nil or env._K == _K )
    assert( env._G == nil or env._G == _G )

    assert( env.GetUserKey() == _K.GetUserKey(), env._NAME )
    assert( _K.TheUser == nil or env.TheUser == _K.TheUser, env._NAME )

    assert( env.GetModKey() == _K.GetModKey(), env._NAME )
    assert( _K.TheMod == nil or env.TheMod == _K.TheMod, env._NAME )
    if _K.modenv ~= nil then
        -- Some Don't Starve specific extra checks.
        local modenv = _K.modenv
        assert( env.modname == modenv.modname, env._NAME )
        assert( env.modinfo == modenv.modinfo, env._NAME )
        -- TODO: see if this should be done to play nice with DST's mod
        -- debugging scheme.
        -- assert( env.env == modenv )
    end

    return env
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
