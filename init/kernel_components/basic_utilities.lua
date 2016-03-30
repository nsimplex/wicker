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

local NewGetter = (function()
	local function doget_wrapper(self, k)
		local v = self[self](k)
		if v == nil then
			return error(("Required variable %s not set."):format(tostring(k)), 3)
		end
		return v
	end

	local getter_meta = {
		__index = doget_wrapper,
		__call = doget_wrapper,
	}

	return function(kernel)
		local function doget(k)
			local v = kernel[k]
			if v == nil then
				v = kernel._G[k]
			end
			return v
		end

		local rawget = doget "rawget"

		local function doget_opt(k, dflt_v)
			local v = kernel[k]
			if v == nil then
				v = rawget(kernel._G, k)
			end
			if v == nil then
				if dflt_v == nil then
					return error(("Required variable %s not set."):format(tostring(k)), 2)
				end
				return dflt_v
			else
				return v
			end
		end

		local setmetatable = doget "setmetatable"

		local ret = {}
		ret[ret] = doget
		ret.opt = doget_opt

		return setmetatable(ret, getter_meta)
	end
end)()

local function memoize_0ary(f, dont_retry)
	local cached
	if not dont_retry then
		return function()
			if cached == nil then
				cached = f()
				if cached ~= nil then
					f = nil
				end
			end
			return cached
		end
	else
		local tried = false
		return function()
			if not tried then
				cached = f()
				f = nil
				tried = true
			end
			return cached
		end
	end
end

local function lambdaif(p)
	return function(a, b)
		if p() then
			return a
		else
			return b
		end
	end
end
local function immutable_lambdaif(p)
	if p() then
		return function(a, b)
			return a
		end
	else
		return function(a, b)
			return b
		end
	end
end

local function const(x)
	return function()
		return x
	end
end

local Nil = const()
local True, False = const(true), const(false)
local Zero, One = const(0), const(1)

local function bindfst(f, x)
	return function(...)
		return f(x, ...)
	end
end

----------

local function make_inner_env(kernel)
	local get = NewGetter(kernel)

	local rawset = get.rawset
	local setmetatable = get.setmetatable
	local setfenv = get.setfenv

	local inner_meta = {
		__index = kernel,
		__newindex = function(t, k, v)
			kernel[k] = v
			rawset(t, k, v)
		end,
	}

	local function finalize(self)
		inner_meta.__newindex = nil
		return self
	end
	inner_meta.__call = finalize

	local inner_env = {}
	inner_env._M = inner_env
	setmetatable(inner_env, inner_meta)

	setfenv(2, inner_env)

	return inner_env
end

----------

