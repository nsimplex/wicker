local levels = require "map/levels"

---

local AddLevel
local AddStartLocation, GetStartLocation
local AddTaskSet

local SerializeLevelOverrides

---

local type = type
local ipairs = ipairs
local pairs = pairs

--- 

local STARTLOCATION_ENTRIES = {
	"start_setpeice",
	"start_node",
}

local TASKSET_ENTRIES = {
	"tasks",
	"numoptionaltasks",
	"optionaltasks",
	"set_pieces",
	"valid_start_tasks",
}

--- 

-- Table of recursive fixes to data entry strings.
local recdata_fixes = {}

local type = type
function recdata_fixes.set_peice(k, v)
	if type(k) ~= "string" then return end

	local dual = k:gsub("set_piece", "set_peice")
	if k == dual then
		dual = k:gsub("set_peice", "set_piece")
	end
	if k ~= dual then
		return dual, v
	end
end

-- Applies said fixes.
local fixData, fixDataPair, fixDataEntry = (function()
	local type = assert( type )
	local pairs = assert( pairs )

	local push = assert( table.insert )

	local function inspect_outcome(k, v, k2, v2)
		if k2 == nil then
			v2 = nil
		else
			if k2 == k then
				if v2 == nil then
					return nil, nil
				else
					v = v2
					v2 = nil
				end
			else
				if v2 == nil then
					v2 = v
				end
			end
		end
		return v, v2
	end

	local function fixpair(accum, p)
		local topush = nil
		for _, fix in ipairs(recdata_fixes) do
			local k, v = p[1], p[2]
			local k2, v2 = fix(k, v)

			if k2 ~= nil then
				topush = topush or {}

				v, v2 = inspect_outcome(k, v, k2, v2)
				if v == nil then
					p = nil
					break
				else
					p[2] = v
				end

				if v2 ~= nil then
					local p2 = {}
					for pk, pv in pairs(p) do
						p2[pk] = pv
					end
					p2[1], p2[2] = k2, v2
					push(topush, p2)
				end
			end
		end
		if p ~= nil then
			push(accum, p)
			if topush then
				for _, q in ipairs(topush) do
					push(accum, q)
				end
			end
		end
		return accum
	end

	local function fixdictentry(accum, k, v)
		local accum_k = v

		local toadd = nil
		for _, fix in ipairs(recdata_fixes) do
			local k2, v2 = fix(k, v)

			if k2 ~= nil then
				toadd = toadd or {}

				v, v2 = inspect_outcome(k, v, k2, v2)

				if v == nil then
					accum_k = nil
					break
				else
					accum_k = v
				end

				if k2 ~= nil then
					toadd[k2] = v2
				end
			end
		end
		accum[k] = accum_k
		if accum_k ~= nil and toadd then
			for k2, v2 in pairs(toadd) do
				accum[k2] = v2
			end
		end
		return accum
	end

	local function recfix(data)
		local ret = {}

		local already_fixed = {}

		local ndata = #data
		for i = 1, ndata do
			local p = data[i]
			if #p == 2 then
				fixpair(ret, p)
				already_fixed[i] = true
			end
		end

		for k, v in pairs(data) do
			if not already_fixed[k] then
				if type(v) == "table" then
					v = recfix(v)
				end
				fixdictentry(ret, k, v)
				ret[k] = v
				for _, fix in ipairs(recdata_fixes) do
					local k2, v2 = fix(k, v)
					if k2 ~= nil then
						ret[k2] = v2
					end
				end
			end
		end

		return ret
	end

	local function fixdata(data)
		-- Top level fixes.

		data.location = data.location or GetStartLocation"default".location

		return recfix(data)
	end

	return fixdata, fixpair, fixdictentry
end)()


-- Receives a set of overrides to fetch.
local function fetchOverrides(data, set)
	local ret = {}
	for _, p in ipairs(data.overrides) do
		local k, v = p[1], p[2]
		if set[k] then
			ret[k] = v
		end
	end
	return ret
