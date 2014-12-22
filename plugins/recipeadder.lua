local Lambda = wickerrequire "paradigms.functional"
local Pred = wickerrequire "lib.predicates"
local Debuggable = wickerrequire "adjectives.debuggable"

require "recipe"

local default_atlas_path = _G.resolvefilepath("images/inventoryimages.xml")

local rawget, rawset = _G.rawget, _G.rawset

assert( Recipe )

---

local RecipeWrapper = Class(function(self, ...)
	rawset(self, "recipe", Recipe(...))
	rawset(self, "setters", {})
end)

function RecipeWrapper:GetRecipe()
	return rawget(self, "recipe")
end

function RecipeWrapper:GetName()
	return tostring(self:GetRecipe().name)
end

local recipe_nillable_fields = {
	placer = true,
}

local function RecipeWrapper_index(self, k)
	local setters = rawget(self, "setters")
	local fn = setters[k]
	if fn == nil then
		local is_not_nillable = not recipe_nillable_fields[k]
		if is_not_nillable and self:GetRecipe()[k] == nil then
			return error("Attempt to set invalid field '"..tostring(k).."' in the Recipe object for "..self:GetName()..".", 3)
		end
		fn = function(val)
			if is_not_nillable and val == nil then
				return error("Attempt to set "..self:GetName().." Recipe field '"..tostring(k).."' to nil.", 2)
			end
			self:GetRecipe()[k] = val
			return self
		end
		setters[k] = fn
	end
	return fn
end

-- newindex
local function RecipeWrapper_newindex(self, k, v)
	self:GetRecipe()[k] = v
end

function RecipeWrapper:__index(k)
	local v = RecipeWrapper[k]
	if v ~= nil then
		return v
	else
		return RecipeWrapper_index(self, k)
	end
end

RecipeWrapper.__newindex = RecipeWrapper_newindex

---

local ModIngredient = Class(_G.Ingredient, function(self, type, amount, atlas, ...)
	_G.Ingredient._ctor(self, type, amount, atlas, ...)

	if not atlas then
		self.has_default_atlas = true
	else
		self.has_default_atlas = false
	end
end)
local IsModIngredient = Pred.IsInstanceOf(ModIngredient)

function ModIngredient:HasDefaultAtlas()
	return self.has_default_atlas
end

function ModIngredient:GetPrefab()
	return self.type
end

---

local NestedRecipeAdder = Class(function(self, parent)
	rawset(self, "parent", parent)
	--rawset(self, "is_tracking", nil)
	--self.default_atlas_fn = nil
end)

function NestedRecipeAdder:GetParent()
	return rawget(self, "parent")
end

function NestedRecipeAdder:IsTracking()
	local is_tracking = rawget(self, "is_tracking")
	if is_tracking ~= nil then
		return is_tracking
	else
		local parent = self:GetParent()
		if parent ~= nil then
			return parent:IsTracking()
		end
	end
end
NestedRecipeAdder.IsTrackingRecipes = NestedRecipeAdder.IsTracking

function NestedRecipeAdder:TrackRecipes(b)
	rawset(self, "is_tracking", b and true or false)
end

function NestedRecipeAdder:AddTrackedRecipe(rec)
	local parent = self:GetParent()
	if parent ~= nil then
		return parent:AddTrackedRecipe(rec)
	end
end

function NestedRecipeAdder:GetDefaultAtlas(prefab)
	local fn = rawget(self, "default_atlas_fn")
	if fn ~= nil then
		return fn(prefab)
	else
		local parent = self:GetParent()
		if parent ~= nil then
			return parent:GetDefaultAtlas(prefab)
		else
			return default_atlas_path
		end
	end
end

function NestedRecipeAdder:SetDefaultAtlasFn(fn)
	rawset(self, "default_atlas_fn", fn)
end

for _, method_name in ipairs{"GetTab", "GetTech", "GetPrefab"} do
	NestedRecipeAdder[method_name] = function(self)
		local parent = self:GetParent()
		if parent ~= nil then
			return parent[method_name](parent)
		end
	end
end

NestedRecipeAdder.__newindex = Lambda.Error( "Attempt to set new index on NestedRecipeAdder object." )

---

