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

local package = package


local Lambda = wickerrequire 'paradigms.functional'
local Iterator = Lambda.iterator
local Logic = wickerrequire 'lib.logic'

local Pred = wickerrequire 'lib.predicates'

local utils = wickerrequire 'utils.common'


local Debuggable = wickerrequire 'gadgets.debuggable'

local FunctionQueue = wickerrequire 'gadgets.functionqueue'


-- Key, used as an index to a Mod object, leading to a table with a field
-- 'add', storing the direct Add methods (such as AddLevel) specs, and 
-- 'hook', storing the AddPostInit and AddPreInit methods specs.
local initspec_key = {}

local raw_Run

local Mod = Class(Debuggable, function(self)
	Debuggable._ctor(self, 'TheMod', false)

	self[initspec_key] = { add = {}, hook = {} }
	self.is_running = false


	--[[
	local silently_failed = false

	function self:Failed()
			return silently_failed
	end

	function self:SilentlyFailed()
			return silently_failed
	end

	local function push_errors()
		self:FlushConfigurationErrors()
		if self.AddGlobalClassPostConstruct then
			self:AddGamePostInit(function()
				self:FlushConfigurationErrors()
			end)
		end
	end

	function self:SilentlyFail()
		ModCheck(self)
		if not silently_failed then
			silently_failed = true
		end
		push_errors()
		return error("Silently failing...", 0)
	end

	local function split_first(x, ...)
		return x, {...}
	end
	]]--

	local postruns = FunctionQueue()

	function self:AddPostRun(f)
		ModCheck(self)
		assert( Lambda.IsFunctional(f) )
		table.insert( postruns, f )
	end



	local ran_set = {}

	function self:Ran(mainname)
		ModCheck(self)
		assert( Pred.IsWordable(mainname), "The main's name should be a string." )
		mainname = tostring(mainname)

		return ran_set[mainname]
	end

	function self:Run(mainname, ...)
		ModCheck(self)

		--if self:Failed() then return push_errors() end

		assert( Pred.IsWordable(mainname), "The main's name should be a string." )
		mainname = tostring(mainname)

		self.is_running = true
		local Rets = {raw_Run(self, mainname, ...)}

		--[[
		local MainArgs = {...}

		local status, Rets = split_first(xpcall(function()
				return raw_Run(self, mainname, unpack(MainArgs))
		end, debug.traceback))

		if not status then
			if self:SilentlyFailed() then
				return
			else
				return error(Rets[1], 0)
			end
		end
		]]--

		ran_set[mainname] = true
		postruns(mainname, ...)

		self.is_running = false
		return unpack(Rets)
	end

	local branch
	local first_branch_query = true
	function self:GetBranch()
		if first_branch_query then
			branch = self.modinfo.branch and tostring(self.modinfo.branch):upper()
			first_branch_query = false
		end
		return branch
	end
end)

Pred.IsMod = Pred.IsInstanceOf(Mod)

function ModCheck(self)
	assert( Pred.IsMod(self), "Don't forget to use ':'!" )
end

function Mod:GetEnvironment()
	return _M
end

function Mod:IsRunning()
	return self.is_running or false
end

function Mod:IsDev()
	ModCheck(self)
	return self:GetBranch() == "DEV"
end
Mod.IsDevel = Mod.IsDev
Mod.IsDevelopment = Mod.IsDev

-- Turns a function into a fake method.
function Mod:EmbedFunction(k, f)
	self[k] = function(_, ...)
		return f(...)
	end
end

-- Normalizes an Add- or hook id.
local function normalize_id(id)
	assert( Pred.IsWordable(id), "Invalid id given to Add- method." )
	return tostring(id):lower()
end

-- Assumes normalized.
local function get_add_spec(self, id)
	return self[initspec_key].add[id]
end

-- Assumes normalized.
local function get_hook_spec(self, id)
	return self[initspec_key].hook[id]
end

local plugin_arg_maps = {
	AddSimPostInit = Lambda.Nil,
}

local function EmbedPlugin(self, specs_table, wrapper, full_name, id, fn)
	assert( Pred.IsTable(specs_table) )
	assert( Lambda.IsFunctional(wrapper) )
	assert( Pred.IsString(full_name) )
	assert( Lambda.IsFunctional(fn) )

	local norm_id = normalize_id(id)

	local arg_map = plugin_arg_maps[full_name]
	if arg_map then
		fn = Lambda.Compose(fn, arg_map)
	end

	local spec = {
		id = id,
		fn = fn,
		full_name = full_name,
	}
	
	specs_table[norm_id] = spec

	self[full_name] = function(self, ...)
		ModCheck(self)
		return wrapper(self, norm_id, ...)
	end

	return spec
end

--[[
-- Embeds a new adder (such as AddTile).
--
-- @param id should be the method's name without the Add prefix.
--]]
function Mod:EmbedAdder(id, fn)
	ModCheck(self)
	assert( Pred.IsWordable(id) )

	id = tostring(id):gsub("^Add([A-Z])", "%1")

	local specs_table = self[initspec_key].add
	local wrapper = self.Add


	local full_name = "Add"..id
	
	EmbedPlugin(self, specs_table, wrapper, full_name, id, fn)
end

local hook_whens = {
	"Post",
	"Pre",
}

