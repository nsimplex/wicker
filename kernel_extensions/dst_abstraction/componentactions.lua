--[[
-- IMPORTANT:
-- The modinfo.id is being hacked in place of 'modname' for identification.
--]]

local Lambda = wickerrequire "paradigms.functional"

init = Lambda.Nil

if IsWorldgen() then
	return _M
end

---

if IsDST() then
	require "entityscript"
	_G.Entity.AddNetwork = (function()
		local AddNetwork = _G.Entity.AddNetwork

		return function(self)
			local ret = AddNetwork(self)

			local inst = assert( _G.Ents[self:GetGUID()] )

			local mac_tbl = inst.actionreplica.modactioncomponents

			local old_mac = assert( mac_tbl[modenv.modname] )
			mac_tbl[modinfo.id] = old_mac
			mac_tbl[modenv.modname] = nil

			return ret
		end
	end)()
end

---

local AddComponentAction, PatchComponentAction
if IsDST() then
	assert(modenv.AddComponentAction)
	assert(TheMod.AddComponentAction)

	AddComponentAction = function(actiontype, cmp_name, fn)
		return _G.AddComponentAction(actiontype, cmp_name, fn, modinfo.id)
	end

	local get_component_actions = memoize_0ary(function()
		require "componentactions"
		local Reflection = wickerrequire "game.reflection"
		return assert(Reflection.RequireUpvalue(_G.EntityScript.CollectActions, "COMPONENT_ACTIONS"))
	end)

	PatchComponentAction = function(actiontype, cmp_name, patcher)
		local cas = get_component_actions()
		local subcas = cas[actiontype]

		if not subcas then
			return AddComponentAction(actiontype, cmp_name, patcher(nil, actiontype, cmp_name))
		end
		
		local fn = subcas[cmp_name]
		subcas[cmp_name] = patcher(fn, actiontype, cmp_name)
	end
else
	-- Maps DST's action type IDs to DS's component method names.
	local actiontype_map = {
		EQUIPPED = "CollectEquippedActions",
		INVENTORY = "CollectInventoryActions",
		POINT = "CollectPointActions",
		SCENE = "CollectSceneActions",
		USEITEM = "CollectUseActions",

		ISVALID = "IsActionValid",
	}

	local function wrapComponentActionFn(fn)
		return function(self, ...)
			return fn(self.inst, ...)
		end
	end

	local function unwrapComponentActionFn(fn, cmp_name)
		return function(inst, ...)
			local cmp = inst.components[cmp_name]
			if cmp then
				return fn(cmp, ...)
			end
		end
	end

	AddComponentAction = function(actiontype, cmp_name, fn)
		local cmp = require("components/"..cmp_name)

		local method_name = actiontype_map[actiontype]
		if method_name == nil then
			return error("Attempt to add component action of invalid action type '"..tostring(actiontype).."' to component '"..cmp_name, 2)
		end

		cmp[method_name] = wrapComponentActionFn(fn)
	end

	PatchComponentAction = function(actiontype, cmp_name, patcher)
		local cmp = require("components/"..cmp_name)
		
		local method_name = actiontype_map[actiontype]

		if method_name then
			local fn = cmp[method_name]
			if fn then
				fn = unwrapComponentActionFn(fn, cmp_name)
			end
			cmp[method_name] = wrapComponentActionFn( patcher(fn, actiontype, cmp_name) )
		end
	end
end

TheMod:EmbedAdder("ComponentAction", AddComponentAction)

function TheMod:PatchComponentAction(...)
	return PatchComponentAction(...)
end

-- Takes a table in the same format as COMPONENT_ACTIONS found in DST's componentactions.lua.
local function AddComponentsActions(data)
	for actiontype, subdata in pairs(data) do
		for cmp_name, fn in pairs(subdata) do
			AddComponentAction(actiontype, cmp_name, fn)
		end
	end
end

TheMod:EmbedAdder("ComponentsActions", AddComponentsActions)
