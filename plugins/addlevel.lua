local MyAddLevel
if not IsDST() then
	MyAddLevel = modenv.AddLevel 
else
	local function extractSubtable(t, ...)
		local ret = {}
		for _, k in ipairs{...} do
			ret[k] = t[k]
			t[k] = nil
		end
		return ret
	end

	local startloc_extraction_set = {
		start_setpeice = true,
		start_node = true,
	}

	local function extractStartLocation(data)
		local startloc_data = {
			name = data.name,
			location = data.location,
		}

		local i = 1
		while i <= #data.overrides do
			local v = data.overrides[i]
			if startloc_extraction_set[v[1]] then
				startloc_data[v[1]] = v[2]
				table.remove(data.overrides, i)
			else
				i = i + 1
			end
		end

		return startloc_data
	end

	local function extractTaskSet(data)
		local taskset_data = extractSubtable(data,
			"tasks",
			"numoptionaltasks",
			"optionaltasks",
			"set_pieces",
			"valid_start_tasks"
			)

		taskset_data.name = data.name
		taskset_data.location = assert( data.location )
		taskset_data.hideinfrontend = false

		return taskset_data
	end

	MyAddLevel = function(leveltype, data)
		local Tree = wickerrequire "utils.table.tree"
		data = Tree.InjectInto({}, data)

		require "map/tasks"
		require "map/startlocations"

		assert(data.id)
		assert(data.location, "DST requires level data to specify a location")

		local startloc_data = extractStartLocation(data)
		local taskset_data = extractTaskSet(data)

		local startloc_id = data.id.."_startloc"
		local taskset_id = data.id.."_taskset"

		_G.AddStartLocation(startloc_id, startloc_data)
		_G.AddTaskSet(taskset_id, taskset_data)

		table.insert(data.overrides, {"task_set", taskset_id})
		table.insert(data.overrides, {"start_location", startloc_id})

		return modenv.AddLevel(leveltype, data)
	end
end
TheMod:EmbedAdder("Level", MyAddLevel)

return MyAddLevel
