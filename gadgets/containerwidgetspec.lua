local Debuggable = wickerrequire "adjectives.debuggable"
local Pred = wickerrequire "lib.predicates"
local DataValidator = wickerrequire "gadgets.datavalidator"
local Tree = wickerrequire "utils.table.tree"

---

local HookSelf
if IsDST() then
	local containers = require "containers"

	local getParamsTable = memoize_0ary(function()
		local Reflection = wickerrequire "game.reflection"
		return Reflection.RequireUpvalue(containers.widgetsetup, "params")
	end)

	HookSelf = function(self)
		if not self.unhooked then return end
		containers.MAXITEMSLOTS = math.max(containers.MAXITEMSLOTS, self.numslots)
		getParamsTable()[self.prefab] = self.spec
		self.unhooked = false
	end
else
	HookSelf = function(self)
		self.unhooked = false
	end
end

---

local ContainerWidgetSpec = Class(Debuggable, function(self, prefab, numslots)
	assert(prefab == nil or Pred.IsString(prefab))
	assert(Pred.IsPositiveInteger(numslots))
	Debuggable._ctor(self, "ContainerWidgetHelper"..(prefab == nil and "" or " for '"..prefab.."'"), false)

	self.prefab = prefab
	self.numslots = numslots

	self.spec = {
		widget = {},
	}

	self.dirty = true
	self.unhooked = true

	if prefab then
		HookSelf(self)
	end
end)
local CWS = ContainerWidgetSpec
Pred.IsContainerWidgetSpec = Pred.IsInstanceOf(CWS)

---

local mandatory_widget_data = {
	"slotpos",
	"animbank",
	"animbuild",
	"pos",
	"side_align_tip",
	--"buttoninfo", --optional
}

local mandatory_spec_data = {
	"type",
	"acceptsstacks",
	--"issidewidget", --optional

	--"itemtestfn", --optional

	widget = mandatory_widget_data,
}

local mandatory_self_data = {
	"prefab",
	"numslots",

	spec = mandatory_spec_data,
}

local validateSelf = DataValidator(mandatory_self_data, "self")

---

local function getSubTableFromKeyTable(t, key_table)
	for _, k in ipairs(key_table) do
		local u = t[k]
		if u == nil then
			u = {}
			t[k] = u
		end
		t = u
	end
	return t
end

local function getSpecTableFromKeyTable(self, key_table)
	return getSubTableFromKeyTable(self.spec, key_table)
end

local function getSpecTable(self, ...)
	return getSpecTableFromKeyTable(self, {...})
end

local setters = {}

local function NewProperty(name, condition_fn, ...) -- (...): spec key list, as in getSpec.
	local key_table = {...}
	local last_key = table.remove(key_table)

	CWS["Get"..name] = function(self)
		--assert(Pred.IsContainerWidgetSpec(self), "ContainerWidgetSpec expected as self parameter.")
		return getSpecTableFromKeyTable(self, key_table)[last_key]
	end

	local setter = function(self, value)
		assert(Pred.IsContainerWidgetSpec(self), "ContainerWidgetSpec expected as self parameter.")
		assert(condition_fn == nil or condition_fn(value), "Invalid value argument.")
		getSpecTableFromKeyTable(self, key_table)[last_key] = value
		self.dirty = true
	end

	CWS["Set"..name] = setter

	getSubTableFromKeyTable(setters, key_table)[last_key] = setter
end

---

function CWS:GetPrefab()
	return self.prefab
end

function CWS:GetNumSlots()
	return self.numslots
end

NewProperty("AcceptsStacks", Pred.IsBoolean, "acceptsstacks")
NewProperty("Type", Pred.IsString, "type")
NewProperty("IsSideWidget", Pred.IsBoolean, "issidewidget")
NewProperty("ItemTestFn", Pred.IsCallable, "itemtestfn")

NewProperty("SlotPosTable", Pred.IsArrayOf(Pred.IsPoint), "widget", "slotpos")
NewProperty("AnimBank", Pred.IsString, "widget", "animbank")
NewProperty("AnimBuild", Pred.IsString, "widget", "animbuild")
NewProperty("Position", Pred.IsPoint, "widget", "pos")
NewProperty("SideAlignTip", Pred.IsNumber, "widget", "side_align_tip")

function CWS:SetAnim(data)
	if data.bank then
		self:SetAnimBank(data.bank)
	end
	if data.build then
		self:SetAnimBuild(data.build)
	end
end
setters.widget.anim = CWS.SetAnim

