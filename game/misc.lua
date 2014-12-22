BecomePackage "common"
local replica = replica

local Lambda = wickerrequire "paradigms.functional"

---

function ReplaceEntity(inst, newinst)
	if newinst.components.stackable and inst.components.stackable then
		newinst.components.stackable:SetStackSize(inst.components.stackable:StackSize())
	end

	local owner = inst.components.inventoryitem and inst.components.inventoryitem.owner
	local holder = owner and (owner.components.inventory or owner.components.container)
	local slot = holder and holder:GetItemSlot(inst)

	local pt = inst:GetPosition()

	inst:Remove()

	if holder then
		holder:GiveItem(newinst, slot)
	else
		Move(newinst, pt)
	end
end

---

local function basic_ShowPlayerHUD(player, b)
	if player.HUD then
		if b then
			player.HUD:Show()
		else
			player.HUD:Hide()
		end
	end
end
if IsDST() then
	function ShowPlayerHUD(player, b)
		if IsMasterSimulation() then
			if player.ShowHUD then
				return player:ShowHUD(b and true or false)
			end
		elseif player == GetLocalPlayer() and player.HUD then
			basic_ShowPlayerHUD(player, b)
		end
	end
else
	ShowPlayerHUD = basic_ShowPlayerHUD
end

---

if IsDST() then
	function GetContainerItems(inst)
		return replica(inst).container:GetItems()
	end
else
	function GetContainerItems(inst)
		return inst.components.container.slots
	end
end
local GetContainerItems = GetContainerItems

function IsEmptyContainer(inst)
	return replica(inst).container and next(GetContainerItems(inst)) == nil
end

function IsNonEmptyContainer(inst)
	return replica(inst).container and next(GetContainerItems(inst)) ~= nil
end

---

local function get_obvious_foodtype(inst)
	local e = inst.components.edible
	if e ~= nil then
		return e.foodtype
	end
end
if IsDST() then
	local FOODTYPE = assert( _G.FOODTYPE )

	local EDIBLE_TAGS = Lambda.Map(function(v)
		if v ~= FOODTYPE.BERRY then
			return "edible_"..v, v
		end
	end, pairs(FOODTYPE))

	function GetFoodType(inst)
		local foodtype = get_obvious_foodtype(inst)
		if foodtype == nil then
			for k, v in pairs(EDIBLE_TAGS) do
				if inst:HasTag(v) then
					return k
				end
			end
		else
			return foodtype
		end
	end
else
	GetFoodType = get_obvious_foodtype
end
local GetFoodType = GetFoodType

function IsEdible(inst)
	return GetFoodType(inst) ~= nil
end

function IsEdibleOfType(inst, foodtype)
	return GetFoodType(inst) == foodtype
end

function IsEdibleNotOfType(inst, foodtype)
	local ft = GetFoodType(inst)
	return ft ~= nil and ft ~= foodtype
end
