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

local PseudoClock = pkgrequire "dst_abstraction.pseudoclock"
local PseudoSeasonManager = pkgrequire "dst_abstraction.pseudoseasonmanager"

local IsDST = assert(IsDST)
local IsHost = assert(IsHost)

---

local modauthor = setmetatable({}, {
	__tostring = function()
		return modinfo.author
	end,
})

---

local function method_redirector(selffn, k)
	return function(pseudoself, ...)
		local self = selffn(pseudoself)
		return self[k](self, ...)
	end
end

local function forbidden_thing(what, k, badcase)
	badcase = badcase or "multiplayer"
	return Lambda.Error("The ", what, " ", k, " is not ", badcase, " friendly. Please report this blasphemy to this mod's author, ", modauthor, ". Make sure to attach your log.txt in the report.")
end

local forbidden_function = Lambda.BindFirst(forbidden_thing, "function")
local forbidden_method = Lambda.BindFirst(forbidden_thing, "method")

local function make_restricted_object(selffn, baseclass, restrictiontemplate, badcase)
	local pseudoself = {}
	for k, v in public_pairs(baseclass) do
		if type(v) ~= "function" then
			pseudoself[k] = v
		elseif restrictiontemplate[k] then
			pseudoself[k] = method_redirector(selffn, k)
		else
			pseudoself[k] = forbidden_method(k, badcase)
		end
	end
	setmetatable(pseudoself, {
		__index = function(_, k)
			return selffn(pseudoself)[k]
		end,
		__newindex = function(_, k, v)
			selffn(pseudoself)[k] = v
		end,
	})
	return pseudoself
end

local function HostClass(...)
	local C = Class(...)
	if not IsHost() then
		C._ctor = Lambda.LeveledError(2)("Attempt to create a host-only class in a client game. Please report this blasphemy to this mod's author, ", modauthor, ". Make sure to attach your log.txt in the report.")
	end
	return C
end

---

return function()
	-- There are already set in init/kernel_components/basic_utilities.lua:
	--
	-- IsDST (aka IsMultiplayer)
	-- IsSingleplayer
	-- IsMasterSimulation
	
	local _G = _G

	---

	local function AddKernelLazyVariable(k, fn)
		return AddLazyVariableTo(_M, k, fn)
	end

	---
	
	_M.HostClass = HostClass

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

	SetPause = forbidden_function("SetPause")

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
			pseudoclock = make_restricted_object(_G.GetClock, Clock, PseudoClock)
			pseudoseasonmanager = make_restricted_object(_G.GetSeasonManager, SeasonManager, PseudoSeasonManager)
		end
	end
	function GetPseudoClock()
		return pseudoclock
	end
	function GetPseudoSeasonManager()
		return pseudoseasonmanager
	end
	GetClock = forbidden_function("GetClock")
	GetSeasonManager = forbidden_function("GetSeasonManager")
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
