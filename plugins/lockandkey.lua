local Lambda = wickerrequire "paradigms.functional"
local Logic = wickerrequire "lib.logic"
local Pred = wickerrequire "lib.predicates"


-------


require "map/lockandkey"

local KEYS_ARRAY = _G.KEYS_ARRAY
local KEYS = _G.KEYS

local LOCKS_ARRAY = _G.LOCKS_ARRAY
local LOCKS = _G.LOCKS

local LOCKS_KEYS = _G.LOCKS_KEYS


-------


local function id_generator_for(array)
	return function()
		return #array + 1
	end
end

-- Returns a new unique key/lock id whenever called.
local new_key_id = id_generator_for(KEYS_ARRAY)
local new_lock_id = id_generator_for(LOCKS_ARRAY)


-------


local function AddKey(name)
	assert( Pred.IsString(name), "String expected as key name." )
	assert( KEYS[name] == nil, "Key "..name.." already exists!" )

	local id = new_key_id()

	KEYS_ARRAY[id] = name
	KEYS[name] = id
end
TheMod:EmbedAdder("Key", AddKey)

local function AddLock(name, keys)
	assert( Pred.IsString(name), "String expected as lock name." )
	assert( LOCKS[name] == nil, "Lock "..name.." already exists!" )
	assert( Pred.IsTable(keys) and #keys > 0, "Non-empty array expected as set of keys unlocking "..name.."!" )
	if TheMod:Debug() then
		for i = 1, #keys do
			if KEYS_ARRAY[keys[i]] == nil then
				error("Invalid "..i.."th key for lock "..name.."!")
			end
		end
	end
	
	local id = new_lock_id()

	LOCKS_ARRAY[id] = name
	LOCKS[name] = id
	LOCKS_KEYS[id] = keys
end
TheMod:EmbedAdder("Lock", AddLock)


-------


local function invert_array(t)
	local u = {}
	for i, v in ipairs(t) do
		u[v] = i
	end
	return u
end

local function get_lock(id)
	local ret = LOCKS_KEYS[id]
	if ret == nil then
		return error("Invalid lock id "..tostring(id)..".")
	end
	return ret
end

-- Performs a logical "and" in the locks.
-- Returns the resulting array of keys.
function LockAnd(a, b)
	local A, B = get_lock(a), get_lock(b)
	local invA = invert_array(A)

	return Lambda.CompactlyFilter(Lambda.Getter(invA), ipairs(B))
end

-- Performs a logical "or" in the locks.
-- Returns the resulting array of keys.
function LockOr(a, b)
	local A, B = get_lock(a), get_lock(b)
	local invA = invert_array(A)

	local Acopy = Lambda.CompactlyInjectInto({}, ipairs(A))

	return Lambda.CompactlyFilterInto(Lambda.Not(Lambda.Getter(invA)), Acopy, ipairs(B))
end
