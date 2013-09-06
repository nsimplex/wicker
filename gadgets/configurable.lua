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


local Lambda = wickerrequire 'paradigms.functional'
local Logic = wickerrequire 'paradigms.logic'

local Configurable = Class(function(self)
end)

local GetMasterKey
local SetMasterKey

do
	local MASTER_KEY = nil

	GetMasterKey = function()
		return MASTER_KEY
	end

	SetMasterKey = function(k)
		MASTER_KEY = k
		assert( TUNING[k] == nil )
		TUNING[k] = {}
		Configurable.SetMasterKey = Lambda.Error('The master key can only be set once.')
		return k
	end

	Configurable.SetMasterKey = SetMasterKey
end

local function GetConfigurationRoot()
	return TUNING[GetMasterKey()]
end

-- The object is discarded. This is a class method in disguise.
function Configurable:AddMasterKeyAlias(alias)
	TUNING[alias] = GetConfigurationRoot()
end

function Configurable:GetKey()
	return self[GetMasterKey()]
end

function Configurable:SetKey(k)
	self[GetMasterKey()] = k
	return k
end

function Configurable:GetLocalConfigurationTable()
	local key = self:GetKey()
	if key then
		local tbl = GetConfigurationRoot()[key]
		if tbl then
			return tbl
		end
	end
end

local function get_virtual_configuration_table(self)
	local local_table = self:GetLocalConfigurationTable()

	if not local_table then return GetConfigurationRoot() end

	local ret = {}
	local meta = {}

	meta.__index = function(t, k)
		local v = local_table[k]
		if v ~= nil then
			return v
		else
			return GetConfigurationRoot()[k]
		end
	end

	return setmetatable(ret, meta)
end

function Configurable:GetConfig(...)
	local cfgtable = get_virtual_configuration_table(self)

	for i, v in ipairs{...} do
		if not type(cfgtable) == "table" then return end
		cfgtable = cfgtable[v]
	end

	return cfgtable
end

local configuration_env = {
	TUNING = TUNING,
	STRINGS = STRINGS,
	math = math,
	table = table,
	ipairs = ipairs,
	pairs = pairs,
	select = select,
	unpack = unpack,
	assert = assert,
	error = error,
	string = string,
	tostring = tostring,
	tonumber = tonumber,
}

local function put_error(msg)
	return error(msg, 3)
end

local loaded_funcs = setmetatable({}, {__mode = "k"})
local loaded_files = {}

-- The object is discarded. This is a class method in disguise.
function Configurable:LoadConfigurationFunction(cfg, name)
	if loaded_funcs[cfg] then return end
	loaded_funcs[cfg] = true

	name = name or "a configuration function"

	local schema = modrequire 'rc.schema'

	local tmpenv = Lambda.Map(Lambda.Identity, pairs(configuration_env))
	
	local meta = {}

	local root = assert( GetConfigurationRoot() )

	local bad_options = {}

	meta.__index = root

	function meta.__newindex(env, k, v)
		if type(k) == "string" and not k:match('^_') then
			if not schema[k] or schema[k](v) then
				root[k] = v
			else
				table.insert( bad_options, {k = k, v = v} )
			end
		else
			rawset(env, k, v)
		end
	end

	setmetatable(tmpenv, meta)

	setfenv(cfg, tmpenv)

	local status, runerr = pcall(cfg)
	if not status then
		put_error(runerr)
	end

	if #bad_options > 0 then
		local msg = "The following problems were found in " .. name .. ":\n"
		msg = msg .. table.concat(
			Lambda.CompactlyMap(function(opt)
				return opt.k .. ' has the invalid value ' .. tostring(opt.v)
			end, ipairs(bad_options))
		, "\n") .. "\n"
		put_error( msg )
	end

	return runerr
end

-- The object is discarded. This is a class method in disguise.
function Configurable:LoadConfigurationFile(fname)
	if loaded_files[fname] then return end
	loaded_files[fname] = true

	local cfg, loaderr = loadmodfile(fname)
	if not cfg then
		put_error(loaderr)
	end
	return self:LoadConfigurationFunction( cfg, fname )
end

return Configurable
