if IsWorldgen() then return {} end

assert(IsSingleplayer(), "fake_singleplayer_rpcs.lua should only be loaded in singleplayer!")

local rpcs = {}

function rpcs.EquipActiveItem(player)
	local inv = player.components.inventory
	if not inv then return end

	local active_item = inv:GetActiveItem()
	if active_item ~= nil and
	   active_item.components.equippable ~= nil and
	   inv:GetEquippedItem(active_item.components.equippable.equipslot) == nil
	then
		inv:Equip(active_item, true)
	end
end

function rpcs.EquipActionItem(player)
	local inv = player.components.inventory
	if not inv then return end

    local active_item = inv:GetActiveItem()
    if active_item ~= nil and
        active_item.components.equippable ~= nil and
        active_item.components.equippable.equipslot == _G.EQUIPSLOTS.HANDS then

        inv:Equip(active_item)
        if inv:GetActiveItem() == active_item then
            inv:SetActiveItem()
        end
    end
end

-- Here action is the actual Action object.
-- Consistency is kept by changing the multiplayer interface as well.
function rpcs.DoWidgetButtonAction(player, action, target)
	if action == nil then return end

	local container = (target ~= nil and target.components.container or nil)

	if container == nil or container.opener == player then
		_G.BufferedAction(player, target, action):Do()
	end
end

return rpcs
