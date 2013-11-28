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


return function(boot_params, wicker_stem)
	local _M = _M

	local basic_import = assert( boot_params.import )
	local modcode_root = assert( boot_params.modcode_root )

	local AssertEnvironmentValidity = assert( AssertEnvironmentValidity )

	local GetNextEnvironmentThreshold = GetNextEnvironmentThreshold
	local GetEnvironmentLayer = GetEnvironmentLayer
	local GetOuterEnvironment = GetOuterEnvironment


	local function prefixed_import(prefix, name)
		assert( type(prefix) == "string" )
		assert( type(name) == "string", "Package name is not a string." )
		local M = basic_import(prefix..name)
		if type(M) == "table" then
			AssertEnvironmentValidity( M )
		end
		return M
	end
	
	
	local importer_metadata = {}

	
	importer_metadata[require] = {name = 'require', category = 'Module'}
	
	function wickerrequire(name)
		local M = prefixed_import(wicker_stem, name)
		if type(M) == "table" then
			AssertEnvironmentValidity( M )
		end
		return M
	end
	local wickerrequire = wickerrequire
	wickerequire = wickerrequire
	importer_metadata[wickerrequire] = {name = 'wickerrequire', category = 'WickerModule'}
	
	function modrequire(name)
		local M = prefixed_import(modcode_root, name)
		if type(M) == "table" then
			AssertEnvironmentValidity( M )
		end
		return M
	end
	local modrequire = modrequire
	importer_metadata[modrequire] = {name = 'modrequire', category = 'ModModule'}

	function pkgrequire(name)
		local env = GetOuterEnvironment()
		assert( env )
		assert( type(env._PACKAGE) == "string" )
	
		local M = prefixed_import(env._PACKAGE, name)
	
		if type(M) == "table" then
			AssertEnvironmentValidity( M )
		end
	
		return M
	end
	local pkgrequire = pkgrequire
	importer_metadata[pkgrequire] = {name = 'pkgrequire', category = 'ModPackage'}


	importer_metadata[function(t) return t end] = {name = 'GetTable', category = 'Table'}

	-- This should be hidden as soon as possible.
	function TheKernel()
		return _M
	end
	local TheKernel = TheKernel
	importer_metadata[TheKernel] = {name = 'TheKernel', category = 'TheKernel'}
	AddVariableCleanup("TheKernel")
	
	function GetTheMod()
		local M = wickerrequire 'api.themod'
		return M
	end
	local GetTheMod = GetTheMod
	importer_metadata[GetTheMod] = {name = 'GetTheMod', category = 'TheMod'}
	
	
	return importer_metadata
end
