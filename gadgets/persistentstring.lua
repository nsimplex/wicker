local Lambda = wickerrequire "paradigms.functional"
local Debuggable = wickerrequire "adjectives.debuggable"
local Pred = wickerrequire "lib.predicates"

local assert = assert
local tostring = tostring

---

if not IsWorldgen() then
	require "mainfunctions"
end

---

local CACHE_KEY = {}

---


local SetFileName = (function()
	local function get_prefix()
		assert( modinfo )
		return tostring(modinfo.id)
	end

	local function doset(self, suffix)
		self.filename = get_prefix()..suffix
	end

	return function(self, base_suffix)
		local suffix = "_"..base_suffix
		return doset(self, suffix)
	end
end)()

---

local PersistentString = Class(Debuggable, function(self, suffix)
	if not Pred.IsWordable(suffix) then
		return error("PersistentString suffix must be a string.")
	end
	suffix = tostring(suffix)
	if suffix:find("[/\\]") then
		return error("PersistentString suffix must not contain '/' or '\\'.", 2)
	end
	
	SetFileName(self, suffix)
	Debuggable._ctor(self, "PersistentString '"..self:GetFileName().."'")

	--self[CACHE_KEY] = nil

	self.encoded = true

	self.loaded = false
end)
Pred.IsPersistentString = Pred.IsInstanceOf(PersistentString)

function PersistentString:GetFileName()
	return self.filename
end
PersistentString.GetFilename = PersistentString.GetFileName

function PersistentString:GetValue()
	return self[CACHE_KEY]
end
PersistentString.GetString = PersistentString.GetValue
PersistentString.__tostring = PersistentString.GetString

-- polymorphic.
function PersistentString:__call()
	return self:GetValue()
end

function PersistentString:SetValue(str)
	self[CACHE_KEY] = str
end
PersistentString.SetString = PersistentString.SetValue

---

function PersistentString:IsEncoded()
	return self.encoded
end

function PersistentString:SetEncoded(b)
	self.encoded = b and true or false
end

function PersistentString:Load(cb)
	if self.loaded then return end

	self:DebugSay("Loading...")
	return _G.TheSim:GetPersistentString(self:GetFileName(), function(load_success, str)
		if self.loaded then
			if cb ~= nil then
				cb(self:GetValue())
			end
			return
		end
		self.loaded = true
		if load_success and str ~= nil then
			self:SetString(str)
		end
		self:DebugSay("Loaded.")
		if cb ~= nil then
			cb(self:GetValue())
		end
	end)
end

function PersistentString:Save(cb)
	local s = self:GetString()
	if s ~= nil then
		self:DebugSay("Saving...")
		_G.SavePersistentString(self:GetFileName(), s, self:IsEncoded(), function()
			self:Say("Saved.")
			if cb ~= nil then
				cb()
			end
		end)
	end
end

function PersistentString:Expunge(cb)
	self[CACHE_KEY] = nil
	_G.ErasePersistentString(self:GetFileName(), cb)
end

---

local function NewMethodHooker(method)
	return function(self, fn, cb)
		local function gn(...)
			local args = fn ~= nil and {...} or {}
			method(self, function(str)
				if fn ~= nil then
					fn(unpack(args))
					gn = fn
				else
					gn = Lambda.Nil
				end
				if cb ~= nil then
					cb(str)
				end
			end)
		end
		return function(...)
			return gn(...)
		end
	end
end

PersistentString.HookLoad = NewMethodHooker(PersistentString.Load)
PersistentString.HookSave = NewMethodHooker(PersistentString.Save)

---

return PersistentString
