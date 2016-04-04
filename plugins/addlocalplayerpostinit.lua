local FunctionQueue = wickerrequire "gadgets.functionqueue"

local postinits = FunctionQueue()

if IsSingleplayer() then
	TheMod:AddPrefabPostInit("world", function()
		assert( _G.GetLocalPlayer() == nil )
		local player_prefab = _G.SaveGameIndex:GetSlotCharacter()
		assert(player_prefab)
	 
		--[[
		-- UPDATE: This should be good
		--
		-- Unfortunately, we can't add new postinits by now. So we have to do
		-- it the hard way...
	 
		_G.TheSim:LoadPrefabs( {player_prefab} )
		local oldfn = _G.Prefabs[player_prefab].fn
		_G.Prefabs[player_prefab].fn = function(Sim)
			local inst = oldfn(Sim)
			postinits(inst)
			return inst
		end
		]]--

		TheMod:AddGenericPrefabPostInit(player_prefab, postinits)
	end)
elseif not IsDedicated() then
	local function OnSetOwner(inst)
		if inst == _G.ThePlayer then
			postinits(inst)
		end
	end

	TheMod:AddPlayerPostInit(function(player)
		player:ListenForEvent("setowner", OnSetOwner)
	end)
end

local function AddLocalPlayerPostInit(fn)
	table.insert(postinits, fn)
end
TheMod:EmbedHook("AddLocalPlayerPostInit", AddLocalPlayerPostInit)
