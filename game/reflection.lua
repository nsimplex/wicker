--[[
-- Utilities for checking things about the game state.
--]]

function FindActiveMod(testfn)
	for _, moddir in ipairs( _G.ModManager:GetEnabledModNames() ) do
		local its_modinfo = _G.KnownModIndex:GetModInfo(moddir)
		if testfn( its_modinfo, moddir ) then
			return its_modinfo, moddir
		end
	end
end

function HasModWithName(name)
	return FindActiveMod(function(info)
		return info.name == name
	end) ~= nil
end

function HasModWithId(id)
	return FindActiveMod(function(info)
		return info.id == id
	end) ~= nil
end
