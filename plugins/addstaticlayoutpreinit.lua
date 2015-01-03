local StaticLayout = require "map/static_layout"

---

local FunctionQueue = wickerrequire "gadgets.functionqueue"

local postinits = FunctionQueue()


StaticLayout.Get = (function()
	local Get = assert( StaticLayout.Get )

	local package_loaded = assert( _G.package.loaded )

	return function(name, ...)
		if not package_loaded[name] then
			postinits( require(name), name, ... )
		end
		return Get(name, ...)
	end
end)()

---

local function AddStaticLayoutPreInit(fn)
	table.insert(postinits, fn)
end
TheMod:EmbedHook("AddStaticLayoutPreInit", AddStaticLayoutPreInit)
