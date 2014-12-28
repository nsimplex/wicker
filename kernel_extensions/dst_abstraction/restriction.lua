local Lambda = wickerrequire "paradigms.functional"
local IsHost = IsHost

---

local modauthor = setmetatable({}, {
	__tostring = function()
		return modinfo and modinfo.author or "(unknown author)"
	end,
})

---

local function method_redirector(selffn, k)
	return function(pseudoself, ...)
		local self = selffn(pseudoself)
		return self[k](self, ...)
	end
end

local function forbidden_thing(what, k, badcase)
	badcase = badcase or "multiplayer"
	return Lambda.Error("The ", what, " ", k, " is not ", badcase, " friendly. Please report this blasphemy to this mod's author, ", modauthor, ". Make sure to attach your log.txt in the report.")
end

local forbidden_function = Lambda.BindFirst(forbidden_thing, "function")
ForbiddenFunction = forbidden_function

local forbidden_method = Lambda.BindFirst(forbidden_thing, "method")
ForbiddenMethod = forbidden_method

local function host_class(...)
	local C = Class(...)
	if not IsHost() then
		C._ctor = Lambda.LeveledError(2)("Attempt to create a host-only class in a client game. Please report this blasphemy to this mod's author, ", modauthor, ". Make sure to attach your log.txt in the report.")
	end
	return C
end
HostClass = host_class

function init(kernel)
	kernel.HostClass = HostClass
end
