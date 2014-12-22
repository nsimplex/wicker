local Lambda = wickerrequire "paradigms.functional"
local Reflection = wickerrequire "game.reflection"

local id = assert( modinfo and modinfo.id, "modinfo.id expected" )

local id_matches = Lambda.CompactlyFilter(function(mod)
	local modinfo = mod.modinfo
	if modinfo and modinfo.id == id then
		return true
	end
end, Reflection.EnabledMods())

assert(#id_matches >= 1)

if #id_matches > 1 then
	local folder_list = Lambda.CompactlyMap(function(mod)
		return ("%q"):format(tostring(mod.modname or "???"))
	end, ipairs(id_matches))
	local q_id = ("%q"):format(tostring(id))
	local folders_str = table.concat(folder_list, ", ")
	return error("Multiple enabled mods with id "..q_id..", with mod directories: "..folders_str..".")
end