local BasicRecipeAdder = Class(NestedRecipeAdder, function(self)
	NestedRecipeAdder._ctor(self, nil)
	
	self:TrackRecipes(false)

	rawset(self, "tracked_recipes", setmetatable(
		{},
		{
			__mode = "v",
		}
	))
end)

function BasicRecipeAdder:GetTrackedRecipes()
	return rawget(self, "tracked_recipes")
end

function BasicRecipeAdder:AddTrackedRecipe(rec)
	self:GetTrackedRecipes()[rec.name] = rec
end

---

local RecipeTabAdder = Class(NestedRecipeAdder, function(self, parent, tab)
	NestedRecipeAdder._ctor(self, parent)
	assert(tab, "Invalid tab.")
	rawset(self, "tab", tab)
end)

function RecipeTabAdder:GetTab()
	return rawget(self, "tab")
end

---

local RecipeTechAdder = Class(NestedRecipeAdder, function(self, parent, tech)
	NestedRecipeAdder._ctor(self, parent)
	assert(tech, "Invalid tech level.")
	rawset(self, "tech", tech)
end)

function RecipeTechAdder:GetTech()
	return rawget(self, "tech")
end

---

local FinalRecipeAdder = Class(NestedRecipeAdder, function(self, parent, prefab)
	NestedRecipeAdder._ctor(self, parent)
	assert(prefab, "Invalid prefab.")
	rawset(self, "prefab", prefab)
end)

function FinalRecipeAdder:GetPrefab()
	return rawget(self, "prefab")
end

function FinalRecipeAdder:__call(ingredients)
	local prefab = assert( self:GetPrefab(), "No result prefab set." )
	local tab = assert( self:GetTab(), "No recipe tab set." )
	local tech = assert( self:GetTech(), "No tech level set." )

	assert(type(ingredients) == "table", "Table expected as 'ingredients' argument.")

	for _, ing in ipairs(ingredients) do
		if IsModIngredient(ing) and ing:HasDefaultAtlas() then
			ing.atlas = _G.resolvefilepath(self:GetDefaultAtlas(ing:GetPrefab()))
		end
	end

	local rec = RecipeWrapper(prefab, ingredients, tab, tech)

	rec.atlas = _G.resolvefilepath(self:GetDefaultAtlas(prefab))

	if self:IsTracking() then
		self:AddTrackedRecipe(rec:GetRecipe())
	end

	return rec
end

---

local function NewNestedSelectorClass(targetclass)
	local Selector = Class(NestedRecipeAdder, function(self, parent, possibilities)
		NestedRecipeAdder._ctor(self, parent)
		rawset(self, "possibilities", possibilities)
	end)

	function Selector:__call(n)
		local v = rawget(self, n)

		if v == nil then
			local possibilities = assert( rawget(self, "possibilities"), "Invalid selection possibilities." )

			local chosen = possibilities[n]
			if chosen == nil then
				return error("Invalid selection index "..tostring(n)..", got nil.", 2)
			end

			v = targetclass(self, chosen)

			rawset(self, n, v)
		end

		return v
	end

	function Selector:__index(k)
		local v = Selector[k]
		if v ~= nil then
			return v
		else
			return self(k)
		end
	end

	return Selector
end

local function NewRecipeAdderChainer(chain)
	local last_class = chain[#chain]

	for i = #chain - 1, 1, -1 do
		local baseclass = chain[i]
		local parentclass = last_class

		local C = Class(baseclass, function(self, parent, value)
			baseclass._ctor(self, parent, value)
		end)

		function C:__index(k)
			local v = C[k]
			if v == nil then
				v = parentclass(self, k)
				rawset(self, k, v)
			end
			return v
		end

		local SelectorClass
		function C:__call(possibilities)
			if type(possibilities) ~= "table" then
				return error("Expected table as 'possibilities' argument, got "..type(possibilities), 2)
			end
			if SelectorClass == nil then
				SelectorClass = NewNestedSelectorClass(parentclass)
			end
			return SelectorClass(self, possibilities)
		end

		last_class = C
	end

	return last_class
end

---

local RecipeAdder = NewRecipeAdderChainer {BasicRecipeAdder, RecipeTabAdder, RecipeTechAdder, FinalRecipeAdder}

RecipeAdder.ModIngredient = ModIngredient

---

return RecipeAdder
