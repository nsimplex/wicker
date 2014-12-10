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
local Logic = wickerrequire "lib.logic"


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

function PseudoClass(name, ...)
	local C = Class(...)
	local mt = getmetatable(C)
	mt.__index = function(_, k)
		return error("Attempt to access invalid member '"..tostring(k).."' in class "..name, 2)
	end
	return C
end
local PseudoClass = PseudoClass


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


---


function NewTableWrapper(k)
	return function(v)
		return {[k] = v}
	end
end
local NewTableWrapper = NewTableWrapper

--[[
-- This takes care of translating singleplayer world events into world state watching when in MP.
--]]

TranslateWorldEvents = (function()
	if not IsDST() then return Lambda.Nil end

	local target_event_map = {}

	local getCallbackMap = (function()
		local key = {}

		local setmetatable = setmetatable

		return function(inst, event)
			local t = inst[key]
			if t == nil then
				t = {}
				inst[key] = t
			end
			local ret = t[event]
			if ret == nil then
				ret = setmetatable({}, {__mode = "kv"})
				t[event] = ret
			end
			return ret
		end
	end)()

	-- Takes the world event listener as the fn parameter.
	local function wrapCallback(fn, filter, datamap)
		filter = filter or Lambda.True
		datamap = datamap or Lambda.Identity

		-- This is the world state watcher.
		local function gn(inst, val)
			if filter(val) then
				return fn(inst, datamap(val))
			end
		end

		return gn
	end

	_G.EntityScript.ListenForEvent = (function()
		local ListenForEvent = assert(_G.EntityScript.ListenForEvent)

		return function(inst, event, fn, source)
			source = source or inst
			if source ~= TheWorld then
				return ListenForEvent(inst, event, fn, source)
			end

			local watch_info = target_event_map[event]
			if watch_info then
				local gn = wrapCallback(fn, watch_info.filter, watch_info.map)
				getCallbackMap(inst, event)[fn] = gn
				return inst:WatchWorldState(watch_info[1], gn)
			else
				return ListenForEvent(inst, event, fn, source)
			end
		end
	end)()

	_G.EntityScript.RemoveEventCallback = (function()
		local RemoveEventCallback = assert(_G.EntityScript.RemoveEventCallback)

		return function(inst, event, fn, source)
			source = source or inst
			if source ~= TheWorld then
				return RemoveEventCallback(inst, event, fn, source)
			end

			local watch_info = target_event_map[event]
			if watch_info then
				local cb_map = getCallbackMap(inst, event)
				local gn = cb_map[fn]
				if gn then
					cb_map[fn] = nil
					return inst:StopWatchingWorldState(watch_info[1], gn)
				end
			else
				return RemoveEventCallback(inst, event, fn, source)
			end
		end
	end)()

	return function(new_maps)
		for k, v in pairs(new_maps) do
			if type(v) ~= "table" then
				v = {v}
			end
			target_event_map[k] = v
		end
	end
end)()
local TranslateWorldEvents = TranslateWorldEvents
