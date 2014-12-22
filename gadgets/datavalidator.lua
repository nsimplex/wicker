local Lambda = wickerrequire "paradigms.functional"

local function NewDataValidator(mandatory_data, table_name)
	local function getFieldName(...)
		local pieces = {}
		if table_name then
			table.insert(pieces, tostring(table_name))
		end
		local reverse_pieces = {...}
		for i = #reverse_pieces, 1, -1 do
			table.insert(pieces, tostring(reverse_pieces[i]))
		end
		return table.concat(pieces, ".")
	end

	local function doValidate(sub_mandatory_data, sub_data, ...)
		assert(type(sub_mandatory_data) == "table", "Program logic error.")
		if type(sub_data) ~= "table" then
			return error("Table expected as field "..getFieldName(...)..", got "..type(sub_data)..".", 0)
		end
		for i, k in ipairs(sub_mandatory_data) do
			if sub_data[k] == nil then
				return error("Mandatory field "..getFieldName(k, ...).." expected.", 0)
			end
		end
		for k, v in pairs(sub_mandatory_data) do
			if type(k) ~= "number" then
				if type(v) == "table" then
					doValidate(v, sub_data[k], k, ...)
				elseif Lambda.IsFunctional(v) then
					if not v(sub_data[k]) then
						return error("Invalid mandatory field "..getFieldName(k, ...).." expected.", 0)
					end
				else
					return error("Mandatory data template has invalid type for field "..getFieldName(k, ...)..".", 0)
				end
			end
		end
	end

	-- error_level is relative to the parent function.
	return function(data, error_level)
		error_level = error_level or 1
		local status, err = xpcall(Lambda.BindAll(doValidate, mandatory_data, data), Lambda.Identity)
		if not status then
			return error(err, error_level + 1)
		end
	end
end

return NewDataValidator
