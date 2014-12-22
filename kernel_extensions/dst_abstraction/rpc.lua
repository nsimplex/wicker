local Lambda = wickerrequire "paradigms.functional"

if IsWorldgen() then
	init = Lambda.Nil
	return
end

local RPCManagers = pkgrequire "rpc.rpcmanagers"
local ExtraRPCs = pkgrequire "rpc.extra_rpcs"


function init(kernel)
	ExtraRPCs.init(kernel)
	for k, v in pairs(RPCManagers) do
		assert(kernel[k] == nil)
		kernel[k] = v
	end
end
