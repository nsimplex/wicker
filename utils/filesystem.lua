--[[
Copyright (C) 2013  simplex

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.
]]--

--@@ENVIRONMENT BOOTUP
local _modname = assert( (assert(..., 'This file should be loaded through require.')):match('^[%a_][%w_%s]*') , 'Invalid path.' )
module( ..., require(_modname .. '.booter') )
--@@END ENVIRONMENT BOOTUP


local Pred = wickerrequire 'lib.predicates'


local DIR_SEP_CHARS = "/\\"

if not DIR_SEP_CHARS:find(package.config:sub(1,1), 1, true) then
	DIR_SEP_CHARS = DIR_SEP_CHARS .. package.config:sub(1,1)
end

local MODULE_SEP_CHARS = DIR_SEP_CHARS .. "."

local CANONICAL_DIR_SEP = "/"
local CANONICAL_MODULE_SEP = "."


--[[
-- Maps a category ("Module", "File") to its parameters.
--]]
local conventions = {
	[""] = {
		suffixes = {"Path"},
		separators = DIR_SEP_CHARS,
		canonical_separator = CANONICAL_DIR_SEP,
		native_separator = package.config:sub(1,1),
	},
	Module = {
		suffixes = {"", "Path", "Name"},
		separators = MODULE_SEP_CHARS,
		canonical_separator = CANONICAL_MODULE_SEP,
	},
}


--[[
-- Maps a prefix of a function to its generator.
--]]
local GetGenerator, AddGenerator, GeneratorIterator = (function()
	local generators = {}
	local cache = {}

	local function Get(prefix, suffix)
		prefix = prefix or ""
		suffix = suffix or ""

		return generators[prefix] and generators[prefix][suffix]
	end

	local function Add(prefix, suffix, generator)
		prefix = prefix or ""
		suffix = suffix or ""

		generators[prefix] = generators[prefix] or {}

		generators[prefix][suffix] = function(convention)
			cache[prefix] = cache[prefix] or {}
			cache[prefix][suffix] = cache[prefix][suffix] or {}

			if not cache[prefix][suffix][convention] then
				cache[prefix][suffix][convention] = generator(convention)
			end

			return cache[prefix][suffix][convention]
		end
	end

	local function Iterator()
		local prefix, suffix

		prefix = next(generators)
		if prefix == nil then return function() end end

		return function()
			suffix = next(generators[prefix], suffix)

			while suffix == nil do
				prefix = next(generators, prefix)
				if prefix == nil then return nil end
				suffix = next(generators[prefix])
			end

			return prefix, suffix, generators[prefix][suffix]
		end
	end

	return Get, Add, Iterator
end)()


--[[
-- Returns the path components as an array.
-- If the path starts with a directory separator, the first component will
-- be the empty string.
-- Ignores trailing and repeated slashes.
--]]
AddGenerator("Split", "", function(convention)
	local separators = convention.separators
	
	assert( type(separators) == "string" )

	return function(path)
		assert( Pred.IsStringable(path), "The path should be a string." )
		path = tostring(path)

		local pieces = {}
		local npieces = 0
		for m in path:gmatch("[^" .. separators .. "]*") do
			if m ~= "" or npieces == 0 then
				table.insert(pieces, m)
				npieces = npieces + 1
			end
		end
		return pieces
	end
end)


local function NewSepReplacer(splitter, sep)
	return function(path)
		return table.concat(splitter(path), sep)
	end
end

AddGenerator("Normalize", "", function(convention)
	local splitter, sep = GetGenerator("Split")(convention), convention.canonical_separator

	return NewSepReplacer(splitter, sep)
end)

AddGenerator("Native", "", function(convention)
	local splitter, sep = GetGenerator("Split")(convention), convention.native_separator
	if sep then
		return NewSepReplacer(splitter, sep)
	end
end)


--
-- seps is the collection of separators, as a string.
--
-- pieces is the output of a path splitter.
--
-- Doesn't account for the full path being the Unix root ("/").
local function NewPathVariantsGenerator(seps)
	local function inner_generate_variant(pieces, n, processed_pieces, i)
		if i > n then
			coroutine.yield( table.concat(processed_pieces) )
			return
		end
		assert( #processed_pieces == 2*i - 3 )
		processed_pieces[2*i - 1] = pieces[i]
		for j = 1, #seps do
			processed_pieces[2*i - 2] = seps:sub(j,j)
			inner_generate_variant(pieces, n, processed_pieces, i + 1)
		end
		processed_pieces[2*i - 2], processed_pieces[2*i - 1] = nil, nil
	end

	return function(pieces)
		assert( #pieces >= 1 )
		return inner_generate_variant(pieces, #pieces, {pieces[1]}, 2)
	end
end

AddGenerator("", "Variants", function(convention)
	local splitter, seps = GetGenerator("Split")(convention), convention.separators

	local pathvariants_generator = NewPathVariantsGenerator(seps)

	-- Returns an iterator triple.
	return function(path)
		local pieces = splitter(path)

		local co = coroutine.create(function() return pathvariants_generator(pieces) end)

		return function(co)
			local status, ret = coroutine.resume(co)
			if status then
				return ret
			else
				return error(ret)
			end
		end, co
	end
end)



for convention_name, convention in pairs(conventions) do
	for prefix, suffix, generator in GeneratorIterator() do
		for _, convention_suffix in ipairs(convention.suffixes) do
			_M[prefix .. convention_name .. convention_suffix .. suffix] = generator(convention)
		end
	end
end



return _M
