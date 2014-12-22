local FunctionQueue = wickerrequire 'gadgets.functionqueue'


local postconstructs = setmetatable({}, {__mode = "k"})


TheMod:AddPrefabPostInitAny(function(inst)
	local ps = postconstructs[inst]
	if ps ~= nil then
		postconstructs[inst] = nil
		return ps(inst)
	end
end)


local function AddPrefabPostConstruct(inst, fn)
	local ps = postconstructs[inst]
	if ps == nil then
		ps = FunctionQueue()
		postconstructs[inst] = ps
	end
	table.insert(ps, fn)
end


TheMod:EmbedHook("AddPrefabPostConstruct", AddPrefabPostConstruct)


return AddPrefabPostConstruct