local function include_corelib(kernel)
	local get = NewGetter(kernel)

	local _G = get._G

	local assert, error = get.assert, get.error
	local VarExists = get.VarExists

	local type = get.type
	local rawget, rawset = get.rawget, get.rawset

	local getmetatable, setmetatable = get.getmetatable, get.setmetatable
	local table, math = get.table, get.math

	local pairs, ipairs = get.pairs, get.ipairs
	local next = get.next

	---

	local CORELIB_ENV = make_inner_env(kernel)

	---
	
	_M.memoize_0ary = assert( memoize_0ary )
	_M.memoise_0ary = assert( memoize_0ary )

	local function ShallowInject(tgt, src)
		for k, v in pairs(src) do
			tgt[k] = v
		end
		return tgt
	end
	_M.ShallowInject = ShallowInject

	local function ShallowCopy(t)
		return ShallowInject({}, t)
	end
	_M.ShallowCopy = ShallowCopy

	local function DeepTreeInject(tgt, src)
		for k, v in pairs(src) do
			if type(v) == "table" then
				local tgt_k = tgt[k]
				if type(tgt_k) ~= "table" then
					tgt_k = {}
					tgt[k] = tgt_k
				end
				DeepTreeInject(tgt_k, v)
			else
				tgt[k] = v
			end
		end
	end
	_M.DeepTreeInject = DeepTreeInject
	_M.DeepInject = DeepTreeInject

	local function DeepTreeCopy(t)
		return DeepTreeInject({}, t)
	end
	_M.DeepTreeCopy = DeepTreeCopy
	_M.DeepCopy = DeepCopy

	local function DeepGraphInject_internal(tgt, src, refmap)
		for k, v in pairs(src) do
			if type(v) == "table" then
				local tgt_k = refmap[v]
				if tgt_k ~= nil then
					tgt[k] = tgt_k
				else
					tgt_k = tgt[k]
					if type(tgt_k) ~= "table" then
						tgt_k = {}
						tgt[k] = tgt_k
					end

					refmap[v] = tgt_k

					DeepGraphInject_internal(tgt_k, v, refmap)
				end
			end
		end
	end

	local function DeepGraphInject(tgt, src)
		return DeepGraphInject_internal(tgt, src, {[src] = tgt})
	end
	_M.DeepGraphInject = DeepGraphInject

	local function DeepGraphCopy(t)
		return DeepGraphInject({}, t)
	end
	_M.DeepGraphCopy = DeepGraphCopy

	-- Returns the size of a table including *all* entries.
	local function cardinal(t)
		local sz = 0
		for _ in pairs(t) do
			sz = sz + 1
		end
		return sz
	end
	_M.cardinal = cardinal
	_M.GetTableCardinality = cardinal

	-- Compares cardinal(t) and n.
	--
	-- Returns -1 if cardinal(t) < n
	-- Returns 0 if cardinal(t) == n
	-- Returns +1 if cardinal(t) > n
	local function cardinalcmp(t, n)
		-- cardinal(t) - n
		local difference = -n
		for _ in pairs(t) do
			difference = difference + 1
			if difference > 0 then
				return 1
			end
		end
		if difference == 0 then
			return 0
		else
			return -1
		end
	end
	_M.cardinalcmp = cardinalcmp

	local function value_dump(t)
		require "dumper"

		local str = _G.DataDumper(t, nil, false)
		return ( str:gsub("^return%s*", "") )
	end
	_M.value_dump = value_dump
	_M.table_dump = value_dump

	---
	
	return CORELIB_ENV()
end

----------

local function include_platform_detection_functions(kernel)
	local get = NewGetter(kernel)

	local _G = get._G

	local assert, error = get.assert, get.error
	local VarExists = get.VarExists

	local type = get.type
	local rawget, rawset = get.rawget, get.rawset

	local getmetatable, setmetatable = get.getmetatable, get.setmetatable
	local table, math = get.table, get.math

	local pairs, ipairs = get.pairs, get.ipairs
	local next = get.next

	---

	local GetModDirectoryName = get.GetModDirectoryName

	---
	
	local PLATFORM_DETECTION = make_inner_env(kernel, _G)

	---

	IsDST = memoize_0ary(function()
		return _G.kleifileexists("scripts/networking.lua") and true or false
	end)
	local IsDST = IsDST
	IsMultiplayer = IsDST

	IfDST = immutable_lambdaif(IsDST)
	IfMultiplayer = IfDST

	function IsSingleplayer()
		return not IsDST()
	end
	local IsSingleplayer = IsSingleplayer

	IfSingleplayer = immutable_lambdaif(IsSingleplayer)

	---

	IsDLCEnabled = get.opt("IsDLCEnabled", False)
	IsDLCInstalled = get.opt("IsDLCInstalled", IsDLCEnabled)

	REIGN_OF_GIANTS = get.opt("REIGN_OF_GIANTS", 1)
	CAPY_DLC = get.opt("CAPY_DLC", 2)

	---

	IsRoG = memoize_0ary(function()
		if IsDST() then
			return true
		else
			return IsDLCEnabled(REIGN_OF_GIANTS) and true or false
		end
	end)
	IsROG = IsRoG

	IsSW = memoize_0ary(function()
		return IsDLCEnabled(CAPY_DLC) and true or false
	end)

	IfRoG = immutable_lambdaif(IsRoG)
	IfROG = IfRoG

	IfSW = immutable_lambdaif(IsSW)

	---

	return PLATFORM_DETECTION()
