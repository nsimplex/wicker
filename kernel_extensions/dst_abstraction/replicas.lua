local Lambda = wickerrequire "paradigms.functional"

if IsWorldgen() then
	init = Lambda.Nil
	return _M
end

---

local AddReplicatableComponent
local get_replica
if IsDST() then
	local get_repcmps_table = memoize_0ary(function()
		local Reflection = wickerrequire "game.reflection"

		require "entityscript"
		require "entityreplica"

		return Reflection.RequireUpvalue(_G.EntityScript.ReplicateComponent, "REPLICATABLE_COMPONENTS")
	end)

	AddReplicatableComponent = function(name)
		get_repcmps_table()[name] = true
	end

	get_replica = function(inst)
		return inst.replica
	end
else
	local REPLICA_KEY = {}

	---
	
	local replicatable_set = {}

	AddReplicatableComponent = function(name)
		if replicatable_set[name] then return end
		replicatable_set[name] = true

		local cmp_pkgname = "components/"..name

		local replica_cmp = require(cmp_pkgname.."_replica")

		TheMod:AddClassPostConstruct(cmp_pkgname, function(self)
			self[REPLICA_KEY] = replica_cmp(self.inst)
		end)
	end
	
	---
	
	local new_virtual_replica = (function()
		local meta = {
			__index = function(t, k)
				local inst = t[t]
				local cmp = inst.components[k]
				return cmp ~= nil and cmp[REPLICA_KEY] or cmp
			end,
		}
		return function(inst)
			local t = {}
			t[t] = inst
			return setmetatable(t, meta)
		end
	end)()

	get_replica = function(inst)
		local ret = inst[REPLICA_KEY]
		if ret == nil then
			ret = new_virtual_replica(inst)
			inst[REPLICA_KEY] = ret
		end
		return ret
	end
end

TheMod:EmbedAdder("ReplicatableComponent", AddReplicatableComponent)

function init(kernel)
	kernel.replica = get_replica
end
