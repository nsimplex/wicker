local Common = pkgrequire "common"

local function validate_inst_position(inst)
	if not inst:IsOnValidGround() then
		local fx = SpawnPrefab("splash_ocean")
		local pos = inst:GetPosition()
		fx.Transform:SetPosition(pos.x, pos.y, pos.z)
		if inst:HasTag("irreplaceable") then
			local player = Common.FindClosestPlayer(pos)
			if player ~= nil then
				inst.Transform:SetPosition(player.Transform:GetWorldPosition())
			else
				inst.Transform:SetPosition(0, 0, 0)
			end
		else
			inst:Remove()
		end
	end
end

---
-- Throws an item from a point, as in loot dropping.
--
-- @param item The item to be thrown.
-- @param srcpos (optional) The point of origin.
-- @param speed (optional) The speed of the throw.
-- @param vertangle (optional) The angle of the throw with respect to the map plane.
-- @param horangle (optional) The angle of the projection of the throw vector onto the map plane.
--
-- @returns item
function ThrowItem(item, srcpos, speed, vertangle, horangle)
	srcpos = srcpos and Common.ToPoint(srcpos) or item:GetPosition()
	speed = speed or (8 + 5*math.random())
	vertangle = vertangle or (0.2 + 0.25*math.random())*math.pi
	horangle = horangle or 2*math.pi*math.random()

	local vertspeed = speed*math.sin(vertangle)
	local horspeed = speed*math.cos(vertangle)

	local dx, dz = math.cos(horangle), math.sin(horangle)

	if item.Physics then
		item.Physics:Teleport( srcpos:Get() )

		item.Physics:SetVel(horspeed*dx, vertspeed, horspeed*dz)

		item:DoTaskInTime(1, function() 
			if not (item.components.inventoryitem and item.components.inventoryitem:IsHeld()) then
				validate_inst_position(item)
			end
		end)
	else
		item.Transform:SetPosition( srcpos:Get() )
		validate_inst_position(item)
	end

	return item
end

--[[
-- Throws an item from a container or inventory, as in loot dropping. The parameters are as in ThrowItem.
--
-- @returns item
--]]
function ThrowItemFromContainer(item, speed, vertangle, horangle)
	horangle = horangle or 2*math.pi*math.random()

	local containercmp = item:IsValid() and item.components.inventoryitem and item.components.inventoryitem:GetContainer()
	if not containercmp then return end

	containercmp:DropItem(item)

	local container = containercmp.inst


	local horangle = 2*math.pi*math.random()
	local dx, dz = math.cos(horangle), math.sin(horangle)

	local pt = Point(container.Transform:GetWorldPosition())
	if container.Physics then
		pt = pt + Vector3(dx, 0, dz)*(container.Physics:GetRadius() or 1)
	end
	if item.Physics then
		pt = pt + Vector3(dx, 0, dz)*(item.Physics:GetRadius() or 1)
	end


	return ThrowItem(item, pt, nil, nil, horangle)
end

---
-- Drops an item from the sky (to be used mainly with loot).
-- 
-- @param item The item entity
-- @param center The center (on the ground) of the falling area.
-- @param min_radius Minimum radius from center it will fall on.
-- @param max_radius Maximum radius from center it will fall on.
-- @param height The original height for the fall.
--
-- @returns item
function DropItemFromTheSky(item, center, min_radius, max_radius, height)
	center = Common.ToPoint(center)
	height = height or 35

	assert( item:is_a(EntityScript) )
	assert( center:is_a(Point) )

	min_radius = min_radius or 0
	max_radius = max_radius or 0

	assert( type(min_radius) == "number" and min_radius >= 0 )
	assert( type(max_radius) == "number" and max_radius >= 0 )

	if max_radius < min_radius then
		max_radius = min_radius
	end

	-- Angle in relation to center it should fall on (preferably).
	local theta = 2*math.pi*math.random()

	-- Offset from center on which it will reach the ground.
	local offset

	-- We try to find a valid position within the range.
	for _ = 1, 4 do
		local tentative_radius = min_radius + math.random()*(max_radius - min_radius)
		offset = _G.FindWalkableOffset(center, theta, tentative_radius, 16)
		if offset then break end
	end

	local target_pt = center + offset

	-- If it doesn't have physics or is static (so that it won't fall), just spawn it on the ground.
	if not item.Physics or item.Physics:GetMass() == 0 then
		item.Transform:SetPosition(target_pt:Get())
		return item
	end

	-- Otherwise, things get interesting! ;]
	
	target_pt.y = height

	item.Physics:Teleport(target_pt:Get())

	return item
end

---
-- Drops all loot from inst from the sky.
--
-- @param inst Lootdropper entity
-- @param max_distance Maximum distance from inst loot should drop on.
--
function DropLootFromTheSky(inst, max_distance)
	assert( inst:is_a(EntityScript) )

	max_distance = max_distance or 0
	assert( type(max_distance) == "number" and max_distance >= 0 )

	if not inst.components.lootdropper then return end


	local center = inst:GetPosition()

	local prefabs = inst.components.lootdropper:GenerateLoot()
	for _, v in pairs(prefabs) do
		local item = SpawnPrefab(v)
		if item then
			local min_radius = inst.Physics and inst.Physics:GetRadius() or 1
			local max_radius = min_radius + max_distance

			if item.Physics then
				min_radius = min_radius + (item.Physics:GetRadius() or 1)
				max_radius = math.max(min_radius, max_radius)
			end

			DropItemFromTheSky(item, center, min_radius, max_radius)
		end
	end
end

if IsDST() then
	function ShakeCamera(inst, source_inst, shakeType, duration, speed, maxShake, maxDist)
		if not inst.ShakeCamera then return end
		return inst:ShakeCamera(shakeType, duration, speed, maxShake, source_inst, maxDist)
	end
else
	function ShakeCamera(inst, source_inst, shakeType, duration, speed, maxShake, maxDist)
		if not inst.components.playercontroller then return end
		return inst.components.playercontroller:ShakeCamera(source_inst, shakeType, duration, speed, maxShake, maxDist)
	end
end
