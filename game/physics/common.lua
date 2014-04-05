local Pred = wickerrequire "lib.predicates"
local Geo = wickerrequire "math.geometry"


--[[
-- Constants and conversions.
--]]

---
-- Magnitude of the acceleration of gravity.
g = 40

---
-- Gravity acceleration vector.
Gravity = Vector3(0, -g, 0)

---
-- Maps a damping coefficient to the terminal speed.
function DampingToTerminalSpeed(damping)
	return -g/math.log(1 - damping)
end

function DampingToTerminalVelocity(damping)
	return Vector3(0, -DampingToTerminalSpeed(damping), 0)
end

function TerminalSpeedToDamping(s)
	return 1 - math.exp(-g/s)
end


--[[
-- Geometry-related stuff.
--]]

---
-- Receives an entity, a curve and a speed, returning a thread making that
-- entity follow the curve. This thread may be terminated prematurely with
-- _G.KillThread().
--
-- @param inst The entity.
-- @param gamma The curve.
-- @param s (optional) The speed to follow the curve in. Default to 1.
-- @param period (optional) Period in which to update the velocity and position of the entity.
function FollowCurve(inst, gamma, s, period)
	assert( Pred.IsValidEntity(inst), "Valid entity expected as inst parameter." )
	assert( Pred.IsCurve(gamma), "Curve expected as gamma parameter." )
	s = s or 1
	assert( Pred.IsPositiveNumber(s), "Positive number expected as speed parameter." )
	period = period or 0.1
	assert( Pred.IsNonNegativeNumber(period), "Non-negative number expected as period parameter." )


	local Sleep = _G.Sleep
	return inst:StartThread(function()
		-- This is a change in the curve parameter, not time.
		local dt = period*s/gamma:Length()
		local inv_dt = 1/dt

		inst.Physics:SetMotorVel(0, 1, 0)
		inst.Physics:Stop()
		
		-- Curve parameter, not time.
		local t = 0

		while t < 1 do
			local pt = gamma(t)

			-- Secant vector to the next point.
			local secant = (gamma(t + dt) - pt)*inv_dt

			inst.Physics:Teleport(pt:Get())
			inst.Physics:SetVel(secant:Get())

			t = t + dt
			Sleep(period)
		end
	end)
end
