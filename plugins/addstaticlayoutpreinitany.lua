local StaticLayout = require "map/static_layout"

---

local FunctionQueue = wickerrequire "gadgets.functionqueue"

local preinits = FunctionQueue()


StaticLayout.Get = (function()
	local Get = assert( StaticLayout.Get )

	local processed_layouts = {}

	return function(name, ...)
		if not processed_layouts[name] then
			processed_layouts[name] = true
			preinits( require(name), name, ... )
		end
		return Get(name, ...)
	end
end)()

---

local function AddStaticLayoutPreInitAny(fn)
	table.insert(preinits, fn)
end
TheMod:EmbedHook("AddStaticLayoutPreInitAny", AddStaticLayoutPreInitAny)
