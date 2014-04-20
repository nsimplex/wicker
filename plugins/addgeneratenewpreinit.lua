local Lambda = wickerrequire "paradigms.functional"
local FunctionQueue = wickerrequire "gadgets.functionqueue"


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
	local did_patch = false

	local json = require "json"

	json.decode = (function()
		local decode = json.decode

		return function(...)
			if not did_patch then
				local generate_new = rawget(_G, "GenerateNew")
				if generate_new then
					_G.GenerateNew = PatchGenerateNew(generate_new)
					did_patch = true
					json.decode = decode
				end
			end
			return decode(...)
		end
	end)()
else
	AddGenerateNewPreInit = Lambda.Nil
end


TheMod:EmbedHook("AddGenerateNewPreInit", AddGenerateNewPreInit)
