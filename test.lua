#!/usr/bin/lua5.1

if _VERSION <= "Lua 5.1" then
	package.path = "./?/init.lua;"..package.path
end

-- require "."
dofile "init.lua"

start_wicker {
    id = "wickertest",

	usercode_root = ".",

	debug = true,
}