end

local function normalizePair(k, v)
	assert( k ~= nil )
	if v == nil and type(k) == "table" then
		return k[1], k[2]
	else
		return k, v
	end
end

local function NewArrayAdder(data)
	return function(k, v)
		fixDataPair(data, {normalizePair(k, v)})
	end
end

local function NewEntryAdder(data)
	return function(k, v)
		fixDataEntry(data, normalizePair(k, v))
	end
end

--[[
-- Expands level data overrides which may contain, possibly partially,
-- dictionary-style definitions as may be used in worldgenoverride.
--]]
local function expandOverrides(overrides)
	local type = type

	local subgroups = {}

	local olds = overrides or {}
	local news = {}

	local nolds = #olds
	for i = 1, nolds do
		local old = olds[i]
		news[old[1]] = old[2]
	end

	for k, v in pairs(olds) do
		local ty = type(k)
		if ty == "number" and (k <= 0 or k > nolds) then
			local old = olds[k]
			news[old[1]] = old[2]
		elseif ty == "string" then
			if type(v) == "table" then
				v = expandOverrides(v)
				subgroups[k] = v
				for sk, sv in pairs(v) do
					news[sk] = sv
				end
			end
			news[k] = v
		end
	end

	return news
end

-- Opposite of expandOverrides().
local shrinkOverrides = (function()
	local type = type
	local push = table.insert

	local function recshrink(olds, news, visited)
		local type = type
		local push = push
		for k, v in pairs(olds) do
			if type(k) == "string" and not visited[k] then
				visited[k] = true
				if type(v) == "table" then
					recshrink(v, news, visited)
				else
					push(news, {k, v})
				end
			end
		end
		return news
	end

	return function(overrides)
		return recshrink(overrides or {}, {}, {})
	end
end)()

local leveltype_map = {
	[_G.LEVELTYPE.ADVENTURE] = "story_levels",
	[_G.LEVELTYPE.SURVIVAL] = "sandbox_levels",
	[_G.LEVELTYPE.CAVE] = "cave_levels",
	[_G.LEVELTYPE.TEST] = "test_levels",
	[_G.LEVELTYPE.CUSTOM] = "custom_levels",
}

-- Returns a table in the format of worldgenoverride.lua
local function GetLevelWorldgenOverrides(id, flatten)
	assert( id )

	local leveltype = assert( levels.GetTypeForLevelID(id) )

	local GetGroupForItem = assert( require "map/customise".GetGroupForItem )

	local data
	local levellist = assert( levels[leveltype_map[leveltype]] )
	for _, mbdata in pairs(levellist) do
		if mbdata.id == id then
			data = mbdata
			break
		end
	end

	assert( data )

	local overrides = {}

	for _, p in ipairs(data.overrides or {}) do
		local gname
		if flatten then
			gname = "overrides"
		else
			gname = GetGroupForItem(p[1])
		end
		local g = overrides[gname]
		if g == nil then
			g = {}
			overrides[gname] = g
		end
		g[p[1]] = p[2]
	end

	overrides.override_enabled = true
	overrides.preset = data.id

	return overrides
end

---

local function extractSubtable(t, ks)
	local ret = {}
	for _, k in ipairs(ks) do
		ret[k] = t[k]
		t[k] = nil
	end
	return ret
end

local function extractStartLocation(data)
	assert(data.id)

	if data.overrides.start_location then
		return data.overrides.start_location
	end

	local startloc_data = extractSubtable(data.overrides, STARTLOCATION_ENTRIES)

	startloc_data.name = assert( data.name )
	startloc_data.location = assert( data.location )

	local startloc_id = data.id.."_startloc"

	AddStartLocation(startloc_id, startloc_data)
	data.overrides.start_location = startloc_id

	return startloc_id
end

