local Lambda = wickerrequire "paradigms.functional"
local Logic = wickerrequire "lib.logic"

local function NewLogicAssertion(operation, operation_name)
	local op_name = tostring(operation_name)
	return function(a, b, desc)
		if not operation(a, b) then
			return error("Assumption about "..tostring(desc).." logical "..op_name.." failed. ("..tostring(a)..", "..tostring(b)..")", 2)
		end
	end
end

local logic_equivalence = NewLogicAssertion(Logic.IfAndOnlyIf, "equivalence")
local logic_implication = NewLogicAssertion(Logic.Implies, "implication")

logic_equivalence(IsServer(), IsMasterSimulation(), "server <-> master simulation")

-- This doesn't hold in the main menu.
if not IsWorldgen() then
	TheMod:AddPrefabPostInit("world", function()
		logic_implication(IsDedicated(), IsServer(), "dedicated -> server")
		logic_equivalence(IsServer(), not IsClient(), "server <-> not client")
	end)
end
