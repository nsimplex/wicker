local Lambda = wickerrequire "paradigms.functional"

if IsWorldgen() then
	return Lambda.Nil
end

---

local EntityTable = wickerrequire "gadgets.entity_table"

local NetUByteArray = assert( NetUByteArray )

---

local RegisterBroadcastEvent
local function basic_PushBroadcastEvent(inst, event_name)
	return inst:PushEvent(event_name)
end
if IsDST() then
	local BROADCAST_EVENTS_KEY = {}

	local broadcast_netvar_name = tostring(assert(modinfo and modinfo.id)).."_event_broadcast"

	local netvar_dirty_handler

	local function NewBroadcastEventsMap(inst)
		local netvar = NetUByteArray(inst, broadcast_netvar_name)
		netvar.local_value = {}
		netvar:AddOnDirtyFn(netvar_dirty_handler)
		return {
			tocode = {},
			fromcode = {},
			netvar = netvar,
		}
	end

	local function GetBroadcastEventsMap(inst, create)
		local ret = inst[BROADCAST_EVENTS_KEY]
		if ret == nil and create then
			ret = NewBroadcastEventsMap(inst)
			inst[BROADCAST_EVENTS_KEY] = ret
		end
		return ret
	end

	local function GetEventCode(inst, event_name)
		if event_name == nil then return end

		local map = GetBroadcastEventsMap(inst, false)
		if not map then return end

		return map.tocode[event_name]
	end

	local function GetEventFromCode(inst, event_code)
		if event_code == nil then return end

		local map = GetBroadcastEventsMap(inst, false)
		if not map then return end

		return map.fromcode[event_code]
	end

	netvar_dirty_handler = function(inst, netvar)
		for _, code in ipairs(netvar.value) do
			local event_name = GetEventFromCode(inst, code)
			if not event_name then
				TheMod:Warn("The broadcast event code ", tostring(code), " wasn't registered for entity [", inst, "]")
			else
				basic_PushBroadcastEvent(inst, event_name)
			end
		end
		netvar.local_value = {}
	end

	---

	RegisterBroadcastEvent = function(inst, event_name)
		local map = GetBroadcastEventsMap(inst, true)
		if map.tocode[event_name] == nil then
			table.insert(map.fromcode, event_name)
			map.tocode[event_name] = #map.fromcode
		end
	end

	---
	
	function ServerRPC.PushBroadcastEvent(player, inst, event_code)
		local event_name = GetEventFromCode(inst, event_code)
		if not event_name then
			TheMod:Warn("The server event code ", tostring(event_code), " wasn't registered for entity [", inst, "]")
			return
		end

		local map = GetBroadcastEventsMap(inst)
		assert( map )

		local queue = map.netvar.value or {}
		table.insert(queue, event_code)

		map.netvar:ForceSync(queue)
	end
	ServerRPC.PushBroadcastEvent:SetInterface(function(inst, event_name)
		local code = GetEventCode(inst, event_name)
		if not code then
			return error("The broadcast event '"..tostring(event_name).."' wasn't registered for entity ["..tostring(inst).."]", 2)
		end
		return inst, code
	end)
else
	RegisterBroadcastEvent = Lambda.Nil

	ServerRPC.PushBroadcastEvent = basic_PushBroadcastEvent
end

---

return RegisterBroadcastEvent
