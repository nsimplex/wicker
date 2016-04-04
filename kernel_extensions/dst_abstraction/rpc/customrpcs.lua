if IsWorldgen() then
	return
end

local Lambda = wickerrequire "paradigms.functional"
local Pred = wickerrequire "lib.predicates"

local Common = pkgrequire "common"

local AddModRPCHandler
local GetModRPCHandler
local SendModRPCToServer
if IsDST() then
	local code_key = {}

	local function GetModRPCCode(inst)
		local v = (inst or _G.TheWorld.net)[code_key].value
		if v <= 0 then
			return error("No mod RPC dispatcher code configured for '"..tostring(modinfo.name).."'.")
		end
		return v
	end

	local function SetModRPCCode(code, inst)
		(inst or _G.TheWorld.net)[code_key].value = code
	end

	---

	local mod_rpcs = {}

	local mod_rpc_codemap = {}

	AddModRPCHandler = function(name, fn)
		if not Pred.IsCallable(fn) then
			return error("Function expected as mod RPC handler '"..tostring(name).."'")
		end
		if mod_rpc_codemap[name] == nil then
			table.insert(mod_rpcs, fn)
			local subcode = #mod_rpcs
			mod_rpc_codemap[name] = subcode
		else
			mod_rpcs[mod_rpc_codemap[name]] = fn
		end
	end

	GetModRPCHandler = function(name)
		local subcode = mod_rpc_codemap[name]
		if subcode ~= nil then
			return assert(mod_rpcs[subcode]), subcode
		end
	end

	SendModRPCToServer = function(subcode, ...)
		return _G.SendRPCToServer(GetModRPCCode(), subcode, ...)
	end

	---

	local function ModRPC_dispatcher(player, subcode, ...)
		local handler = mod_rpcs[subcode]
		if handler == nil then
			return error("No custom mod RPC registed for subcode "..tostring(subcode))
		end
		if TheMod:Debug() then
			for name, n in pairs(mod_rpc_codemap) do
				if n == subcode then
					TheMod:Say("Received RPC '", name, "'.")
					break
				end
			end
		end
		return handler(player, ...)
	end

	-- inst is the world_network entity.
	local function SetupModRPCs(inst)
		local code
		local RPC_HANDLERS = Common.GetVanillaRPCHandlers()
		if IsServer() then
			code = #RPC_HANDLERS + 1
			assert(RPC_HANDLERS[code] == nil)
			SetModRPCCode(code, inst)
		else
			code = GetModRPCCode(inst)
		end

		if RPC_HANDLERS[code] == nil then
			RPC_HANDLERS[code] = ModRPC_dispatcher
		end
	end

	TheMod:AddPrefabPostInitAny(function(inst)
		local TheWorld = assert( _G.TheWorld )
		if inst ~= TheWorld.net then return end

		if #mod_rpcs == 0 then
			TheMod:Say("Mod '", modinfo.name, "' hasn't added custom RPCs, skipping hook.")
			return
		end
		TheMod:Say("Hooking custom RPCs for mod '", modinfo.name, "'.")
		local netvar = NetShortUInt(inst, modinfo.id..".rpc_code")
		inst[code_key] = netvar
		if IsServer() then
			SetupModRPCs(inst)
		else
			netvar:AddOnDirtyFn(SetupModRPCs)
		end
	end)
else
	local mod_rpc_map = {}

	AddModRPCHandler = function(name, fn)
		mod_rpc_map[name] = fn
	end

	GetModRPCHandler = function(name)
		local fn = mod_rpc_map[name]
		if fn ~= nil then
			return fn, name
		end
	end

	SendModRPCToServer = function(subcode, ...)
		-- Here, subcode is actually the method's name.
		local fn = mod_rpc_map[subcode]
		if fn == nil then
			return error("No custom mod fake RPC registed for name '"..tostring(subcode).."'")
		end
		fn(GetLocalPlayer(), ...)
	end
end

return {
	AddModRPCHandler = AddModRPCHandler,
	GetModRPCHandler = GetModRPCHandler,
	SendModRPCToServer = SendModRPCToServer,
}
