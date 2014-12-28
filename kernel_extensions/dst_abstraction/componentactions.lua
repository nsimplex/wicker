--[[
-- IMPORTANT:
-- The modinfo.id is being hacked in place of 'modname' for identification.
--]]

local Lambda = wickerrequire "paradigms.functional"

if IsWorldgen() then
	init = Lambda.Nil
	return _M
end

local Rest = pkgrequire "restriction"

---

if IsDST() then
	require "entityscript"

	local SHOULD_FAKE_SERVER_MODNAMES = false

	_G.ModManager.GetServerModsNames = (function()
		local GetServerModsNames = assert( _G.ModManager.GetServerModsNames )

		local modname = assert( modenv.modname )
		local id = assert( modinfo.id )

		local function modname_mapper(name)
			if name == modname then
				return id
			else
				return name
			end
		end

		return function(self, ...)
			local modlist = GetServerModsNames(self, ...)
			if SHOULD_FAKE_SERVER_MODNAMES then
				return Lambda.CompactlyMap(modname_mapper, ipairs(modlist))
			else
				return modlist
			end
		end
	end)()

	_G.Entity.AddNetwork = (function()
		local AddNetwork = _G.Entity.AddNetwork

		return function(self)
			SHOULD_FAKE_SERVER_MODNAMES = true
			local ret = AddNetwork(self)
			SHOULD_FAKE_SERVER_MODNAMES = false
			return ret
		end
	end)()
end

---

-- Maps DST's action type IDs to DS's component method names.
local actiontype_map = {
	EQUIPPED = "CollectEquippedActions",
	INVENTORY = "CollectInventoryActions",
	POINT = "CollectPointActions",
	SCENE = "CollectSceneActions",
	USEITEM = "CollectUseActions",

	ISVALID = "IsActionValid",
}

local function ActionTypeToMethodName(actiontype)
	local name = actiontype_map[actiontype]
	if name == nil then
		return error("Invalid action type '"..tostring(actiontype).."'.", 2)
	end
	return name
end

local GetComponentActions
if IsDST() then
	GetComponentActions = memoize_0ary(function()
		require "entityscript"
		require "componentactions"
		local Reflection = wickerrequire "game.reflection"
		return assert(Reflection.RequireUpvalue(_G.EntityScript.CollectActions, "COMPONENT_ACTIONS"))
	end)
else
	GetComponentActions = Rest.ForbiddenFunction("GetComponentActions", "singleplayer")
end

local GetModComponentActions
if IsDST() then
	GetModComponentActions = memoize_0ary(function()
		require "entityscript"
		require "componentactions"
		local Reflection = wickerrequire "game.reflection"
		return assert(Reflection.RequireUpvalue(_G.AddComponentAction, "MOD_COMPONENT_ACTIONS"))
	end)
else
	GetModComponentActions = Rest.ForbiddenFunction("GetModComponentActions", "singleplayer")
end

local GetActionComponentIDs
if IsDST() then
	GetActionComponentIDs = memoize_0ary(function()
		require "entityscript"
		require "componentactions"
		local Reflection = wickerrequire "game.reflection"
		return Reflection.RequireUpvalue(_G.EntityScript.RegisterComponentActions, "ACTION_COMPONENT_IDS")
	end)
else
	GetActionComponentIDs = Rest.ForbiddenFunction("GetActionComponentIDs", "singleplayer")
end

local GetModActionComponentIDs
if IsDST() then
	GetModActionComponentIDs = memoize_0ary(function()
		require "entityscript"
		require "componentactions"
		local Reflection = wickerrequire "game.reflection"
		return Reflection.RequireUpvalue(_G.AddComponentAction, "MOD_ACTION_COMPONENT_IDS")
	end)
else
	GetModActionComponentIDs = Rest.ForbiddenFunction("GetModActionComponentIDs", "singleplayer")
end

local GetActionComponentNames
if IsDST() then
	GetActionComponentNames = memoize_0ary(function()
		require "entityscript"
		require "componentactions"
		local Reflection = wickerrequire "game.reflection"
		return Reflection.RequireUpvalue(_G.EntityScript.CollectActions, "ACTION_COMPONENT_NAMES")
	end)
else
	GetActionComponentNames = Rest.ForbiddenFunction("GetActionComponentNames", "singleplayer")
end

local GetModActionComponentNames
if IsDST() then
	GetModActionComponentNames = memoize_0ary(function()
		require "entityscript"
		require "componentactions"
		local Reflection = wickerrequire "game.reflection"
		return Reflection.RequireUpvalue(_G.AddComponentAction, "MOD_ACTION_COMPONENT_NAMES")
	end)
