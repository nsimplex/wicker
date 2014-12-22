local Lambda = wickerrequire "paradigms.functional"

local GetVanillaRPCHandlers
local GetVanillaRPCCodeMap
if IsDST() then
	GetVanillaRPCHandlers = memoize_0ary(function()
		local Reflection = wickerrequire "game.reflection"
		require "networkclientrpc"

		local RPC_HANDLERS = Reflection.RequireUpvalue(_G.HandleRPC, "RPC_HANDLERS")
		assert(#RPC_HANDLERS > 0, "Logic error.")

		return RPC_HANDLERS
	end)

	GetVanillaRPCCodeMap = memoize_0ary(function()
		require "networkclientrpc"
		return assert(_G.RPC)
	end)
else
	local FakeRPCs = pkgrequire "fake_singleplayer_rpcs"

	local handlers = {}
	local codemap = {}
	do
		local i = 1
		for k, v in pairs(FakeRPCs) do
			codemap[k] = i
			handlers[i] = v
			i = i + 1
		end
	end

	GetVanillaRPCHandlers = Lambda.Constant( handlers )
	GetVanillaRPCCodeMap = Lambda.Constant( codemap )
end

return {
	GetVanillaRPCHandlers = GetVanillaRPCHandlers,
	GetVanillaRPCCodeMap = GetVanillaRPCCodeMap,
}
