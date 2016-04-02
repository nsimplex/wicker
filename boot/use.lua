--[[
Copyright (c) 2013, 2016 simplex

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
]]--


local _G = GLOBAL
local _M = env

local assert = _G.assert
local error = _G.error


--[[
-- The following is to prevent this file from being run more than once.
--
-- This is necessary to allow it to be loaded both from modmain.lua and
-- modworldgenmain.lua without the former load overriding the latter.
--]]
local _IDENTIFIER = _G.debug.getinfo(1, 'S').source .. "_LOADED"

if _G.rawget(_G, _IDENTIFIER) then
	return _G[_IDENTIFIER]
end


local function preload_searcher(self, name)
	local ret = self.package.preload[name]
	if ret ~= nil then
		return ret
	else
		return "no field package.preload['"..name.."']"
	end
end

local function default_searcher(self, name)
	name = name:gsub("[.\\]", "/")

	local fail_pieces = {}

	for pathspec in self.package.path:gmatch("[^;]+") do
		local path = pathspec:gsub("%?", name, 1)
		if _G.kleifileexists(path) then
			local fn = _G.kleiloadlua(path)
			if type(fn) ~= "function" then
				return error(tostring(fn or "Unknown error"), 3)
			end
			return fn
		else
			table.insert(fail_pieces, "\tno file '" .. path .. "'")
		end
	end

	return table.concat(fail_pieces, "\n")
end


local Requirer = Class(function(self, default_env)
	default_env = default_env or _G

	self.package = {
		path = MODROOT .. "?.lua",
		searchers = {preload_searcher, default_searcher},
		preload = {},
		loaded = {},
	}
	self.package.loaders = self.package.searchers

	function self:GetDefaultEnvironment()
		return default_env
	end
end)

function Requirer:GetEnvironment()
	return self.env or self:GetDefaultEnvironment()
end

function Requirer:SetEnvironment(env)
	self.env = env
end

function Requirer:__call(name)
	if self.package.loaded[name] then
		return self.package.loaded[name]
	else
		local fail_pieces = {}

		for _, searcher in ipairs(self.package.searchers) do
			local fn = searcher(self, name)
			if type(fn) == "function" then
				_G.setfenv(fn, self:GetEnvironment())
				local ret = fn(name)
				if ret == nil then
					ret = self.package.loaded[name] or true
				end
				self.package.loaded[name] = ret
				return ret
			elseif type(fn) == "string" then
				table.insert(fail_pieces, fn)
			end
		end

		table.insert(fail_pieces, 1, ("mod module '%s' not found:"):format(name))
		return error(table.concat(fail_pieces, "\n"), 2)
	end
end

function Requirer:ExportAs(id)
	_G.package.loaded[id] = self
end


local ModRequirer = Class(Requirer, function(self)
	Requirer._ctor(self, _M)
end)

function ModRequirer:GetModEnvironment()
	return self:GetDefaultEnvironment()
end
ModRequirer.GetModEnv = ModRequirer.GetModEnvironment

function ModRequirer:GetModInfo()
	return self:GetModEnvironment().modinfo
end

---

--[[
-- Allows member functions to be used without passing the 'self' parameter.
--]]
local function makeImplicit(self)
	local getmetatable, setmetatable = _G.getmetatable, _G.setmetatable
	local pairs = _G.pairs
	local type = _G.type

	local class = getmetatable(self)

	local meta = {}
	for k, v in pairs(class) do
		meta[k] = v
	end

	local index = {}
	for k, v in pairs( assert(meta.__index) ) do
		if type(v) == "function" then
			local oldv = v
			v = function(mself, ...)
				if mself == self then
					return oldv(mself, ...)
				else
					return oldv(self, mself, ...)
				end
			end
		end
		index[k] = v
	end
	meta.__index = index

	setmetatable(self, meta)
	return self
end

---


use = makeImplicit(ModRequirer())
_G[_IDENTIFIER] = use
return use
