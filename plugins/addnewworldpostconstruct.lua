local Lambda = wickerrequire "paradigms.functional"
local FunctionQueue = wickerrequire "gadgets.functionqueue"

wickerrequire "plugins.addworldgenmainpostload"


local AddNewWorldPostConstruct

if IsWorldgen() then
	local postconstructs = FunctionQueue()

	TheMod:AddWorldgenMainPostLoad(function()
		local check_save = _G.CheckMapSaveData
		_G.CheckMapSaveData = function(savedata, ...)
			postconstructs(savedata, ...)
			return check_save(savedata, ...)
		end
	end)

	AddNewWorldPostConstruct = function(fn)
		table.insert(postconstructs, fn)
	end
else
	AddNewWorldPostConstruct = Lambda.Nil
end

TheMod:EmbedHook("AddNewWorldPostConstruct", AddNewWorldPostConstruct)
