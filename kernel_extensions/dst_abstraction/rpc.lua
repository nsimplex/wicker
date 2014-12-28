local Lambda = wickerrequire "paradigms.functional"

if IsWorldgen() then
	init = Lambda.Nil
	return
end

local RPCManagers = pkgrequire "rpc.rpcmanagers"

function init(kernel)
	for k, v in pairs(RPCManagers) do
		assert(kernel[k] == nil)
		kernel[k] = v
	end
end
