--BindGlobal()

local Pred = wickerrequire 'lib.predicates'

--------------------------------------

local function try_require(options)
	if type(options) ~= "table" then options = {options} end

	for _, m in ipairs(options) do
		local status, pkg = pcall(require, m)
		if status then return pkg, m end
	end
end

---------------------------------------

local function find_global_fibermatch(y, f)
	for x in pairs(_G) do
		if type(x) == "string" and f(x) == y then
			return x
		end
	end
end


--
-- Call it like AddGlobalClassPostConstruct or like AddClassPostConstruct
-- (in the latter, the "fn" actually goes in the "classname" position.
--
local function AddGenericClassPostConstruct(pkgname, classname, fn)
	if not fn then
		classname, fn = fn, classname
	end

	local pkg_prefix, pkg_suffix = pkgname:match("^(.-)([%w_]+)$")

	local is_primary = (not classname or classname:lower() == pkg_suffix:lower())


	local pkg
	local effective_pkgname
	if is_primary then
		pkg = require(pkgname)
	else
		try_require(pkgname)
		pkg, effective_pkgname = try_require{pkg_prefix .. classname, classname}
	end
	if not effective_pkgname then
		effective_pkgname = pkgname
	end


	if Pred.IsObject(pkg) then
		modenv.AddClassPostConstruct(effective_pkgname, fn)
		return
	else
		if not classname then
			classname = find_global_fibermatch(pkg_suffix:lower(), string.lower)
		end
		if classname and VarExists(classname) then
			modenv.AddGlobalClassPostConstruct("math", classname, fn)
			return
		end
	end

	return error("Unable to find a class to which attach the post construct.")
end
TheMod:EmbedAdder("GenericClassPostConstruct", AddGenericClassPostConstruct)
TheMod:EmbedAdder("ClassPostConstruct", AddGenericClassPostConstruct)
TheMod:EmbedAdder("GlobalClassPostConstruct", AddGenericClassPostConstruct)
