local Lambda = wickerrequire "paradigms.functional"
local Pred = wickerrequire "lib.predicates"

if IsWorldgen() then
	init = Lambda.Nil
	return
end

require "recipe"

local GRecipe = assert( _G.Recipe )

if not IsDST() then
	function init(kernel)
		kernel.Recipe = GRecipe
		kernel.Ingredient = _G.Ingredient
	end
	return
end

---

-- ugly hack, but necessary for robustness.
local VSK_MAGIC_STRING = "wicker\a\bVSK_"

local VirtualSortKey = Class(function(self, recipe, value)
	self.recipe = recipe
	self:SetValue(value)
end)
local IsVirtualSortKey = Pred.IsInstanceOf(VirtualSortKey)

function VirtualSortKey:GetValue()
	return self.value
end

function VirtualSortKey:SetValue(v)
	if IsVirtualSortKey(v) then
		v = v:GetValue()
	end
	self.value = v
end

-- For sorting.
function VirtualSortKey:__lt(x)
	if type(x) ~= "number" then
		x = x:GetValue()
	end
	return self:GetValue() < x
end

-- For RPC calls. Only matches if the recipe matches.
function VirtualSortKey:__eq(key)
	if IsVirtualSortKey(key) then
		return self.recipe == key.recipe
	end
end

VirtualSortKey.serialization_type = "string"

function VirtualSortKey:Serialize()
	return VSK_MAGIC_STRING..assert( self.recipe.name )
end

local VSK_DESERIAL_MATCH_STR = "^"..VSK_MAGIC_STRING.."(.+)$"

-- Class function.
function VirtualSortKey.CanDeserialize(str)
	return str:find(VSK_DESERIAL_MATCH_STR) ~= nil
end

-- Class function.
function VirtualSortKey.Deserialize(str)
	local recname = str:match(VSK_DESERIAL_MATCH_STR)
	if recname == nil then return end

	local rec = _G.AllRecipes[recname]
	if rec == nil then
		local msg = "No recipe with name '"..recname.."' was found on VirtualSortKey deserialization."
		if TheMod:Debug() then
			return error(msg)
		else
			TheMod:Warn(msg, " Application may misbehave.")
		end
		return
	end

	local sortkey = rec.sortkey
	if IsVirtualSortKey(sortkey) then
		return sortkey
	else
		return VirtualSortKey(rec, rec.sortkey)
	end
end

---

local SHOULD_RETURN_RAW_SORTKEY = false

local RecipeCompat = Class(GRecipe, function(self, ...)
	GRecipe(self, ...)

	rawset(self, VirtualSortKey, assert( rawget(self, "sortkey") ))
	rawset(self, "sortkey", nil)
end)

function RecipeCompat:__index(k)
	if k == "sortkey" then
		local virtkey = rawget(self, VirtualSortKey)
		if SHOULD_RETURN_RAW_SORTKEY then
			return virtkey:GetValue()
		else
			return virtkey
		end
	end
	return RecipeCompat[k]
end

function RecipeCompat:__newindex(k, v)
	if k == "sortkey" then
		rawget(self, VirtualSortKey):SetValue(v)
	end
	rawset(self, k, v)
end

---

TheMod:AddClassPostConstruct("widgets/crafting", function(widget)
	widget.UpdateRecipes = (function()
		local UpdateRecipes = widget.UpdateRecipes
		return function(widget, ...)
			SHOULD_RETURN_RAW_SORTKEY = true
			local rets = { UpdateRecipes(widget, ...) }
			SHOULD_RETURN_RAW_SORTKEY = false
			return unpack(rets)
		end
	end)()
end)

---

local PatchHandler = (function()
	local RPC_HANDLERS = pkgrequire "rpc.common" .GetVanillaRPCHandlers()

	---
	
	local function serialize(...)
		local nargs = select("#", ...)
		local args = {...}
		for i = 1, nargs do
			local arg = args[i]
			if IsVirtualSortKey(arg) then
				args[i] = arg:Serialize()
			elseif type(arg) ==  VirtualSortKey.serialization_type and VirtualSortKey.CanDeserialize(arg) then
				return error("RPC call argument '"..tostring(arg).."' conflicts with wicker's serialization scheme for VirtualSortKeys.", 2)
			end
		end
		return unpack(args)
	end

	local function deserialize(...)
		local nargs = select("#", ...)
		local args = {...}
		for i = 1, nargs do
			local arg = args[i]
			if type(arg) == VirtualSortKey.serialization_type then
				local vsk = VirtualSortKey.Deserialize(arg)
				if vsk ~= nil then
					args[i] = vsk
				end
			end
		end
		return unpack(args)
	end

	---

	local patched_codeset = {}

	local applied_serialization_patch = false
	local function apply_serialization_patch()
		if applied_serialization_patch then return end
		applied_serialization_patch = true

		_G.SendRPCToServer = (function()
			local SendRPCToServer = assert( _G.SendRPCToServer )
			return function(code, ...)
				if patched_codeset[code] then
					return SendRPCToServer(code, serialize(...))
				else
					return SendRPCToServer(code, ...)
				end
			end
		end)()
	end

	---

	return function(code)
		apply_serialization_patch()

		assert(not patched_codeset[code])
		patched_codeset[code] = true

		local fn = assert( RPC_HANDLERS[code] )
		RPC_HANDLERS[code] = function(player, ...)
			return fn(player, deserialize(...))
		end
	end
end)()

assert( _G.RPC )
for name, code in pairs(_G.RPC) do
	if name == "BufferBuild" or name:find("Recipe") then
		PatchHandler(code)
	end
end

---

function init(kernel)
	kernel.Recipe = RecipeCompat
	kernel.Ingredient = _G.Ingredient
end
