--[[
-- Utilities for checking things about the game state.
--]]

function FindActiveMod(testfn)
	for _, mod in ipairs( _G.ModManager.mods ) do
		local its_modinfo = mod.modinfo
		if type(its_modinfo) ~= "table" then
			its_modinfo = (mod.modname and _G.KnownModIndex:GetModInfo(mod.modname))
		end
		if type(its_modinfo) == "table" and testfn( its_modinfo, mod ) then
			return its_modinfo, mod
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

function IsModEnabled(id_or_name)
	return FindActiveMod(function(info)
		return info.id == id_or_name or info.name == id_or_name
	end) ~= nil
end

EnableModInCache = (function()
	local did_enable = false

	return function(cb)
		if did_enable then
			cb()
			return
		end

		local moddir = modenv.modname
		local KnownModIndex = rawget(_G, "KnownModIndex")
		assert(KnownModIndex)
		if not KnownModIndex then return end

		did_enable = true
		KnownModIndex:Enable(moddir)
		KnownModIndex:Save(cb)
	end
end)()
