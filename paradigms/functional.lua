BindPackage "functional.common"

Iterator = pkgrequire "functional.iterator"
iterator = Iterator
iter = Iterator

BindPackage "functional.concepts"
BindPackage "functional.misc"
BindPackage "functional.prelude"

AddSelfPostInit(function()
	wickerrequire "paradigms.logic"
end)
