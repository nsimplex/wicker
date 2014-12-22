if IsWorldgen() then
	return {}
end

---

local Lambda = wickerrequire "paradigms.functional"
local Pred = wickerrequire "lib.predicates"

---

local function uint(name, bitsz)
	return {name = name, tag = "uint", type = "number", bitsz = bitsz, min = 0, max = 2^bitsz - 1}
end

local function int(name, bitsz)
	return {name = name, tag = "int", type = "number", signed = true, modulo = 2^bitsz, min = -2^(bitsz - 1), max = 2^(bitsz - 1) - 1}
end

local function int_pair(s_name, u_name, bitsz)
	return {int(s_name, bitsz), uint(u_name, bitsz)}
end

local function bool()
	return {name = "Bool", tag = "boolean", type = "boolean"}
end

local function float()
	return {name = "Float", tag = "float", type = "number"}
end

local function str()
	return {name = "String", tag = "string", type = "string"}
end

local function entity()
	return {name = "Entity", tag = "entity", type = "entity"}
end

local function array(element)
	if element.tag then
		return {name = element.name.."Array", tag = "array", type = "table", element = element}
	else
		local ret = {}
		for i, v in ipairs(element) do
			table.insert(ret, array(v))
		end
		return ret
	end
end

--[[
local function logic_or(a, b)
	return {type = "choice", a, b}
end
]]--

---

local atomic_net_types = {
	net_bool = {bool()},
	net_byte = int_pair("Byte", "UByte", 8),
	net_entity = {entity()},
	net_float = {float()},
--	net_hash = logic_or(str(), uint(32)),
	net_smallbyte = int_pair("SmallByte", "SmallUByte", 4),
	net_string = {str()},
	net_tinybyte = int_pair("TinyByte", "TinyUByte", 3),
	net_uint = int_pair("Int", "UInt", 32),
	net_ushortint = int_pair("ShortInt", "ShortUInt", 16),
}

---

local array_net_types = {
	net_bytearray = array(atomic_net_types.net_byte),
	net_smallbytearray = array(atomic_net_types.net_smallbyte),
}

---

local IsEntityOrNil = Lambda.Or(Lambda.IsNil, Pred.IsEntityScript)
local function get_arg_validator(spec)
	if spec.tag == "array" then
		return Pred.IsArrayOf( get_arg_validator(spec.element) )
	end
	if spec.type == "string" then
		return Pred.IsWordable
	end
	if spec.type == "entity" then
		return IsEntityOrNil
	end
	return Pred.IsType(spec.type)
end

local function new_clamper(min, max)
	local math_min, math_max = math.min, math.max
	return function(x)
		return math_max(min, math_min(max, x))
	end
end

local math_floor = math.floor
local function round(x)
	return math_floor(x + 0.5)
end

local function get_array_encoder(elem_encoder)
	return function(t)
		local u = {}
		for i, v in ipairs(t) do
			u[i] = elem_encoder(v)
		end
		return u
	end
end
local get_array_decoder = get_array_encoder

local function get_encoder(spec)
	if spec.tag == "array" then
		return get_array_encoder( get_encoder(spec.element) )
	end

	if spec.type == "string" then
		return tostring
	end

	if spec.type ~= "number" or spec.tag == "float" then
		return Lambda.Identity
	end

	local ret = round

	if not spec.min and not spec.max then
		return ret
	end

	if spec.min and spec.max then
		ret = Lambda.Compose(new_clamper(spec.min, spec.max), ret)
	elseif spec.min then
		ret = Lambda.Compose(Lambda.BindFirst(math.max, spec.min), ret)
	else
		ret = Lambda.Compose(Lambda.BindFirst(math.min, spec.max), ret)
	end

	if spec.signed then
		local MODULO = assert(spec.modulo)
		local basic_normalize = ret
		ret = function(x)
			x = basic_normalize(x)
			if x < 0 then
				x = MODULO + x
			end
			return x
		end
	end

	return ret
end

local function get_decoder(spec)
	if spec.tag == "array" then
		return get_array_decoder( get_decoder(spec.element) )
	end

	if not spec.signed then
		return Lambda.Identity
	end

	assert(spec.max)
	assert(spec.modulo)

	local MAX = spec.max
	local m_MODULO = -spec.modulo
	return function(x)
		if x > MAX then
			return x + m_MODULO
		end
	end
end

local function decorate_spec(raw_name, spec)
	spec.raw_net_type = IsDST() and assert(_G[raw_name]) or Lambda.Nil

	spec.validate_arg = get_arg_validator(spec)
	spec.encode = get_encoder(spec)
	spec.decode = get_decoder(spec)

	return spec
end

---

-- The capital "N" denotes the keys are the name of the derivative, high
-- level types.
local Net_types = {}
for _, t in ipairs{atomic_net_types, array_net_types} do
	for raw_name, spec_list in pairs(t) do
		for _, spec in ipairs(spec_list) do
			if IsDST() then
				if not VarExists(raw_name) then
					return error("The net type '"..tostring(raw_name).."' doesn't exist!", 0)
				end
			end
			Net_types["Net"..spec.name] = decorate_spec(raw_name, spec)
		end
	end
end

---

return Net_types
