ifndef SCRIPT_DIR
 $(error SCRIPT_DIR is not defined)
endif
ifndef TOOLS_DIR
 $(error TOOLS_DIR is not defined)
endif


wicker:
	-git subtree pull --prefix $(SCRIPT_DIR)/wicker https://github.com/nsimplex/wicker.git master --squash
	-git subtree pull --prefix $(TOOLS_DIR) https://github.com/nsimplex/wickertools.git master --squash

boot: $(TOOLS_DIR)/bootup_gen.pl
	find "$(SCRIPT_DIR)" -type f -name '*.lua' -exec perl "$<" '{}' global \;
