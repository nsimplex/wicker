local Lambda = wickerrequire "paradigms.functional"
local FunctionQueue = wickerrequire "gadgets.functionqueue"

local Rest = pkgrequire "restriction"

local _G = _G
local coroutine = assert( _G.coroutine )
local IsMasterSimulation = assert( IsMasterSimulation )

if not IsDST() then
	init = function(kernel)
		kernel.SetupNetwork = Lambda.Nil
	end
	return _M
end

---

local StartedConstructing, DoneConstructing, IsConstructionThread = (function()
	local thread_set = setmetatable({}, {__mode = "k"})

	local function started(co)
		thread_set[co] = true
	end

	local function done(co)
		thread_set[co] = nil
	end

	local function is_cons(co)
		return co ~= nil and thread_set[co]
	end

	return started, done, is_cons
end)()

local GetPostConstructs, ClearPostConstructs = (function()
	local postconstructs = setmetatable({}, {__mode = "k"})

	local function get(co, dont_create)
		local ret = postconstructs[co]
		if ret == nil and not dont_create then
			ret = FunctionQueue()
			postconstructs[co] = ret
		end
		return ret
	end

	local function clear(co)
		postconstructs[co] = nil
	end

	return get, clear
end)()

local function AddThreadPostConstruct(co, fn)
	if not IsConstructionThread(co) then
		return OuterError("Attempt to attach post construct outside of a construction thread! [co = "..tostring(co).."]")
	end
	table.insert(GetPostConstructs(co), fn)
end

---

local function WrapPrefabConstructor(fn)
	return function(Sim)
		local co = coroutine.create(fn)

		StartedConstructing(co)
		local status, inst = coroutine.resume(co, Sim)
		DoneConstructing(co)

		if not status then
			-- In this case, inst is actually the error msg.
			return error(traceback(co, tostring(inst)), 0)
		end

		local ps = GetPostConstructs(co, true)
		if ps ~= nil then
			ps(inst)
			ClearPostConstructs(co)
		end

		return inst
	end
end

local function SetupNetwork(inst)
	if inst.Network then
		return error("Calling SetupNetwork on entity ["..tostring(inst).."], which already has networking set up.", 2)
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

---

function init(kernel)
	kernel.SetupNetwork = SetupNetwork

	kernel.MakeSnowCovered = function(inst)
		local co = coroutine.running()
		if IsConstructionThread(co) then
			if IsMasterSimulation() then
				if inst.Network then
					return error("Called MakeSnowCovered after SetupNetwork!", 2)
				end
				AddThreadPostConstruct(co, _G.MakeSnowCovered)
			end
			return _G.MakeSnowCoveredPristine(inst)
		else
			return _G.MakeSnowCovered(inst)
		end
	end

	kernel.MakeSnowCoveredPristine = Rest.ForbiddenFunction("MakeSnowCoveredPristine", "singleplayer")
end