end

----------

local function include_constants(kernel)
	local get = NewGetter(kernel)

	local _G = get._G

	local assert, error = get.assert, get.error
	local VarExists = get.VarExists

	local type = get.type
	local rawget, rawset = get.rawget, get.rawset

	local getmetatable, setmetatable = get.getmetatable, get.setmetatable
	local table, math = get.table, get.math

	local pairs, ipairs = get.pairs, get.ipairs
	local next = get.next

	local tostring = get.tostring

	---

	local CONSTANTS_ENV = make_inner_env(kernel, _G)

	---
	
	local function addConstants(name, t)
		if t == nil then
			return bindfst(addConstants, name)
		end

		local t2 = ShallowCopy(t)

		local _N
		if name == nil then
			_N = _M
		else
			_N = _M[name]
			if not _N then
				_N = {}
				_M[name] = _N
			end
		end

		ShallowInject(_N, t)
	end

	local dflts = {}
	local function addDefaultConstants(name, t)
		if t == nil then
			return bindfst(addDefaultConstants, name)
		end

		addConstants(name, t)

		local _N
		if name == nil then
			_N = dflts
		else
			_N = dflts[name]
			if not _N then
				_N = {}
				dflts[name] = _N
			end
		end

		ShallowInject(_N, t)
	end

	local validateConstants = (function()
		local function atomic_error(val)
			return {tostring(val)}
		end

		local function rec_find_error(dflt_subroot, check_subroot)
			local dflt_type = type(dflt_subroot)
			local check_type = type(check_subroot)

			if dflt_type ~= check_type then
				return atomic_error(check_subroot)
			end

			if dflt_type ~= "table" then
				if dflt_subroot ~= check_subroot then
					return atomic_error(check_subroot)
				end
			else
				for name, v in pairs(dflt_subroot) do
					local err = rec_find_error(v, check_subroot[name])
					if err then
						local myerr = atomic_error(name)
						myerr.next = err
						return myerr
					end
				end
			end
		end

		return function()
			local err = rec_find_error(dflts, _M)
			if err then
				local push = table.insert
				
				local keys = {}
				local val = nil

				while err.next do
					push(keys, err[1])
					err = err.next
				end
				val = assert( err[1] )
				err = err.next
				assert( err == nil )

				local msg = ("Constant %s = %s violates default assumptions.")
					:format(table.concat(keys, "."), val)

				return error(msg, 0)
			end
		end
	end)()

	---
	

	addConstants (nil) {
		DONT_STARVE_APPID = get.opt("DONT_STARVE_APPID", 219740),
		DONT_STARVE_TOGETHER_APPID = get.opt("DONT_STARVE_TOGETHER_APPID", 322330),
	}

	addDefaultConstants "SHARDID" {
		INVALID = "0", 
		MASTER = "1",
	}

	addDefaultConstants "REMOTESHARDSTATE" {
		OFFLINE = 0, 
		READY = 1, 
	}

	if IsDST() then
		addConstants("SHARDID", assert(_G.SHARDID))
		addConstants("REMOTESHARDSTATE", assert(_G.REMOTESHARDSTATE))
	else
		addConstants "SHARDID" {
			CAVE_PREFIX = "2",
		}
	end

	---
	
	validateConstants()
	return CONSTANTS_ENV()
end

---

