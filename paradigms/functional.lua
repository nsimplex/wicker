BindPackage "functional.common"

Iterator = pkgrequire "functional.iterator"
iterator = Iterator

BindPackage "functional.concepts"
BindPackage "functional.misc"


AddSelfPostInit(function()
	wickerrequire "paradigms.logic"
end)
