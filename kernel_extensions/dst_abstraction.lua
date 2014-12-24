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
local FunctionQueue = wickerrequire "gadgets.functionqueue"

pkgrequire "dst_abstraction.assumptions"

local Rest = pkgrequire "dst_abstraction.restriction"

local PseudoClock = pkgrequire "dst_abstraction.pseudoclock"
local PseudoSeasonManager = pkgrequire "dst_abstraction.pseudoseasonmanager"

local PrefabConstructor = pkgrequire "dst_abstraction.prefab_constructor"

local CmpActions = pkgrequire "dst_abstraction.componentactions"
local Reps = pkgrequire "dst_abstraction.replicas"

local NetVars = pkgrequire "dst_abstraction.netvars"
local ModRPC = pkgrequire "dst_abstraction.rpc"

local IsDST = assert(IsDST)

---

local AddLocalPlayerPostActivation
if IsWorldgen() then
	AddLocalPlayerPostActivation = Lambda.Nil
elseif IsDST() then
	local postactivations = FunctionQueue()

	TheMod:AddPrefabPostInit("world", function(wrld)
		wrld:ListenForEvent("playeractivated", function(wlrd, player)
			if player == _G.ThePlayer then
				postactivations(player)
				postactivations = nil
			end
		end)
	end)

	AddLocalPlayerPostActivation = function(fn)
		if postactivations ~= nil then
			table.insert(postactivations, fn)
		else
			return fn( assert(_G.ThePlayer) )
		end
	end
else
	local doAddLocalPlayerPostActivation = assert(modenv.AddSimPostInit)

	doAddLocalPlayerPostActivation(function()
		doAddLocalPlayerPostActivation = nil
	end)

	AddLocalPlayerPostActivation = function(fn)
		if doAddLocalPlayerPostActivation ~= nil then
			return doAddLocalPlayerPostActivation(fn)
		else
			return fn( assert(_G.GetPlayer()) )
		end
	end
end
TheMod:EmbedHook("LocalPlayerPostActivation", AddLocalPlayerPostActivation)

---

return function()
	-- These are already set in init/kernel_components/basic_utilities.lua:
	--
	-- IsDST (aka IsMultiplayer)
	-- IsSingleplayer
	-- IsMasterSimulation
	
	if IsWorldgen() then
		return
	end

	local _G = _G
	local _M = _M

	Rest.init(_M)
	PrefabConstructor.init(_M)
	CmpActions.init(_M)
	Reps.init(_M)
	NetVars.init(_M)
	ModRPC.init(_M)

	---

	local function AddKernelLazyVariable(k, fn)
		return AddLazyVariableTo(_M, k, fn)
	end

	---
	
	_M.HostClass = Rest.HostClass

	---
	
	if IsDST() then
		-- haaaack
		local AddAction = assert(modenv.AddAction)
		TheMod:EmbedAdder("Action", function(...)
			local old_modname = modenv.modname
			local tmp_modname
			if modinfo.id then
				tmp_modname = modinfo.id
			else
				tmp_modname = modenv.modname
			end
			modenv.modname = tmp_modname
			local act = AddAction(...)
			modenv.modname = old_modname
			assert(act.mod_name == tmp_modname, "Logic error.")
		end)
	end

	---

	if IsDST() then
		function GetLocalPlayer()
			return _G.ThePlayer
		end
	else
		GetLocalPlayer = _G.GetPlayer
		AddKernelLazyVariable("ThePlayer", GetLocalPlayer)
	end
	AddKernelLazyVariable("TheLocalPlayer", GetLocalPlayer)

	GetPlayer = Lambda.Error("GetPlayer() must not be used.")

	if IsDST() then
		function GetWorld()
			return _G.TheWorld
		end
	else
		GetWorld = _G.GetWorld
		AddKernelLazyVariable("TheWorld", GetWorld)
	end

	if IsDST() then
		TryPause = Lambda.Nil
	else
		TryPause = function(b)
			return _G.SetPause(b)
		end
	end

	SetPause = Rest.ForbiddenFunction("SetPause")

	require "recipe"
	if IsDST() then
		AllRecipes = _G.AllRecipes
	else
		AllRecipes = _G.Recipes
	end
	Recipes = AllRecipes

	if IsDST() then
		function GetRecipe(name)
			return _G.AllRecipes[name]
		end
	else
		AddKernelLazyVariable("GetRecipe", function()
			require "recipe"
			return _G.GetRecipe
		end)
	end

	if VarExists "Label" then
		local Label = _G.Label

		local method_names = {"SetPos", "SetPosition", "SetUIOffset"}

		local method = nil
		for _, name in ipairs(method_names) do
			local v = Label[name]
			if v ~= nil then
				method = v
				break
			end
		end
		assert(method, "Unable to find method equivalent to singleplayer's inst.Label:SetPos(x, y, z).")

		for _, name in ipairs(method_names) do
			if Label[name] == nil then
				Label[name] = method
			end
		end
	end

	---

	SendRPCToServer = Rest.ForbiddenFunction("SendRPCToServer", "singleplayer")

	---

	assert(not VarExists("TheWorld"))
	local pseudoclock, pseudoseasonmanager
	local pseudo_initializer -- takes the world entity as argument
	if IsDST() then
		pseudo_initializer = function(inst)
			pseudoclock = PseudoClock(inst)
			pseudoseasonmanager = PseudoSeasonManager(inst)
		end
	else
		pseudo_initializer = function()
			local Clock = require "components/clock"
			local SeasonManager = require "components/seasonmanager"
			pseudoclock = Rest.MakeRestrictedObject(_G.GetClock, Clock, PseudoClock)
			pseudoseasonmanager = Rest.MakeRestrictedObject(_G.GetSeasonManager, SeasonManager, PseudoSeasonManager)
		end
	end
	function GetPseudoClock()
		return pseudoclock
	end
	function GetPseudoSeasonManager()
		return pseudoseasonmanager
	end
	GetClock = Rest.ForbiddenFunction("GetClock")
	GetSeasonManager = Rest.ForbiddenFunction("GetSeasonManager")
	TheMod:AddPostRun(function(mainname)
		if mainname ~= "main" then return end
		TheMod:AddPrefabPostInit("world", function(inst)
			if pseudo_initializer then
				assert(TheWorld == nil or inst == TheWorld)
				pseudo_initializer(inst)
				pseudo_initializer = nil
			end
		end)
	end)

	---

	if IsDST() then
		function AddNetwork(inst)
			return inst.entity:AddNetwork()
		end
	else
		AddNetwork = Lambda.Nil
	end

	if IsDST() then
		function SetPristine(inst)
			inst.entity:SetPristine()
			return inst
		end
	else
		SetPristine = Lambda.Identity
	end
	MakePristine = SetPristine
end