local function include_introspectionlib(kernel)
	local get = NewGetter(kernel)

	local _G = get._G

	local assert, error = get.assert, get.error
	local VarExists = get.VarExists

	local type = get.type
	local rawget, rawset = get.rawget, get.rawset

	local getmetatable, setmetatable = get.getmetatable, get.setmetatable
	local table, math = get.table, get.math

	local pairs, ipairs = get.pairs, get.ipairs
	local next = get.next

	---
	
	local INTRO_ENV = make_inner_env(kernel)

	---
	
	IsWorldgen = memoize_0ary(function()
		return rawget(_G, "SEED") ~= nil
	end)
	local IsWorldgen = IsWorldgen
	IsWorldGen = IsWorldgen
	AtWorldgen = IsWorldgen
	AtWorldGen = IsWorldgen

	IfWorldgen = immutable_lambdaif(IsWorldgen)
	IfWorldGen = IfWorldgen

	---

	GetWorkshopId = memoize_0ary(function()
		local dirname = GetModDirectoryName():lower()
		local strid = dirname:match("^workshop%s*%-%s*(%d+)$")
		if strid ~= nil then
			return tonumber(strid)
		end
	end)
	GetSteamWorkshopId = GetWorkshopId
	local GetWorkshopId = GetWorkshopId

	IsWorkshop = function()
		return GetWorkshopId() ~= nil
	end
	IsSteamWorkshop = IsWorkshop
	local IsWorkshop = IsWorkshop


	---

	local GetSteamAppID
	local has_TheSim = VarExists("TheSim")
	if has_TheSim and _G.TheSim.GetSteamAppID then
		GetSteamAppID = function()
			return _G.TheSim:GetSteamAppID()
		end
	else
		GetSteamAppID = function()
			if IsDST() then
				return DONT_STARVE_TOGETHER_APPID
			else
				return DONT_STARVE_APPID
			end
		end
		if has_TheSim then
			getmetatable(_G.TheSim).__index.GetSteamAppID = GetSteamAppID
		end
	end
	GetSteamAppId = GetSteamAppID

	---

	if IsDST() then
		GetPlayerId = function(player)
			return player.userid
		end
	else
		GetPlayerId = One
	end
	GetPlayerID = GetPlayerId
	GetUserId = GetPlayerId
	GetUserID = GetPlayerID

	---

	local function is_vacuously_host()
		return IsWorldgen() or not IsMultiplayer()
	end

	IsHost = memoize_0ary(function()
		if is_vacuously_host() then
			return true
		else
			return _G.TheNet:GetIsServer() and true or false
		end
	end)
	local IsHost = IsHost
	IsServer = IsHost

	IsMasterSimulation = memoize_0ary(function()
		if is_vacuously_host() then
			return true
		else
			return _G.TheNet:GetIsMasterSimulation() and true or false
		end
	end)
	IsMasterSim = IsMasterSimulation

	IfHost = immutable_lambdaif(IsHost)
	IfServer = IfHost

	IfMasterSimulation = immutable_lambdaif(IsMasterSimulation)
	IfMasterSim = IfMasterSimulation

	IsClient = memoize_0ary(function()
		if is_vacuously_host() then
			return false
		else
			return _G.TheNet:GetIsClient() and true or false
		end
	end)

	IfClient = immutable_lambdaif(IsClient)

	IsDedicated = (function()
		if IsWorldgen() then
			return true
		elseif IsSingleplayer() then
			return false
		else
			return _G.TheNet:IsDedicated() and true or false
		end
	end)
	local IsDedicated = IsDedicated
	IsDedicatedHost = IsDedicated
	IsDedicatedServer = IsDedicated

	IfDedicated = immutable_lambdaif(IsDedicated)

	---

	local function can_be_shard()
		return IsDST() and IsServer() and not IsWorldgen() and VarExists("TheShard")
	end

	IsMasterShard = memoize_0ary(function()
		return can_be_shard() and _G.TheShard:IsMaster()
	end)

	IsSlaveShard = memoize_0ary(function()
		return can_be_shard() and _G.TheShard:IsSlave()
	end)

	IsShardedServer = memoize_0ary(function()
		return IsMasterShard() or IsSlaveShard()
	end)
	IsShard = IsShardedServer

	IfMasterShard = immutable_lambdaif(IsMasterShard)

	IfSlaveShard = immutable_lambdaif(IsSlaveShard)

	IfShardedServer = immutable_lambdaif(IsShardedServer)
	IfShard = IfShardedServer

	---
	
	local function getSaveIndex()
		return rawget(_G, "SaveGameIndex")
	end

	local function current_wrap(fn)
		return function(...)
			return fn(nil, ...)
		end
	end

	local function GetCurrentSaveSlot()
		local slot = nil

		local sg = getSaveIndex()
		if sg then
			slot = sg:GetCurrentSaveSlot()
		end

		return slot or 1
	end
	_M.GetCurrentSaveSlot = GetCurrentSaveSlot

	local GetSlotMode
	if IsDST() then
		GetSlotMode = const "survival"
	else
		GetSlotMode = function(slot)
			slot = slot or GetCurrentSaveSlot()
			local sg = getSaveIndex()
			if sg then
				return sg:GetCurrentMode(slot)
			end
		end
	end
	_M.GetSlotMode = GetSlotMode

	local GetCurrentMode = current_wrap(GetSlotMode)
	_M.GetCurrentMode = GetCurrentMode

	local function GetSlotData(slot)
		slot = slot or GetCurrentSaveSlot()
		local sg = getSaveIndex()
		if sg and sg.data and sg.data.slots then
			return sg.data.slots[slot]
		end
	end
	_M.GetSlotData = GetSlotData

	local GetCurrentSlotData = current_wrap(GetSlotData)
	_M.GetCurrentSlotData = GetCurrentSlotData

	-- In DS, returns current mode data.
	local GetSlotWorldData
	if IsDST() then
		GetSlotWorldData = function(slot)
			local slot_data = GetSlotData(slot)
			if slot_data then
				return slot_data.world
			end
		end
	else
		GetSlotWorldData = function(slot)
			slot = slot or GetCurrentSaveSlot()
			local sg = getSaveIndex()
			if sg then
				return sg:GetModeData(slot, GetSlotMode(slot))
			end
		end
	end

	local GetSlotCaveNum
	if IsDST() then
		GetSlotCaveNum = One
	else
		GetSlotCaveNum = function(slot)
			local sg = getSaveIndex()
			if sg then
				return sg:GetCurrentCaveNum(slot)
			end
		end
	end

	local GetCurrentCaveNum = current_wrap(GetSlotCaveNum)
	_M.GetCurrentCaveNum = GetCurrentCaveNum

	local GetSlotCaveLevel
	if IsDST() then
		GetSlotCaveLevel = Nil
	else
		GetSlotCaveLevel = function(slot, cavenum)
			local sg = getSaveIndex()
			if sg and GetSlotMode(slot) == "cave" then
				slot = slot or GetCurrentSaveSlot()
				cavenum = cavenum or GetSlotCaveNum(slot)
				return sg:GetCurrentCaveLevel(slot, cavenum)
			end
		end
	end

	---

	IsSWLevel = memoize_0ary(function()
		local sg = getSaveIndex()
		if sg then
			return sg:IsModeShipwrecked()
		end
	end)
	
	IfSWLevel = lambdaif(IsSWLevel)

	---

	local doGetShardId = memoize_0ary(function()
		if can_be_shard() then
			local id = _G.TheShard:GetShardId()
			assert( type(id) == "string" )
			return id
		else
			if IsWorldgen() or not IsServer() then
				return SHARDID.INVALID
			end

			if IsDST() or not getSaveIndex() then
				return nil
			end

			local cavenum = GetCurrentCaveNum()
			local cavelevel = GetCurrentCaveLevel()

			if cavenum and cavelevel then
				local prefix = assert( SHARDID.CAVE_PREFIX )
				return ("%s.%d.%d"):format(prefix, cavenum, cavelevel)
			else
				return SHARDID.MASTER
			end
		end
	end)

	local function GetShardId()
		local id = doGetShardId()
		if id == nil then
			return SHARDID.INVALID
		end
	end
	_M.GetShardId = GetShardId
	_M.GetShardID = GetShardId

	---
	
	return INTRO_ENV()
