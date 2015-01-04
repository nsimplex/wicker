local Lambda = wickerrequire "paradigms.functional"
local FunctionQueue = wickerrequire "gadgets.functionqueue"

local postconstructs = FunctionQueue()

local function AddParamsPostConstruct(fn)
	table.insert(postconstructs, fn)
end

local function PatchJsonEncode(encode)
	local type = type

	local depth = 0

	local function process_encoded_data(...)
		depth = depth - 1
		return ...
	end

	return function(data, ...)
		if depth == 0 and type(data) == "table" and data.level_type ~= nil then
			postconstructs(data, ...)
		end

		depth = depth + 1
		return process_encoded_data(encode(data, ...))
	end
end

local function PatchWGenScreenCtor(ctor)
	return function(self, ...)
		require "json"
		local old_encode = _G.json.encode
		_G.json.encode = PatchJsonEncode(old_encode)

		ctor(self, ...)

		_G.json.encode = old_encode
	end
end

if not IsWorldgen() then
	local WGenScreen = require "screens/worldgenscreen"
	WGenScreen._ctor = PatchWGenScreenCtor(WGenScreen._ctor)
else
	AddParamsPostConstruct = Lambda.Nil
end


TheMod:EmbedHook("AddWorldgenParametersPostConstruct", AddParamsPostConstruct)
