--[[
-- Utilities for checking things about the game state.
--]]

function FindUpvalue(fn, upvalue_name)
	assert(type(fn) == "function", "Function expected as 'fn' parameter.")

	local info = debug.getinfo(fn, "u")
	local nups = info and info.nups
	if not nups then return end

	local getupvalue = debug.getupvalue

	for i = 1, nups do
		local name, val = getupvalue(fn, i)
		if name == upvalue_name then
			return val, true
		end
	end
end
local FindUpvalue = FindUpvalue
FindUpValue = FindUpvalue

function RequireUpvalue(fn, upvalue_name)
	local val, found = FindUpvalue(fn, upvalue_name)
	if not found then
		return error("Unable to find upvalue '"..tostring(upvalue_name).."' through introspection.", 2)
	end
	return val
end
local RequireUpvalue = RequireUpvalue
RequireUpValue = RequireUpvalue

Upvalues = (function()
	local getinfo = debug.getinfo
	local getupvalue = debug.getupvalue

	local function f(s, var)
		local fn, nups = s[1], s[2]
		var = var + 1
		if var > nups then
			return
		end
		return var, getupvalue(fn, var)
	end

	return function(fn)
		local info = getinfo(fn, "u")
		local nups = info and info.nups or 0

		return f, {fn, nups}, 0
	end
end)()
local Upvalues = Upvalues

---

function EnabledMods()
	return ipairs( _G.ModManager.mods )
end
local EnabledMods = EnabledMods

function FindActiveMod(testfn)
	for _, mod in EnabledMods() do
		local its_modinfo = mod.modinfo
		if type(its_modinfo) ~= "table" then
			its_modinfo = (mod.modname and _G.KnownModIndex:GetModInfo(mod.modname))
		end
		if type(its_modinfo) == "table" and testfn( its_modinfo, mod ) then
			return its_modinfo, mod
		end
	end
end

function HasModWithName(name)
	return FindActiveMod(function(info)
		return info.name == name
	end) ~= nil
end

function HasModWithId(id)
	return FindActiveMod(function(info)
		return info.id == id
	end) ~= nil
end

function IsModEnabled(id_or_name)
	return FindActiveMod(function(info)
		return info.id == id_or_name or info.name == id_or_name
	end) ~= nil
end

EnableModInCache = (function()
	local did_enable = false

	return function(cb)
		if did_enable then
			cb()
			return
		end

		local moddir = modenv.modname
		local KnownModIndex = rawget(_G, "KnownModIndex")
		assert(KnownModIndex)
		if not KnownModIndex then return end

		did_enable = true
		KnownModIndex:Enable(moddir)
		KnownModIndex:Save(cb)
	end
end)()