local function extractTaskSet(data)
	assert(data.id)

	if data.overrides.task_set then
		return data.overrides.task_set
	end

	local taskset_data = extractSubtable(data, TASKSET_ENTRIES)

	taskset_data.name = assert( data.name )
	taskset_data.location = assert( data.location )
	taskset_data.hideinfrontend = false

	local taskset_id = data.id.."_taskset"

	AddTaskSet(taskset_id, taskset_data)
	data.overrides.task_set = taskset_id

	return taskset_id
end

local function extractLevelData(data)
	extractStartLocation(data)
	extractTaskSet(data)
end

---

if not IsDST() then
	local startlocations = {}

	AddStartLocation = function(id, data)
		startlocations[id] = fixData(data)
	end

	GetStartLocation = function(id)
		return startlocations[id]
	end

	AddStartLocation("default", {
		name = "Default Start",
		location = "forest",
		start_setpeice = "DefaultStart",
		start_node = "Clearing",
	})

	local default_start_location = GetStartLocation "default"

	---
	
	local tasksets = {}

	AddTaskSet = function(id, data)
		tasksets[id] = fixData(data)
	end

	local function GetTaskSet(id)
		return tasksets[id]
	end

	-- I won't add the default taskset, way too big for a probably useless
	-- inclusion.

	---
	

	local function expandStartLocation(addoverride, startloc_id)
		if not startloc_id then return end

		local startloc_data = GetStartLocation(startloc_id)
		if not startloc_data then
			return error( ("Attempt to use inexistent start location %q."):format(tostring(startloc_id)) )
		end

		for _, k in ipairs(STARTLOCATION_ENTRIES) do
			local v = startloc_data[k]
			if v ~= nil then
				addoverride(k, v)
			end
		end
	end

	local function expandTaskSet(addentry, taskset_id)
		if not taskset_id then return end

		local taskset_data = GetTaskSet(taskset_id)
		if not taskset_data then
			return error( ("Attempt to use inexistent task set %q."):format(tostring(taskset_id)) )
		end

		for _, k in ipairs(TASKSET_ENTRIES) do
			local v = taskset_data[k]
			if v ~= nil then
				addentry(k, v)
			end
		end
	end

	---

	AddLevel = function(leveltype, data, ...)
		data.overrides = expandOverrides(data.overrides)
		data = fixData(data)

		assert(data.id)
		assert(data.location, "DST requires level data to specify a location")

		local addoverride = NewEntryAdder(data.overrides)
		local addentry = NewEntryAdder(data)

		local startloc_id = data.overrides.start_location
		local taskset_id = data.overrides.task_set

		if startloc_id then
			expandStartLocation(addoverride, startloc_id)
		else
			extractStartLocation(data)
		end

		if taskset_id then
			expandTaskSet(addentry, taskset_id)
		else
			extractTaskSet(data)
		end

		data.overrides = shrinkOverrides(data.overrides)

		return modenv.AddLevel(leveltype, data, ...)
	end
else
	require "map/startlocations"
	require "map/tasks"

	local function fixwrap(f)
		assert( f )
		return function(id, data, ...)
			return f(id, fixData(data), ...)
		end
	end

	AddStartLocation = fixwrap( _G.AddStartLocation )
	GetStartLocation = assert( _G.GetStartLocation )
	AddTaskSet = fixwrap( _G.AddTaskSet )

	---

	AddLevel = function(leveltype, data, ...)
		data.overrides = expandOverrides(data.overrides)
		data = fixData(data)

		assert(data.id)
		assert(data.location, "DST requires level data to specify a location")

		extractLevelData(data)

		data.overrides = shrinkOverrides(data.overrides)

		return modenv.AddLevel(leveltype, data, ...)
	end

end
TheMod:EmbedFunction("GetLevelWorldgenOverrides", GetLevelWorldgenOverrides)
TheMod:EmbedAdder("StartLocation", AddStartLocation)
TheMod:EmbedFunction("GetStartLocation", GetStartLocation)
TheMod:EmbedAdder("TaskSet", AddTaskSet)
TheMod:EmbedAdder("Level", AddLevel)

return AddLevel
