local Pred = wickerrequire "lib.predicates"

local new_tech_branches = {}

-- Delays the patching of other tech and prototyper trees to minimize the
-- chance of incompatibility with other mods.
TheMod:AddGamePostInit(function()
	-- Inserts the new branch in the TECH predef trees.
	for _, v in pairs(_G.TECH) do
		for _, name in ipairs(new_tech_branches) do
			v[name] = v[name] or 0
		end
	end

	-- The same, but for the prototyper trees.
	for _, v in pairs(_G.TUNING.PROTOTYPER_TREES) do
		for _, name in ipairs(new_tech_branches) do
			v[name] = v[name] or 0
		end
	end
end)


local function nasty_overridings()
	local Builder = _G.require "components/builder"

	function Builder:KnowsRecipe(recname)
		local recipe = _G.GetRecipe(recname)
	 
		if recipe then
			local is_intrinsic = true

			for k, v in pairs(recipe.level) do
				local bonus = self[k:lower().."_bonus"] or 0
				if bonus < v then
					is_intrinsic = false
					break
				end
			end

			if is_intrinsic then
				return true
			end
		end
	 
		return self.freebuildmode or _G.table.contains(self.recipes, recname)
	end
end
nasty_overridings()


--[[
-- Receives the name of the new tech branch and its max level. The max level
-- is used to create entries in TECH. If, say, name == "SHENANIGANS", these
-- entries have the form TECH.SHENANIGANS_1, TECH_SHENANIGANS_2, ... with
-- the number going up to maxlevel.
--
-- For uniformity with the game's own tech trees, it's best to use an
-- uppercase name.
--]]
function AddTechBranch(name, maxlevel)
	assert( type(name) == "string", "String expected as 'name' parameter." )

	table.insert(new_tech_branches, name)

	-- Now we create our own predefs.
	for i = 1, (maxlevel or 1) do
		local newtech = {[name] = i}
		for k, v in pairs(_G.TECH.NONE) do
			newtech[k] = newtech[k] or v
		end
		_G.TECH[("%s_%d"):format(name, i)] = newtech
	end

	--[[
	-- The following is needed to reset the custom tech level when
	-- leaving proximity. It is not needed for vanilla branches,
	-- but for custom ones it is (see Builder:EvaluateTechTrees() for
	-- details).
	--
	-- An alternative would be to do this resetting through the onturnoff
	-- callback of the Prototyper component, like Heavenfall does, but that
	-- requires assuming that the only builder entity in the game is the
	-- player, so I prefer this method. Neither of them are clean enough
	-- by my judgement, though: the Builder component has far too much
	-- hardcoded logic.
	--]]
	local Builder = _G.require "components/builder"
	Builder.EvaluateTechTrees = (function()
		local oldEval = Builder.EvaluateTechTrees

		return function(self)
			local had_prototyper = self.current_prototyper

			oldEval(self)

			if had_prototyper and not self.current_prototyper then
				-- If there is a prototyper, it'll take care of setting the
				-- values right.
				self.accessible_tech_trees[name] = 0
				self.inst:PushEvent("techtreechange", {level = self.accessile_tech_trees})
			end
		end
	end)()
end


--[[
-- Adds a new prototyper tree, to be used by an entity with the Prototyper
-- component.
--
-- The first parameter is the name of the tree (such as "SCIENCEMACHINE").
-- For uniformity with the game's conventions, it's preferable for it to
-- be in uppercase.
--
-- The second parameter is the table with the corresponding tech levels
-- (such as {SCIENCE = 1, MAGIC = 1}).
--
-- The third (optional) parameter is the string to be used by the recipe
-- popup when the player must be close to the corresponding structure
-- (such as "Use a science machine to build a prototype!")
--]]
function AddPrototyperTree(name, spec, hint)
	assert( type(name) == "string", "String expected as 'name' parameter." )
	assert( type(spec) == "table", "Table expected as 'spec' parameter." )
	assert( hint == nil or Pred.IsWordable(hint), "Nil or string expected as 'hint' parameter." )

	--[[
	-- This should be already taken care of by our game post init above,
	-- the following is just insurance.
	--]]
	spec.SCIENCE = spec.SCIENCE or 0
	spec.MAGIC = spec.MAGIC or 0
	spec.ANCIENT = spec.ANCIENT or 0

	_G.TUNING.PROTOTYPER_TREES[name] = spec

	if hint then
		local RecipePopup = _G.require "widgets/recipepopup"
		_G.require "widgets/widgetutil"

		local ERROR_404 = "Text not found."

		RecipePopup.Refresh = (function()
			local Refresh = RecipePopup.Refresh

			return function(self, ...)
				Refresh(self, ...)

				if self.teaser and self.teaser:IsVisible() and self.teaser:GetString() == ERROR_404 then
					if _G.CanPrototypeRecipe(self.recipe.level, spec) and _G.GetHintTextForRecipe(self.recipe) == name then
						self.teaser:SetString(tostring(hint))
					end
				end
			end
		end)()
	end
end


TheMod:EmbedAdder("TechBranch", AddTechBranch)
TheMod:EmbedAdder("PrototyperTree", AddPrototyperTree)
