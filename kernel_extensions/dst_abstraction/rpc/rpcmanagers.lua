if IsWorldgen() then
	return {}
end


local Lambda = wickerrequire "paradigms.functional"
local Pred = wickerrequire "lib.predicates"
local Debuggable = wickerrequire "adjectives.debuggable"

local Common = pkgrequire "common"
local Custom = pkgrequire "customrpcs"

---

local GetVanillaRPCHandlers = assert(Common.GetVanillaRPCHandlers)
local GetVanillaRPCCodeMap = assert(Common.GetVanillaRPCCodeMap)

local AddModRPCHandler = assert(Custom.AddModRPCHandler)
local GetModRPCHandler = assert(Custom.GetModRPCHandler)
local SendModRPCToServer = assert(Custom.SendModRPCToServer)

---

local function IsVanillaRPCHandlerName(name)
	return GetVanillaRPCCodeMap()[name] ~= nil
end

local function IsModRPCHandlerName(name)
	return GetModRPCHandler(name) ~= nil
end

---

-- Abstract class.
local BasicVirtualServerRPC = Class(Debuggable, function(self, name)
	Debuggable._ctor(self, "VirtualRPC ("..tostring(name)..")", false)
	self:SetConfigurationKey("VIRTUAL_RPC")

	assert(Pred.IsString(name), "String expected as 'name' parameter.")

	self.name = name
	self.interface_fn = Lambda.Identity
end)

function BasicVirtualServerRPC:GetName()
	return self.name
end

function BasicVirtualServerRPC:GetInterface()
	return self.interface_fn
end

function BasicVirtualServerRPC:SetInterface(fn)
	assert(Pred.IsCallable(fn), "Function expected as interface function.")
	self.interface_fn = fn
end

-- Pure virtual method.
BasicVirtualServerRPC.Send = Lambda.Error("Attempt to call pure virtual method 'Send'.")

-- For polymorphism.
function BasicVirtualServerRPC:__call(...)
	return self:Send(...)
end

---

local VirtualServerRPC = Class(BasicVirtualServerRPC, function(self, name)
	BasicVirtualServerRPC._ctor(self, name)

	-- For error checking.
	self:GetHandler()
end)

function VirtualServerRPC:GetCode()
	local code = GetVanillaRPCCodeMap()[self:GetName()]
	assert(Pred.IsPositiveInteger(code), "Invalid RPC name.")
	return code
end

function VirtualServerRPC:GetHandler()
	local handler = GetVanillaRPCHandlers()[self:GetCode()]
	assert(Pred.IsCallable(handler), "Invalid RPC code.")
	return handler
end

local doSendVirtualServerRPC = (function()
	if IsServer() then
		return function(self, ...)
			return self:GetHandler()(GetLocalPlayer(), ...)
		end
	else
		return function(self, ...)
			return _G.SendRPCToServer(self:GetCode(), ...)
		end
	end
end)()

function VirtualServerRPC:Send(...)
	return doSendVirtualServerRPC(self, self:GetInterface()(...))
end

---

local VirtualServerModRPC = Class(BasicVirtualServerRPC, function(self, name)
	BasicVirtualServerRPC._ctor(self, name)

	-- For error checking.
	self:GetHandler()
end)

function VirtualServerModRPC:GetSubCode()
	local handler, subcode = GetModRPCHandler(self:GetName())
	assert(Pred.IsPositiveInteger(subcode), "Invalid mod RPC name.")
	return subcode
end

function VirtualServerModRPC:GetHandler()
	local handler = GetModRPCHandler(self:GetName())
	assert(Pred.IsCallable(handler), "Invalid mod RPC name.")
	return handler
end

local doSendVirtualServerModRPC = (function()
	if IsServer() then
		return function(self, ...)
			return self:GetHandler()(GetLocalPlayer(), ...)
		end
	else
		return function(self, ...)
			return SendModRPCToServer(self:GetSubCode(), ...)
		end
	end
end)()

function VirtualServerModRPC:Send(...)
	return doSendVirtualServerModRPC(self, self:GetInterface()(...))
end

---

local NewServerRPCManager = (function()
	local rawget, rawset = rawget, rawset

	---

	local function NewVirtualServerRPC(name)
		if IsModRPCHandlerName(name) then
			return VirtualServerModRPC(name)
		elseif IsVanillaRPCHandlerName(name) then
			return VirtualServerRPC(name)
		end
	end

	local function index(self, k)
		local v = NewVirtualServerRPC(k)
		if v ~= nil then
			rawset(self, k, v)
		end
		return v
	end

	local function newindex(self, k, v)
		if not Pred.IsPublicString(k) then
			return error("String expected as new mod RPC handler name.", 2)
		end
		AddModRPCHandler(k, v)
		rawset(self, k, VirtualServerModRPC(k))
	end

	local meta = {
		__index = index,
		__newindex = newindex,
	}
	
	return function()
		return setmetatable({}, meta)
	end
end)()

---

local ServerRPC = NewServerRPCManager()

assert(ServerRPC.DoWidgetButtonAction)
if IsDST() then
	-- This is already the interface for the singleplayer implementation.
	ServerRPC.DoWidgetButtonAction:SetInterface(function(action, target)
		return action.code, target, action.mod_name
	end)
end

---

return {
	ServerRPC = ServerRPC,
}