end

---

local function include_auxlib(kernel)
	local get = NewGetter(kernel)

	local _G = get._G

	local assert, error = get.assert, get.error
	local VarExists = get.VarExists

	local type = get.type
	local rawget, rawset = get.rawget, get.rawset

	local getmetatable, setmetatable = get.getmetatable, get.setmetatable
	local table, math = get.table, get.math

	local pairs, ipairs = get.pairs, get.ipairs
	local next = get.next

	---

	local AUXLIB_ENV = make_inner_env(kernel)

	---
	
	GetTick = get.opt("GetTick", Zero)
	GetTime = get.opt("GetTime", get.os.clock or Zero)
	GetTimeReal = get.opt("GetTimeReal", GetTime)
	FRAMES = get.opt("FRAMES", 1/60)

	if VarExists "FRAMES" then
		FRAMES = _G.FRAMES
	else
		FRAMES = 1/60
	end

	if VarExists "TheSim" then
		GetTickTime = memoize_0ary(function()
			return _G.TheSim:GetTickTime()
		end)
	else
		GetTickTime = function()
			return 1/30
		end
	end
	local GetTickTime = GetTickTime

	GetTicksPerSecond = memoize_0ary(function()
		return 1/GetTickTime()
	end)
	local GetTicksPerSecond = GetTicksPerSecond

	GetTicksForInterval = (function()
		local floor = math.floor
		return function(dt)
			return floor(dt*GetTicksPerSecond())
		end
	end)()
	GetTicksInInterval = GetTicksForInterval

	GetTicksCoveringInterval = (function()
		local ceil = math.ceil
		return function(dt)
			return ceil(dt*GetTicksPerSecond())
		end
	end)()

	-- Returns an __index metamethod.
	function LazyCopier(source, filter)
		if not filter then
			return function(t, k)
				local v = source[k]
				if v ~= nil then
					rawset(t, k, v)
				end
				return v
			end
		elseif type(filter) == "table" then
			return function(t, k)
				if filter[k] then
					local v = source[k]
					if v ~= nil then
						rawset(t, k, v)
					end
					return v
				end
			end
		elseif type(filter) == "function" then
			return function(t, k)
				if filter(k) then
					local v = source[k]
					if v ~= nil then
						rawset(t, k, v)
					end
					return v
				end
			end
		else
			return error("Invalid filter given to LazyCopier.", 2)
		end
	end

	local function require_metatable(object)
		local meta = getmetatable( object )
		if meta == nil then
			meta = {}
			setmetatable( object, meta )
		end
		return meta
	end

	local function NewMetamethodChainer(name, tablehandler)
		assert(type(name) == "string")
		assert(tablehandler == nil or type(tablehandler) == "function")

		local metakey = "__"..name
		local metachainkey = {}

		local function accessor(t, ...)
			local chain = rawget(getmetatable(t), metachainkey)
			if not chain then return end

			for i = #chain, 1, -1 do
				local metamethod = chain[i]
				local v
				if type(metamethod) == "function" then
					v = metamethod(t, ...)
				elseif tablehandler ~= nil then
					v = tablehandler(metamethod, ...)
				end
				if v ~= nil then
					return v
				end
			end
		end

		-- If last, it is put in front, because we are using a stack.
		local function include(chain, newv, last)
			if last then
				table.insert(chain, 1, newv)
			else
				table.insert(chain, newv)
			end
			return chain
		end

		local function attach(t, fn, last)
			local meta = require_metatable(t)

			local chain = rawget(meta, metachainkey)
			if chain then
				include(chain, fn, last)
			else
				local oldfn = rawget(meta, metakey)
				if oldfn then
					rawset(meta, metachainkey, include({oldfn, nil}, fn, last))
					rawset(meta, metakey, accessor)
				else
					rawset(meta, metakey, fn)
				end
			end

			return t
		end

		local function count(t)
			local meta = getmetatable(t)
			if meta == nil then return 0 end

			local chain = rawget(meta, metachainkey)
			if chain then
				return #chain
			else
				if rawget(meta, metakey) then
					return 1
				else
					return 0
				end
			end
		end

		return attach, count
	end

	local function table_get(t, k)
		return t[k]
	end

	local function table_set(t, k, v)
		t[k] = v
	end

	AttachMetaIndexTo, CountMetaIndexes = NewMetamethodChainer("index", table_get)
	local AttachMetaIndexTo, CountMetaIndexes = AttachMetaIndexTo, CountMetaIndexes

	function AttachMetaIndex(fn, t, last)
		return AttachMetaIndexTo(t, fn, last)
	end

	AttachMetaNewIndexTo, CountMetaNewIndexes = NewMetamethodChainer("newindex", table_set)
	local AttachMetaNewIndexTo, CountMetaNewIndexes = AttachMetaNewIndexTo, CountMetaNewIndexes

	function AttachMetaNewIndex(fn, t, last)
		return AttachMetaNewIndexTo(t, fn, last)
	end

	local props_getters_metakey = {}
	local props_setters_metakey = {}

	local function property_index(object, k)
		local props = rawget(getmetatable(object), props_getters_metakey)
		if props == nil then return end

		local fn = props[k]
		if fn ~= nil then
			return fn(object, k, props)
		end
	end

	local function property_newindex(object, k, v)
		local props = rawget(getmetatable(object), props_setters_metakey)
		if props == nil then return end

		local fn = props[k]
		if fn ~= nil then
			fn(object, k, v, props)
			return true
		end
	end

	function AddPropertyTo(object, k, getter, setter)
		local meta = require_metatable(object)
		if getter ~= nil then
			local getters = rawget(meta, props_getters_metakey)
			if not getters then
				getters = {}
				rawset(meta, props_getters_metakey, getters)
				AttachMetaIndexTo(object, property_index)
			end
			getters[k] = getter
		end
		if setter ~= nil then
			local setters = rawget(meta, props_setters_metakey)
			if not setters then
				setters = {}
				rawset(meta, props_setters_metakey, setters)
				if CountMetaNewIndexes(object) == 0 then
					AttachMetaNewIndexTo(object, rawset, true)
				end
				AttachMetaNewIndexTo(object, property_newindex)
			end
			setters[k] = setter
		end
	end
	local AddPropertyTo = AddPropertyTo

	function AddLazyVariableTo(object, k, fn)
		local function getter(object, k, props)
			local v = fn(k, object)
			if v ~= nil then
				props[k] = nil
				rawset(object, k, v)
			end
			return v
		end

		return AddPropertyTo(object, k, getter)
	end
	local AddLazyVariableTo = AddLazyVariableTo


	function InjectNonPrivatesIntoTableIf(p, t, f, s, var)
		for k, v in f, s, var do
			if type(k) == "string" and not k:match('^_') then
				if p(k, v) then
					t[k] = v
				end
			end
		end
		return t
	end
	
	function InjectNonPrivatesIntoTable(t, f, s, var)
		t = InjectNonPrivatesIntoTableIf(function() return true end, t, f, s, var)
		return t
	end

	---
	
	return AUXLIB_ENV()
end

----------

return function()
	local kernel = _M

	---

	include_corelib(kernel)
	PLATFORM_DETECTION = include_platform_detection_functions(kernel)
	include_constants(kernel)
	include_introspectionlib(kernel)
	include_auxlib(kernel)

	---

	assert( IsDST )
end
