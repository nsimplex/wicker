local Game = pkgrequire "common"
local Lambda = wickerrequire "paradigms.functional"

require 'entityscript'
local GROUND = GROUND


BecomeWickerModule "lib.predicates"


function IsValidGround(tile)
	return tile and not ( tile == GROUND.IMPASSABLE or tile >= GROUND.UNDERGROUND)
end

function IsValidPoint(pt)
	return IsValidGround(GetGroundTypeAtPosition( Game.ToPoint(pt) ))
end

IsUnblockedPoint = (function()
	local not_tags = {'NOBLOCK', 'player', 'FX', "INLIMBO", "DECOR"}

	return function(pt, blocking_radius, fn)
		if IsValidPoint(pt) then
			return not Game.FindSomeEntity(
				pt,
				blocking_radius or 2,
				function(inst)
					return inst.parent == nil and not inst.components.placer and not rawequal(inst, pt) and (not fn or fn(inst))
				end,
				nil,
				not_tags
			)
		end
	end
end)()

function IsDeployablePoint(inst, pt)
	if not inst.components.deployable then return false end
	return IsUnblockedPoint(pt, inst.components.deployable.min_spacing, function(ent) return ent ~= inst end)
end

-- Returns whether there exists a clear path connecting both points.
function IsClearPath(src, dest, check_for_walls)
	src, dest = Game.ToPoint(src), Game.ToPoint(dest)
	if IsValidPoint(dest) then
		return GetWorld().Pathfinder:IsClear(src.x, src.y, src.z, dest.x, dest.y, dest.z, {
			ignorewalls = not check_for_walls,
			ignore_creep = true,
		})
	end
end
