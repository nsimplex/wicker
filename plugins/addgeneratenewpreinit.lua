local Lambda = wickerrequire "paradigms.functional"
local FunctionQueue = wickerrequire "gadgets.functionqueue"

wickerrequire "plugins.addworldgenmainpostload"



local preinits = FunctionQueue()

local function AddGenerateNewPreInit(fn)
	table.insert(preinits, fn)
end


local function PatchGenerateNew(generate_new)
	return function(debug, parameters, ...)
		preinits(parameters, ...)
		return generate_new(debug, parameters, ...)
	end
end


if IsWorldgen() then
	TheMod:AddWorldgenMainPostLoad(function()
		local generate_new = _G.GenerateNew
		_G.GenerateNew = PatchGenerateNew(generate_new)
	end)
else
	AddGenerateNewPreInit = Lambda.Nil
end


TheMod:EmbedHook("AddGenerateNewPreInit", AddGenerateNewPreInit)
