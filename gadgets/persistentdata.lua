local PersistentString = wickerrequire "gadgets.persistentstring"
require "dumper"

local Pred = wickerrequire "lib.predicates"

local assert = assert

---

local DATA_KEY = {}

---

local PersistentData = Class(PersistentString, function(self, suffix, default_value)
	PersistentString._ctor(self, suffix)

	self.loadenv = {}

	self.prettyprint = TheMod:IsDev()

	self[DATA_KEY] = default_value
end)
Pred.IsPersistentData = Pred.IsInstanceOf(PersistentData)

---

function PersistentData:GetLoadEnv()
	return self.loadenv
end

function PersistentData:SetLoadEnv(env)
	if not Pred.IsTable(env) then
		return error("table expected as loading environment.")
	end
	self.loadenv = env
end

function PersistentData:IsPrettyPrinted()
	return self.prettyprint
end

function PersistentData:SetPrettyPrinted(v)
	self.prettyprint = v and true or false
end

---


local function encode(self, data)
	local ret = _G.DataDumper(data, nil, not self:IsPrettyPrinted())
	if type(ret) ~= "string" then
		return error("string expected as result of dumping persistent data, got "..tostring(ret))
	end
	return ret
end

local function decode(self, str)
	if type(str) ~= "string" then
		return error( "string expected as persistent string, got "..tostring(str) )
	end

    local fn, msg = loadstring(str)
	if not fn then
		TheMod:Warn("Failed to load persistent data in '", self:GetFileName(), "': ", msg)
		return nil
	end

    setfenv(fn, self:GetLoadEnv())

    local ret = fn()

    if ret == nil and not str:find("^return ") then
        ret = self:GetLoadEnv()
    end

    return ret
end

---

function PersistentData:GetValue()
	return self[DATA_KEY]
end
PersistentData.GetData = PersistentData.GetValue

function PersistentData:GetString()
	local data = self:GetData()
	if data ~= nil then
		return encode( self, data )
	end
end

function PersistentData:SetValue(str)
	self[DATA_KEY] = str
end
PersistentData.SetData = PersistentData.SetValue

function PersistentData:SetString(str)
	self:SetData( decode(self, str) )
end

---

return PersistentData
