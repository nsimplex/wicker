# Editable part

WICKER_FILES_CATEGORIES:=BASE API UTIL PARADIGM LIB ADJECTIVE GADGET MATH PROTOCOMPONENT MISC \
	LICENSE


WICKER_BASE_DIR_SUF:=
BARE_WICKER_BASE_FILES:=init.lua utils.lua

WICKER_API_DIR_SUF:=api
BARE_WICKER_API_FILES:=core.lua themod.lua

WICKER_UTIL_DIR_SUF:=utils
BARE_WICKER_UTIL_FILES:=algo.lua game.lua io.lua string.lua table.lua table/core.lua table/tree.lua table/tree/core.lua table/tree/dfs.lua time.lua

WICKER_PARADIGM_DIR_SUF:=paradigms
BARE_WICKER_PARADIGM_FILES:=functional.lua logic.lua

WICKER_LIB_DIR_SUF:=lib
BARE_WICKER_LIB_FILES:=predicates.lua searchspace.lua

WICKER_ADJECTIVE_DIR_SUF:=adjectives
BARE_WICKER_ADJECTIVE_FILES:=configurable.lua debuggable.lua

WICKER_GADGET_DIR_SUF:=gadgets
BARE_WICKER_GADGET_FILES:=configurable.lua debuggable.lua eventchain.lua functionqueue.lua

WICKER_MATH_DIR_SUF:=math
BARE_WICKER_MATH_FILES:=probability/markovchain.lua

WICKER_PROTOCOMPONENT_DIR_SUF:=protocomponents
BARE_WICKER_PROTOCOMPONENT_FILES:=base.lua conditionaltasker.lua

WICKER_MISC_DIR_SUF:=
BARE_WICKER_MISC_FILES:=

WICKER_LICENSE_DIR_SUF:=
BARE_WICKER_LICENSE_FILES:=AUTHORS.txt COPYING.txt

# End of editable part



# Already includes the trailing slash.
define WICKER_DIR_TEMPLATE = 
 # WICKER_$(1)_DIR:=$(CURDIR)/$$(WICKER_$(1)_DIR_SUF)
 WICKER_$(1)_DIR:=$$(addsuffix /, $$(WICKER_$(1)_DIR_SUF))
endef

define WICKER_FILES_TEMPLATE = 
 WICKER_$(1)_FILES:=$$(foreach f, $$(BARE_WICKER_$(1)_FILES), $$(WICKER_$(1)_DIR)$$(f))
endef


$(foreach cat, $(WICKER_FILES_CATEGORIES), \
 $(eval $(call WICKER_DIR_TEMPLATE,$(cat))) \
 $(eval $(call WICKER_FILES_TEMPLATE,$(cat))) \
)

WICKER_FILES:=$(foreach cat, $(WICKER_FILES_CATEGORIES), $(WICKER_$(cat)_FILES))
