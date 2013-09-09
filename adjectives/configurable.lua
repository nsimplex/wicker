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

local Pred = wickerrequire 'lib.predicates'

local Tree = wickerrequire 'utils.table.tree'

--local FunctionQueue = wickerrequire 'gadgets.functionqueue'


local ScriptErrorScreen = require "screens/scripterrorscreen"
if not Pred.IsTable(ScriptErrorScreen) then
		ScriptErrorScreen = assert( _G.ScriptErrorScreen )
end


local Configurable = Class(function(self)
end)

Pred.IsConfigurable = Pred.IsInstanceOf(Configurable)

local cfgcheck = Lambda.Assert(Pred.IsConfigurable, "Configurable object expected as `self' parameter.")


local CONFIGURATION_ROOT = {}


--[[
-- Returns a read-only proxy for a given table.
--]]
local make_ro_proxy, ro_error = (function()
	local make_ro_proxy

	local ro_error = Lambda.Error("Attempt to write a read-only value.")

	local meta
	meta = {
		__index = function(t, k)
			local v = t[meta][k]
			if type(v) == "table" and not Pred.IsObject(v) then
				v = make_ro_proxy(v)
			end
			rawset(t, k, v)
			return v
		end,

		__newindex = ro_error,
	}

	make_ro_proxy = function(t)
		return setmetatable({[meta] = t}, meta)
	end

	return make_ro_proxy, ro_error
end)()


--local CONFIGURATION_ROOT_PROXY = make_ro_proxy(CONFIGURATION_ROOT)
local CONFIGURATION_ROOT_PROXY = CONFIGURATION_ROOT


-- The object is discarded. This is a class method in disguise.
function Configurable:AddMasterConfigurationKey(alias)
	TUNING[alias] = CONFIGURATION_ROOT_PROXY
end

function Configurable:GetConfigurationKey()
	cfgcheck(self)
	return self[CONFIGURATION_ROOT_PROXY]
end

function Configurable:SetConfigurationKey(k)
	cfgcheck(self)
	self[CONFIGURATION_ROOT_PROXY] = k
end

local function GetLocalConfigurationTable(self)
	local key = self:GetConfigurationKey()
	if key then
		CONFIGURATION_ROOT[key] = CONFIGURATION_ROOT[key] or {}
		local tbl = CONFIGURATION_ROOT_PROXY[key]
		if tbl then
			return tbl
		end
	end
end

local function GetConfigurationTable(self)
	return GetLocalConfigurationTable(self) or CONFIGURATION_ROOT
end

local get_virtual_configuration_table = (function()
	local vtables = setmetatable({CONFIGURATION_ROOT = CONFIGURATION_ROOT_PROXY}, {__mode = "k"})

	local meta
	meta = {
		__index = function(t, k)
			local v = t[meta][k]
			if v ~= nil then
				return v
			else
				return CONFIGURATION_ROOT_PROXY[k]
			end
		end,

		__newindex = function(t, k, v)
			t[meta][k] = v	
		end,
	}

	return function(self)
		local cfgtable = GetConfigurationTable(self)
	
		local vt = vtables[cfgtable]

		if not vt then
			--local cfgtable_proxy = make_ro_proxy(cfgtable)
			local cfgtable_proxy = cfgtable
			vt = setmetatable({[meta] = cfgtable_proxy}, meta)
			vtables[cfgtable] = vt
		end

		return vt
	end
end)()

function Configurable:GetConfig(...)
	cfgcheck(self)

	local cfgtable = get_virtual_configuration_table(self)

	for i, v in ipairs{...} do
		if not type(cfgtable) == "table" then return end
		cfgtable = cfgtable[v]
	end

	return cfgtable
end


local exportable_LoadConfiguration
local function exportable_LoadConfiguration_relayer(...)
	return exportable_LoadConfiguration(...)
end

