local Lambda = wickerrequire "paradigms.functional"

local coroutine = coroutine
local IsMasterSimulation = IsMasterSimulation

if not IsDST() then
	SetupNetwork = Lambda.Nil
	return
end

---

local function WrapPrefabConstructor(fn)
	return function(Sim)
		local co = coroutine.create(fn)

		local status, inst = coroutine.resume(co, Sim)
		if not status then
			-- In this case, inst is actually the error msg.
			return error(inst, 0)
		end

		return inst
	end
end

function SetupNetwork(inst)
	if inst.Network then
		return error("Calling SetupNetwork on entity ["..tostring(inst).."], which already has networking setup.", 2)
	end

	inst.entity:AddNetwork()

	if not IsMasterSimulation() then
		coroutine.yield(inst)
	end

	inst.entity:SetPristine()
end

local function ProcessModPrefab(prefab)
	if prefab.fn then
		prefab.fn = WrapPrefabConstructor(prefab.fn)
	end
end

---

local ModManager = assert(_G.ModManager)

ModManager.RegisterPrefabs = (function()
	local RegisterPrefabs = assert(ModManager.RegisterPrefabs)

	return function(self, ...)
		local rets = {RegisterPrefabs(self, ...)}

		local mod_prefabs = assert(modenv.Prefabs)
		for k, prefab in pairs(mod_prefabs) do
			ProcessModPrefab(prefab)
		end

		return unpack(rets)
	end
end)()
