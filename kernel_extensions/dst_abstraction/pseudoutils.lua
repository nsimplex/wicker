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


function NewMasterSetter(baseclass, baseclassname)
	local assert = assert
	local type = type
	local IsHost = IsHost

	assert(type(baseclass) == "table")
	assert(type(baseclassname) == "string")

	return setmetatable({}, {
		__index = baseclass,
		__newindex = function(_, k, v)
			assert(type(v) == "function")
			if IsHost() then
				baseclass[k] = v
			else
				baseclass[k] = Lambda.Error("Attempt to call ", baseclassname, ":", k, "() on non-host.")
			end
		end,
	})
end
local NewMasterSetter = NewMasterSetter


-- The optional self should be a component of the world entity.
function PushWorldEvent(name, data, self)
	(self and self.inst or TheWorld):PushEvent(name, data)
end
local PushWorldEvent = PushWorldEvent

function PushWorldEventTrigger(name, fixed_data)
	local ret = function(self, data)
		return PushWorldEvent(name, data, self)
	end
	if fixed_data then
		ret = Lambda.BindSecond(ret, fixed_data)
	end
	return ret
end
local PushWorldEventTrigger = PushWorldEventTrigger


-- The optional self should be a component of the world entity.
function WorldStateGet(k, self)
	local wsdata = (self and self.inst or TheWorld).state
	if wsdata then
		return wsdata[k]
	end
end
local WorldStateGet = WorldStateGet

function WorldStateGetter(k)
	return Lambda.BindFirst(WorldStateGet, k)
end
local WorldStateGetter = WorldStateGetter


function NewCapitalizationMap(t)
	local m = {}
	for _, v in ipairs(t) do
		m[v] = v:gsub("^.", string.upper)
	end
	return m
end
local NewCapitalizationMap = NewCapitalizationMap

function NewGenericMethodDefiner(possibilities)
	local cap_map
	if possibilities[1] or next(possibilities) == nil then
		cap_map = NewCapitalizationMap(possibilities)
	else
		cap_map = possibilities
		possibilities = {}
		for k in pairs(cap_map) do
			table.insert(possibilities, k)
		end
	end

	return function(class, name_template, generic_fn)
		for _, p in ipairs(possibilities) do
			local method_name = name_template:format(cap_map[p])
			class[method_name] = function(self, ...)
				return generic_fn(self, p, ...)
			end
		end
	end
end
local NewGenericMethodDefiner = NewGenericMethodDefiner
