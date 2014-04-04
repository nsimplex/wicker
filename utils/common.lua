local Pred = wickerrequire "lib.predicates"

toreadable = (function()
	local function bracket_handler(x)
		return "["..tostring(x).."]"
	end

	local type_handlers = {
		string = function(x)
			return ("%q"):format(x)
		end,
		number = function(x)
			return ("%2.2f"):format(x)
		end,
		["function"] = bracket_handler,
		table = bracket_handler,
	}
	
	return function(x)
		local h = type_handlers[type(x)]
		if h then 
			return h(x)
		else
			return tostring(x)
		end
	end
end)()