local hook_match_strings = {}
for _, when in ipairs(hook_whens) do
	table.insert(hook_match_strings, "^(.+)"..when.."([A-Z].*)$")
end

local function BreakHookName(str)
	for i, matcher in ipairs(hook_match_strings) do
		local what, condition = string.match(str, matcher)
		if what ~= nil then
			return what, hook_whens[i], condition
		end
	end
end

local function BashHookName(str)
	local what, when, condition = BreakHookName(str)
	if what == nil then
		return error("Invalid hook name '"..str.."'.", 2)
	end
	return what, when, condition
end

local function EmbedBrokenDownHook(self, fn, what, when, condition)
	local specs_table = self[initspec_key].hook
	local wrapper = self.AddHook

	local id = condition..what
	local full_name = "Add"..what..when..condition

	EmbedPlugin(self, specs_table, wrapper, full_name, id, fn).when = when:lower()
end

--[[
-- Embeds a new hook (such as AddSaveIndexPostInit).
--
-- @param id should be the method's name with an optional Add prefix 
-- (if absent, it gets added to the final method's name) and with an optional
-- (Post|Pre)Init suffix (which, if absent, must be given in the 'when' parameter.
-- If it ends in "Any", "Any" gets placed at the end of the final method's name.
--
-- @param when (optional) Should be "post" or "pre", defaulting to "post".
--]]
function Mod:EmbedHook(name, fn)
	ModCheck(self)
	assert( Pred.IsWordable(name) )

	name = tostring(name):gsub("^Add([A-Z])", "%1")

	EmbedBrokenDownHook(self, fn, BashHookName(name))
end


-- Slurps a mod environment (either from modmain or modworldgenmain)
function Mod:SlurpEnvironment(env, overwrite)
	assert( type(env) == "table" )

	if overwrite == nil then overwrite = true end

	for k, v in pairs(env) do
		if type(k) == 'string' and Lambda.IsFunctional(v) then
			local stem = k:match('^Add([A-Z].*)$')
			if stem and (overwrite or rawget(self, k) == nil) then
				local what, when, condition = BreakHookName(stem)
				if what then
					EmbedBrokenDownHook(self, v, what, when, condition)
				else
					self:EmbedAdder(stem, v)
				end
			end
		end
	end
end


local function do_main(mainname, ...)
	local main
	local M = modrequire(mainname)
	if type(M) == "function" then
		main = M
	end

	if Lambda.IsFunctional( main ) then
		return main(...)
	else
		return M
	end
end

raw_Run = function(self, mainname, ...)
	return do_main(mainname, ...)
end


local function call_add_fn(self, spec, ...)
	if self:Debug() then
		local ArgNames = Lambda.CompactlyMap(utils.toreadable, ipairs{...})
		self:Say('Calling ', spec.full_name, '(' .. table.concat(ArgNames, ', '), ')')
	end

	local Rets = {spec.fn( ... )}

	return unpack(Rets)
end


function Mod:Add(id, ...)
	ModCheck(self)
	local spec = get_add_spec( self, normalize_id(id) )
	if not spec then return error(("Invalid Add- id %q"):format(id), 2) end
	return call_add_fn(self, spec, ...)
end


local function Mod_HookAdder(self, spec, branch, reached_leaf)
	local function parameter_iterator(x, ...)
		if x == nil then
			assert( select('#', ...) == 0, "nil given as a hook-adding argument." )
			return parameter_iterator
		end

		assert( not reached_leaf or Lambda.IsFunctional(x), "Function expected as a postinit setup argument." )

		if Lambda.IsFunctional(x) then
			table.insert(branch, x)
			call_add_fn(self, spec, unpack(branch))
			table.remove(branch)
			reached_leaf = true
		elseif type(x) == "table" then
			-- We create new closures that leave our current upvalues alone.
			local hookadder_branches = Lambda.CompactlyMap(function(v, i)
				return Mod_HookAdder(self, spec, Lambda.InjectInto({}, ipairs(branch)), reached_leaf)(v)
			end, ipairs(x))
			
			local function multiplier(...)
				for i, v in ipairs(hookadder_branches) do
					hookadder_branches[i] = v(...)
				end
				return multiplier
			end

			return multiplier(...)
		else
			if Pred.IsWordable(x) then
				x = tostring(x)
			end

			table.insert(branch, x)
		end

		return parameter_iterator(...)
	end

	return parameter_iterator
end

function Mod:AddHook(id, ...)
	ModCheck(self)
	local spec = get_hook_spec( self, normalize_id(id) )
	if not spec then return error(("Invalid hook id %q"):format(id), 2) end
	return Mod_HookAdder(self, spec, {})(...)
end

for _, when in ipairs{"Pre", "Post"} do
	local when_low = when:lower()

	Mod["Add" .. when .. "Init"] = function(self, id, ...)
		ModCheck(self)
		local spec = get_hook_spec( self, normalize_id(id) )
		if not spec or spec.when ~= when_low then return error(("Invalid %sInit id %q"):format(when, id), 2) end
		return Mod_HookAdder(self, spec, {})(...)
	end
end


return function(boot_params)
	local TheMod = Mod()

	_M.TheMod = TheMod

	Lambda.ConceptualizeSingletonObject( TheMod, _M )

	boot_params.package.loaded[_NAME] = _M

	return TheMod
end
