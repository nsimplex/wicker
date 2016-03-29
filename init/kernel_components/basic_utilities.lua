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

local function Zero()
	return 0
end

local function One()
	return 1
end

----------

local function include_platform_detection_functions(_G, kernel)
	local PLATFORM_DETECTION = {}

	local assert = _G.assert
	local VarExists = assert( kernel.VarExists )

	local rawget = _G.rawget
	local rawset = _G.rawset

	local getmetatable = _G.getmetatable
	local setmetatable = _G.setmetatable

	local type = _G.type

	local pairs = _G.pairs
	local ipairs = _G.ipairs

	local next = _G.next

	local detect_meta = {
		__index = kernel,
		__newindex = function(t, k, v)
			kernel[k] = v
			rawset(t, k, v)
		end,
	}

	setmetatable(PLATFORM_DETECTION, detect_meta)

	---
	
	_G.setfenv(1, PLATFORM_DETECTION)

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

	GetShardId = memoize_0ary(function()
		if cab_be_shard() then
			local id = _G.TheShard:GetShardId()
			assert( type(id) == "string" )
			return id
		else
			return "1"
		end
	end)

	---

	if VarExists("IsDLCEnabled") then
		IsDLCEnabled = _G.IsDLCEnabled
	else
		IsDLCEnabled = Lambda.False
	end
	if VarExists("IsDLCInstalled") then
		IsDLCInstalled = _G.IsDLCInstalled
	else
		IsDLCInstalled = IsDLCEnabled
	end
	if VarExists("REIGN_OF_GIANTS") then
		REIGN_OF_GIANTS = _G.REIGN_OF_GIANTS
	else
		REIGN_OF_GIANTS = 1
	end
	if VarExists("CAPY_DLC") then
		CAPY_DLC = _G.CAPY_DLC
	else
		CAPY_DLC = 2
	end

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

	IsSWLevel = memoize_0ary(function()
		if VarExists "SaveGameIndex" then
			return SaveGameIndex:IsModeShipwrecked()
		end
	end)

	IfRoG = immutable_lambdaif(IsRoG)
	IfROG = IfRoG

	IfSW = immutable_lambdaif(IsSW)

	IfSWLevel = lambdaif(IsSWLevel)

	if VarExists("DONT_STARVE_APPID") then
		DONT_STARVE_APPID = _G.DONT_STARVE_APPID
	else
		DONT_STARVE_APPID = 219740
	end

	if VarExists("DONT_STARVE_TOGETHER_APPID") then
		DONT_STARVE_TOGETHER_APPID = _G.DONT_STARVE_TOGETHER_APPID
	else
		DONT_STARVE_TOGETHER_APPID = 322330
	end

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
	GetUserId = GetPlayerId

	---

	detect_meta.__newindex = nil
	return PLATFORM_DETECTION
end

----------

return function()
	local _G = _G

	local assert, error = assert( _G.assert ), assert( _G.error )
	local type = assert( _G.type )
	local rawget = assert( _G.rawget )
	local rawset = assert( _G.rawset )
	local getmetatable = assert( _G.getmetatable )
	local setmetatable = assert( _G.setmetatable )
	local table = assert( _G.table )
	local math = assert( _G.math )

	_M.memoize_0ary = assert( memoize_0ary )
	_M.memoise_0ary = assert( memoize_0ary )

	PLATFORM_DETECTION = include_platform_detection_functions(_G, assert(_M))
	assert( IsDST )

	if VarExists "GetTick" then
		GetTick = _G.GetTick
	else
		GetTick = Zero
	end
	if VarExists "GetTime" then
		GetTime = _G.GetTime
	else
		GetTime = _G.os.clock or Zero
	end
	if VarExists "GetTimeReal" then
		GetTimeReal = _G.GetTimeReal
	else
		GetTimeReal = GetTime
	end
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
end