else
	GetModActionComponentNames = Rest.ForbiddenFunction("GetModActionComponentNames", "singleplayer")
end

---

local AddComponentAction, PatchComponentAction
if IsDST() then
	assert(modenv.AddComponentAction)
	assert(TheMod.AddComponentAction)

	AddComponentAction = function(actiontype, cmp_name, fn)
		return _G.AddComponentAction(actiontype, cmp_name, fn, modinfo.id)
	end

	PatchComponentAction = function(actiontype, cmp_name, patcher)
		local cas = GetComponentActions()
		local subcas = cas[actiontype]

		if not subcas then
			return AddComponentAction(actiontype, cmp_name, patcher(nil, actiontype, cmp_name))
		end
		
		local fn = subcas[cmp_name]
		subcas[cmp_name] = patcher(fn, actiontype, cmp_name)
	end
else
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

---

local HasActionComponent
if IsDST() then
	local set_key = {}
	local dirty_set_key = {}

	---

	local function genericUpdateActionComponentSet(set, id_list, id_map, value)
		local current_ids = {}
		for _, id in ipairs(id_list) do
			current_ids[id] = true
		end

		for k, v in pairs(set) do
			if v == value and not current_ids[id_map[k]] then
				set[k] = nil
			end
		end

		for id, k in pairs(id_map) do
			if current_ids[id] and set[k] == nil then
				set[k] = value
			end
		end
	end

	---
	
	local function updateActionComponentSet(inst)
		local set = assert( inst[set_key] )

		local id_map = GetActionComponentIDs()

		return genericUpdateActionComponentSet(set, inst.actioncomponents, id_map, true)
	end

	local function updateModActionComponentSet(inst, mod_name)
		assert( mod_name )
		local set = assert( inst[set_key] )

		local id_list = inst.modactioncomponents[mod_name]
		if id_list == nil then return end

		local id_map = GetModActionComponentIDs()[mod_name]
		if id_map == nil then return end

		return genericUpdateActionComponentSet(set, id_list, id_map, mod_name)
	end

	local function cleanDirtySets(inst)
		local set = inst[dirty_set_key]
		if set == nil then return end

		for k in pairs(set) do
			if k == 1 then
				updateActionComponentSet(inst)
			else
				updateModActionComponentSet(inst, k)
			end
		end

		inst[dirty_set_key] = nil
	end

	local function flagDirtyActionComponentSet(inst)
		local set = inst[dirty_set_key]
		if set == nil then
			set = {nil}
			inst[dirty_set_key] = set
		end
		set[1] = true
	end

	local getDirtyModActionComponentSetFlagger = (function()
		local cache = {}

		return function(mod_name)
			local ret = cache[mod_name]
			if ret == nil then
				ret = function(inst)
					local set = inst[dirty_set_key]
					if set == nil then
						set = {_ = nil}
						inst[dirty_set_key] = set
					end
					set[mod_name] = true
				end
				cache[mod_name] = ret
			end
			return ret
		end
	end)()

	local function initializeActionComponentSet(inst)
		if inst.actionreplica then
			inst:ListenForEvent("actioncomponentsdirty", flagDirtyActionComponentSet)
			for modname in pairs(inst.actionreplica.modactioncomponents) do
				inst:ListenForEvent("modactioncomponentsdirty"..modname, getDirtyModActionComponentSetFlagger(modname))
			end
		end

		updateActionComponentSet(inst)
		if inst.modactioncomponents then
			for modname in pairs(inst.modactioncomponents) do
				updateModActionComponentSet(inst, modname)
			end
		end
	end

	HasActionComponent = function(inst, cmp_name)
		local set = inst[set_key]
		if set == nil then
			set = {}
			inst[set_key] = set
			initializeActionComponentSet(inst)
		else
			cleanDirtySets(inst)
		end
		return set[cmp_name] and true or false
	end
else
	HasActionComponent = function(inst, cmp_name)
		return inst.components[cmp_name] ~= nil
	end
end

---

function init(kernel)
	kernel.GetComponentActions = GetComponentActions
	kernel.GetModComponentActions = GetModComponentActions
	kernel.GetActionComponentIDs = GetActionComponentIDs
	kernel.GetModActionComponentIDs = GetModActionComponentIDs
	kernel.GetActionComponentNames = GetActionComponentNames
	kernel.GetModActionComponentNames = GetModActionComponentNames

	kernel.ActionTypeToMethodName = ActionTypeToMethodName
	kernel.HasActionComponent = HasActionComponent
end
