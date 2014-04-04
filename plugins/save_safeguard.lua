assert( type(modinfo) == "table" )
assert( type(modinfo.id) == "string", "String expected as `id' field of modinfo.lua." )


------------------------------------------------------------------------


--[[
-- This runs when savedata is processed.
-- It runs in the global environment.
--
-- Do NOT place references to anything outside of this function.
-- Use only things in the global environment and defined in the function
-- itself.
--]]
local function onload(mod_id, mod_prettyname, mod_shorthand)
	pcall(function()
		mod_prettyname = tostring(mod_prettyname)
		mod_shorthand = tostring(mod_shorthand or "Mod")

		local function IsThisMod(moddir)
			local modinfo = KnownModIndex:GetModInfo(moddir)
			return modinfo and modinfo.id == mod_id
		end

		local function IsThisModEnabled()
			for _, moddir in ipairs( ModManager:GetEnabledModNames() ) do
				if IsThisMod(moddir) then
					return true
				end
			end
			return false
		end

		if not IsThisModEnabled() then
			local oldDoInitGame = DoInitGame

			local function get_thismods()
				local ret = {}
				for _, moddir in ipairs(KnownModIndex:GetModNames()) do
					if IsThisMod(moddir) then
						table.insert(ret, moddir)
					end
				end
				return ret
			end

			_G.DoInitGame = function(...)
				local args = {...}
				
				local status = pcall(function()
					local ScriptErrorScreen = require "screens/scripterrorscreen"

					local buttons = {
						{text = "Main Menu", cb = function()
							if rawget(_G, "EnableAllDLC") then
								-- This is needed for the DLC main screen to be shown.
								EnableAllDLC()
							end
							StartNextInstance()
						end},
						{text = "Ignore", cb = function()
							TheFrontEnd:PopScreen()
							oldDoInitGame(unpack(args))
						end},
					}

					local thismods = get_thismods()
					if #thismods == 1 then
						table.insert(buttons, 1, {text = "Enable "..mod_shorthand, cb = function()
							KnownModIndex:Enable(thismods[1])
							KnownModIndex:Save(function()
								StartNextInstance(Settings)
							end)
						end})
					end

					TheFrontEnd:ShowScreen(ScriptErrorScreen(
						"HIC SUNT DRACONES!",
						("This save was last played with the mod %s enabled. It is STRONGLY RECOMMENDED that you DO NOT play this save with it disabled, at the risk of data loss and a permanently broken save."):format(mod_prettyname),
						buttons,
						ANCHOR_MIDDLE,
						("Please consider reenabling %s before running this save."):format(mod_prettyname),
						30
					))
				end)

				if not status then
					pcall(function() TheFrontEnd:ClearScreens() end)
					oldDoInitGame(unpack(args))
				end
			end
		end
	end)
end
setfenv(onload, _G)


------------------------------------------------------------------------


local mod_shorthand = "Mod"

require "mainfunctions"
_G.SavePersistentString = (function()
	local SavePersistentString = _G.SavePersistentString

	return function(name, data, ...)
		if SaveGameIndex:GetCurrentMode() ~= "adventure" then
			local status, parent_info = pcall(debug.getinfo, 3, 'f')

			if status and parent_info and parent_info.func == _G.SaveGame then
				data = ("loadstring(%q)(%q, %q, %q);\n"):format(
					assert( string.dump(onload) ),
					assert( modinfo.id ),
					assert( modinfo.name ),
					tostring( mod_shorthand or "Mod" )
				)..data
			end
		end
		return SavePersistentString(name, data, ...)
	end
end)()

------------------------------------------------------------------------

return function(new_mod_shorthand)
	mod_shorthand = tostring(new_mod_shorthand or "Mod")
end
