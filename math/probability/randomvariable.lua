local Lambda = wickerrequire "paradigms.functional"
local Pred = wickerrequire "lib.predicates"

local GeoCommon = wickerrequire "math.geometry.common"

local rand = math.random

---

local RandVar = Class(function(self, fn)
	self.fn = fn
end)
Pred.IsRandomVariable = Pred.IsInstanceOf(RandVar)

function RandVar:__call()
	return self.fn()
end

RandVar.__add = Lambda.Compose(RandVar, GeoCommon.VectorValuedFunction.Add)
RandVar.__mul = Lambda.Compose(RandVar, GeoCommon.VectorValuedFunction.Scale)

---

local function Uniform(a, b)
	local delta = b - a
	return RandVar(function()
		return a + delta*rand()
	end)
end
_M.Uniform = Uniform

local function UniformDiscrete(m, n)
	return RandVar(function()
		return rand(m, n)
	end)
end
_M.UniformDiscrete = UniformDiscrete
