local Lambda = wickerrequire "paradigms.functional"

if IsWorldgen() then
	return Lambda.Nil
end

---

assert( ServerRPC )

---

local RegisterServerEvent
local function basic_PushServerEvent(player, inst, event_name)
	inst:PushEvent(event_name, {player = player})
end
if IsDST() then
	local SERVER_EVENTS_KEY = {}

	local function NewServerEventsMap()
		return {
			tocode = {},
			fromcode = {},
		}
	end

	local function GetServerEventsMap(inst, create)
		local ret = inst[SERVER_EVENTS_KEY]
		if ret == nil and create then
			ret = NewServerEventsMap()
			inst[SERVER_EVENTS_KEY] = ret
		end
		return ret
	end

	local function GetEventCode(inst, event_name)
		if event_name == nil then return end

		local map = GetServerEventsMap(inst, false)
		if not map then return end

		return map.tocode[event_name]
	end

	local function GetEventFromCode(inst, event_code)
		if event_code == nil then return end

		local map = GetServerEventsMap(inst, false)
		if not map then return end

		return map.fromcode[event_code]
	end

	---

	RegisterServerEvent = function(inst, event_name)
		local map = GetServerEventsMap(inst, true)
		if map.tocode[event_name] == nil then
			table.insert(map.fromcode, event_name)
			map.tocode[event_name] = #map.fromcode
		end
	end

	---
	
	function ServerRPC.PushServerEvent(player, inst, event_code)
		local event_name = GetEventFromCode(inst, event_code)
		if not event_name then
			TheMod:Warn("The server event code ", tostring(event_code), " wasn't registered for entity [", inst, "]")
			return
		end
		return basic_PushServerEvent(player, inst, event_name)
	end
	ServerRPC.PushServerEvent:SetInterface(function(inst, event_name)
		local code = GetEventCode(inst, event_name)
		if not code then
			return error("The server event '"..tostring(event_name).."' wasn't registered for entity ["..tostring(inst).."]", 2)
		end
		return inst, code
	end)
else
	RegisterServerEvent = Lambda.Nil

	ServerRPC.PushServerEvent = basic_PushServerEvent
end

---

return RegisterServerEvent