NewProperty("ButtonInfoText", Pred.IsString, "widget", "buttoninfo", "text")
NewProperty("ButtonInfoPos", Pred.IsPoint, "widget", "buttoninfo", "position")
NewProperty("ButtonInfoFn", Pred.IsCallable, "widget", "buttoninfo", "fn")
NewProperty("ButtonInfoValidFn", Pred.IsCallable, "widget", "buttoninfo", "validfn")

function CWS:GetButtonInfo()
	return getSpecTable(self, "widget", "buttoninfo")
end

function CWS:SetButtonInfo(data)
	if data.text then
		self:SetButtonInfoText(data.text)
	end
	if data.pos then
		self:SetButtonInfoPos(data.pos)
	end
	if data.fn then
		self:SetButtonInfoFn(data.fn)
	end
	if data.validfn then
		self:SetButtonInfoValidFn(data.validfn)
	end
end
-- DO NOT set setters.widget.buttoninfo, for obvious reasons.

---

local function doInclude(self, subsetters, subdata)
	for k, v in pairs(subdata) do
		local subsubsetters = subsetters[k]
		if Pred.IsFunction(subsubsetters) then
			subsubsetters(self, v)
		else
			if not Pred.IsTable(subsubsetters) then
				return error("Invalid data included (last key: "..k..")")
			end
			doInclude(self, subsubsetters, v)
		end
	end
end

function CWS:Include(data)
	assert(Pred.IsContainerWidgetSpec(self), "ContainerWidgetSpec expected as self parameter.")
	assert(Pred.IsTable(data), "Table expected as table parameter.")
	return doInclude(self, setters, data)
end

---

-- Returns the last position.
function CWS:SetupSlotsLine(data)
	assert(Pred.IsContainerWidgetSpec(self), "ContainerWidgetSpec expected as self parameter.")
	assert(Pred.IsTable(data), "Table expected as table parameter.")

	local direction_str = data.direction or "y"
	local offset = data.offset or Point()
	local margin = data.margin or 0
	local slot_length = data.slot_length
	assert(direction_str == "x" or direction_str == "y")
	assert(Pred.IsPoint(offset))
	assert(Pred.IsNumber(margin))
	assert(Pred.IsPositiveNumber(slot_length))

	local dir = (direction_str == "x" and Vector3(1, 0, 0) or Vector3(0, -1, 0))

	local full_offset = offset + dir*margin
	local full_length = slot_length + margin

	local num = self:GetNumSlots()
	local slotpos = {}

	for factor = 0.5 + math.ceil(num/2) - 1, -(0.5 + math.floor(num/2) - 1), -1 do
		table.insert( slotpos, full_offset + dir*(factor*full_length) )
	end

	self:SetSlotPosTable(slotpos)
	if num > 0 then
		return slotpos[num]
	end
end
CWS.ConfigureSlotsLine = CWS.SetupSlotsLine

---

local doConfigureEntity
if IsDST() then
	doConfigureEntity = function(self, inst)
		inst.components.container:WidgetSetup(self.prefab)
		return inst
	end
else
	doConfigureEntity = function(self, inst)
		local c = inst.components.container

		c:SetNumSlots(self:GetNumSlots())
		c.widgetslotpos = self:GetSlotPosTable()
		c.widgetanimbank = self:GetAnimBank()
		c.widgetanimbuild = self:GetAnimBuild()
		c.widgetpos = self:GetPosition()
		c.side_align_tip = self:GetSideAlignTip()
		c.widgetbuttoninfo = self:GetButtonInfo()
		c.acceptsstacks = self:GetAcceptsStacks()
		c.type = self:GetType()
		c.itemtestfn = self:GetItemTestFn()

		return inst
	end
end

function CWS:ConfigureEntity(inst)
	assert(Pred.IsContainerWidgetSpec(self), "ContainerWidgetSpec expected as self parameter.")
	assert(Pred.IsEntityScript(inst), "Entity expected as inst parameter.")
	assert(inst.components.container, "Entity with container component expected as inst parameter.")
	HookSelf(self)
	if self.dirty then
		validateSelf(self)
		self.dirty = false
	end
	return doConfigureEntity(self, inst)
end
CWS.SetupEntity = CWS.ConfigureEntity

---

function CWS:CopyAs(new_prefab)
	local ret = CWS(new_prefab, self:GetNumSlots())

	Tree.InjectInto(ret.spec, self.spec)

	local ret_slotpos = ret:GetSlotPosTable()
	for i, v in ipairs(ret_slotpos) do
		ret_slotpos[i] = Point(v:Get())
	end

	if not new_prefab then
		ret.dirty = true
	else
		ret.dirty = self.dirty
	end

	return ret
end

---

return CWS
