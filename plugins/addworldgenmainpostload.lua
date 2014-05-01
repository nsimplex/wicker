local Lambda = wickerrequire "paradigms.functional"
local FunctionQueue = wickerrequire "gadgets.functionqueue"


local AddWorldgenMainPostLoad

if IsWorldgen() then
	local postloads = FunctionQueue()

	local json = require "json"

	json.decode = (function()
		local decode = json.decode

		local did_patch = false

		return function(...)
			if not did_patch then
				local generate_new = rawget(_G, "GenerateNew")
				if generate_new then
					postloads()
					postloads = nil
					did_patch = true
					json.decode = decode
				end
			end
			return decode(...)
		end

	end)()

	AddWorldgenMainPostLoad = function(fn)
		table.insert(postloads, fn)
	end
else
	AddWorldgenMainPostLoad = Lambda.Nil
end


TheMod:EmbedHook("AddWorldgenMainPostLoad", AddWorldgenMainPostLoad)
TheMod:EmbedHook("AddWorldGenMainPostLoad", AddWorldgenMainPostLoad)
