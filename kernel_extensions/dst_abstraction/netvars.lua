local NETVARS_DEBUG = false

---

local Lambda = wickerrequire "paradigms.functional"
local Pred = wickerrequire "lib.predicates"
local FunctionQueue = wickerrequire "gadgets.functionqueue"

if IsWorldgen() then
	init = Lambda.Nil
	return
end

local net_types = pkgrequire "netvars.net_types"

---

local rawget, rawset = rawget, rawset

---

local function debug_ondirty(inst, self)
	TheMod:Say("ondirty: ", self, " = ", self:ForceGetValue())
end

local BasicNetVar = Class(function(self, inst, varname)
	assert(Pred.IsEntityScript(inst), "Entity expected as 'inst' parameter of BasicNetVar constructor.")
	rawset(self, "inst", inst)

	rawset(self, "varname", varname)
	rawset(self, "dirty_eventname", varname.."_dirty")

	rawset(self, "ondirty_queue", FunctionQueue())

	self.inst:ListenForEvent(self.dirty_eventname, function(inst)
		self.ondirty_queue(inst, self)
	end)

	if NETVARS_DEBUG then
		self:AddOnDirtyFn(debug_ondirty)
	end
end)
Pred.IsNetVar = Pred.IsInstanceOf(BasicNetVar)

function BasicNetVar:GetInst()
	return rawget(self, "inst")
end

function BasicNetVar:GetName()
	return rawget(self, "varname")
end

function BasicNetVar:GetOnDirtyEventName()
	return self.dirty_eventname
end

function BasicNetVar:AddOnDirtyFn(ondirtyfn)
	table.insert(self.ondirty_queue, ondirtyfn)
end

function BasicNetVar:RemoveOnDirtyFn(ondirtyfn)
	for i, fn in ipairs(self.ondirty_queue) do
		if fn == ondirtyfn then
			table.remove(self.ondirty_queue, i)
			return
		end
	end
end

function BasicNetVar:GetDebugString()
	return "["..tostring(self:GetInst()).."]."..tostring(self:GetName())
end

BasicNetVar.__tostring = BasicNetVar.GetDebugString

---

local configureAccessors = (function()
	local getters = {}
	getters.value = function(self)
		return self:GetValue()
	end
	getters.local_value = getters.value
	getters.value_local = getters.local_value

	local setters = {}
	setters.value = function(self, v)
		return self:SetValue(v)
	end
	setters.local_value = function(self, v)
		return self:SetLocalValue(v)
	end
	setters.value_local = setters.local_value

	return function(class)
		class.__index = function(self, k)
			local v = class[k]
			if v ~= nil then
				return v
			end

			local get = getters[k]
			if get ~= nil then
				return get(self)
			end
		end
		class.__newindex = function(self, k, v)
			local set = setters[k]
			if set ~= nil then
				return set(self, v)
			end

			return error("Attempt to set new netvar index.", 2)
		end
	end
end)()


---

local function NetVarClass(...)
	local C = Class(...)

	configureAccessors(C)

	return C
end

local function NewNetVarClassFromSpec(spec, classname)
	local raw_net_type = assert( spec.raw_net_type )

	local validate_arg = assert( spec.validate_arg )
	local encode = assert( spec.encode )
	local decode = assert( spec.decode )
	local spec_type = assert( spec.type )

	local cache_key = {}

	local C = NetVarClass(BasicNetVar, function(self, inst, varname)
		assert(Pred.IsValidEntity(inst))
		assert(Pred.IsString(varname))
		BasicNetVar._ctor(self, inst, varname)

		rawset(self, "_raw", raw_net_type(inst.GUID, varname, self:GetOnDirtyEventName()))

		if spec_type == "number" then
			rawset(self, "scale", 1)
			rawset(self, "invscale", 1)
		end

		rawset(self, "pending_dirty", true)

		self:AddOnDirtyFn( Lambda.BindFirst(self.ForceGetValue, self) )
	end)

	if spec_type == "number" then
		function C:SetEncodingScale(s)
			self.scale = s
			self.invscale = 1/s
		end
	end

	local function check_arg(x)
		if not validate_arg(x) then
			return error("Attempt to set invalid value '"..tostring(x).."' to net var.", 3)
		end
	end

	local apply_scale, unapply_scale
	if spec_type == "number" then
		apply_scale = function(self, v)
			return v*self.scale
		end
		unapply_scale = function(self, v)
			return v*self.invscale
		end
	else
		apply_scale = Lambda.SecondOf
		unapply_scale = Lambda.SecondOf
	end

	local function get_cached_value(self)
		return rawget(self, cache_key)
	end

	local function set_cached_value(self, v)
		return rawset(self, cache_key, v)
	end

	if IsDST() then
		local function map_into(self, v)
			if v == nil then
				return nil
			else
				return encode(apply_scale(self, v))
			end
		end

		local function map_outof(self, w)
			if w == nil then
				return nil
			else
				return unapply_scale(self, decode(w))
			end
		end

		function C:ForceGetValue()
			local v = map_outof(self, self._raw:value())
			set_cached_value(self, v)
			return v
		end
		function C:GetValue()
			local v = get_cached_value(self)
			if v == nil then
				return self:ForceGetValue()
			else
				return v
			end
		end
		function C:SetValue(v)
			check_arg(v)
			local w = map_into(self, v)
			if self.pending_dirty or w ~= self._raw:value() then
				self.pending_dirty = false
				set_cached_value(self, v)
				self._raw:set(w)
			end
		end
		function C:SetLocalValue(v)
			check_arg(v)
			local w = map_into(self, v)
			set_cached_value(self, v)
			self._raw:set_local(w)
			self.pending_dirty = true
		end
		-- Raises the "ondirty" across the network, even if the value didn't change.
		function C:ForceSync(v)
			local r = self._raw
			local w
			if v == nil then
				w = r:value()
			else
				w = map_into(self, v)
			end
			self.pending_dirty = false
			r:set_local(w)
			r:set(w)
		end
	else
		C.ForceGetValue = get_cached_value
		C.GetValue = C.ForceGetValue
		function C:SetLocalValue(v)
			check_arg(v)
			self.pending_dirty = true
			return set_cached_value(self, v)
		end
		function C:SetValue(v)
			local oldv = self:GetValue()
			self:SetLocalValue(v)
			if v ~= oldv or self.pending_dirty then
				self:ForceSync()
			end
		end
		function C:ForceSync(v)
			if v ~= nil then
				self:SetLocalValue(v)
			end
			self.pending_dirty = false
			self.inst:PushEvent(self:GetOnDirtyEventName())
		end
	end

	return C
end

---

local Net_classes = Lambda.Map(NewNetVarClassFromSpec, pairs(net_types))
Lambda.InjectInto(_M, pairs(Net_classes))

---

Net_classes.NetShort = assert( Net_classes.NetShortInt )
Net_classes.NetUShort = assert( Net_classes.NetShortUInt )

---

NetBool.__call = assert( NetBool.SetValue )

---

local NetSignal = NetVarClass(NetBool, function(self, inst, varname)
	NetBool._ctor(self, inst, varname)
end)
Net_classes.NetSignal = NetSignal
_M.NetSignal = NetSignal

NetSignal.Connect = assert( NetSignal.AddOnDirtyFn )

function NetSignal:Send()
	self:ForceSync(true)
end

NetSignal.__call = NetSignal.Send

---

function init(kernel)
	Lambda.InjectInto(kernel, pairs(Net_classes))
end