local configuration_env = {
	LoadConfiguration = exportable_LoadConfiguration_relayer,

	TUNING = TUNING,
	STRINGS = STRINGS,
	Point = Point,
	Vector3 = Vector3,

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
	getmetatable = getmetatable,
	setmetatable = setmetatable,

	Lambda = make_ro_proxy(Lambda),
	Logic = make_ro_proxy(Logic),
	Pred = make_ro_proxy(Pred),
}

local loaded_funcs = setmetatable({}, {__mode = "k"})
local loaded_files = {}


local LoadConfiguration


local function LoadConfigurationFunction(root, cfg, name)
	local schema = modrequire 'rc.schema'

	if loaded_funcs[cfg] then return end
	loaded_funcs[cfg] = true

	name = name or "a configuration function"


	local tmpenv = Lambda.Map(Lambda.Identity, pairs(configuration_env))
	tmpenv.LoadConfiguration = Lambda.BindFirst(LoadConfiguration, root)

	
	local new_options = setmetatable({}, {__index = root})

	local indexed_fields = {}

	local meta = {
		__index = function(t, k)
			if Pred.IsPublicString(k) then
				indexed_fields[k] = true
			end
			new_options[k] = new_options[k] ~= nil and new_options[k] or Tree()
			return new_options[k]
		end,

		__newindex = function(t, k, v)
			if Pred.IsPublicString(k) then
				indexed_fields[k] = true
			end
			new_options[k] = v
		end,
	}

	setmetatable(tmpenv, meta)
	setfenv(cfg, tmpenv)

	local status, runerr = pcall(cfg)
	if not status then
		return error(runerr, 0)
	end


	local bad_options = {}

	local function check_subtree(opt_subroot, schema_subroot, optname)
		optname = optname or ""
		for k, p in pairs(schema_subroot) do
			if Pred.IsString(k) then
				local child = opt_subroot[k]
				local child_optname = optname .. "." .. k

				if type(p) == "table" then
					if not Pred.IsIndexable(child) then
						table.insert(bad_options, {k = child_optname, v})
					else
						check_subtree(child, p, child_optname)
					end
				elseif Lambda.IsFunctional(p) then
					if not p(child) then
						table.insert(bad_options, {k = child_optname, v})
					end
				end
			end
		end
	end

	for k in pairs(indexed_fields) do
		if schema[k] then
			check_subtree(new_options[k], schema[k])
		end
	end

	if #bad_options > 0 then
		return error(table.concat {
			"The following problems were found in " .. name .. ":\n",
			table.concat(
				Lambda.CompactlyMap(function(opt)
					return (" "):rep(4) .. opt.k .. ' has the invalid value ' .. tostring(opt.v)
				end, ipairs(bad_options))
			, "\n"),
			"\n",
		}, 0)
	end

	for k in pairs(indexed_fields) do
		if Pred.IsTable(new_options[k]) and not Pred.IsObject(new_options[k]) then
			root[k] = root[k] or {}
			Tree.InjectIntoIf(
				Lambda.Not( Lambda.And(Tree.IsAbstractTree, Tree.IsLeaf) ),
				root[k],
				new_options[k]
			)
		else
			root[k] = new_options[k]
		end
	end
end

local function LoadConfigurationFile(root, fname)
	if loaded_files[fname] then return end
	loaded_files[fname] = true

	local cfg, loaderr = loadmodfile(fname)
	if not cfg then
		return error(loaderr, 0)
	end
	return LoadConfigurationFunction( root, cfg, fname )
end

local function put_error(msg)
	return error(msg, 0)
end

LoadConfiguration = function(root, what, description)
	local loader

	if type(what) == "function" then
		loader = LoadConfigurationFunction
	else
		assert( Pred.IsWordable(what), "Configurable:LoadConfiguration only accepts a file name or a function." )
		what = tostring(what)
		loader = LoadConfigurationFile
	end

	local status, err = pcall(loader, GetConfigurationTable(self), what, description)

	if not status then put_error(err) end
end

-- The object is discarded. This is a class method in disguise.
function Configurable:LoadConfiguration(what, description)
	cfgcheck(self)
	return LoadConfiguration(GetConfigurationTable(self), what, description)
end


return Configurable
