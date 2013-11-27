$(info Starting wicker Makefile rules set...)

ifndef FILES
 $(error FILES is not defined)
endif
ifndef SCRIPT_DIR
 $(error SCRIPT_DIR is not defined)
endif
ifndef TOOLS_DIR
 $(error TOOLS_DIR is not defined)
endif
ifndef THEMAIN
 $(error THEMAIN is not defined)
endif
ifndef LICENSE_FILES
 $(warning LICENSE_FILES is not defined)
endif



$(info Augmenting FILES...)

WICKER_GENERATED_CONFIGURATION_FILES:=rc.lua rc.example.lua $(SCRIPT_DIR)/rc/defaults.lua
WICKER_GENERATED_POST_FILES:=Post.upload Post.discussion

WICKER_GENERATED_FILES:=modinfo.lua $(WICKER_GENERATED_CONFIGURATION_FILES) $(WICKER_GENERATED_POST_FILES)

WICKER_DEFAULT_PROJECT_FILES:=modmain.lua modinfo.lua $(SCRIPT_DIR)/rc/schema.lua rc.lua $(SCRIPT_DIR)/rc/defaults.lua $(ICON) $(ICON_ATLAS)

include $(SCRIPT_DIR)/wicker/make/files.mk

FILES:=$(FILES) $(WICKER_DEFAULT_PROJECT_FILES)

WICKER_PROJECT_FILES:=$(FILES)

FILES+=$(foreach f, $(WICKER_FILES), $(SCRIPT_DIR)/wicker/$(f))


PROJECT_ZIP:=$(shell echo $(PROJECT) | tr [:blank:] _).zip


$(info Setting up targets...)

.PHONY: dist wicker boot touch modinfo.lua modmain.lua $(THEMAIN) rc rc.lua post clean count



## Convenience targets

dist: $(PROJECT_ZIP) $(WICKER_GENERATED_FILES)

touch: modinfo.lua modmain.lua $(THEMAIN)

rc: $(WICKER_GENERATED_CONFIGURATION_FILES)

post: $(WICKER_GENERATED_POST_FILES)



## Generated and modified code

modinfo.lua:
	echo "$$MOD_INFO" > $@

modmain.lua: $(TOOLS_DIR)/touch_modmain.pl
	perl -i $< $@

$(THEMAIN): $(TOOLS_DIR)/touch_modmain.pl
	perl -i $< $@

rc.lua: $(TOOLS_DIR)/rc_gen.pl rc.template.lua
	$< rc < rc.template.lua > rc.lua

$(SCRIPT_DIR)/rc/defaults.lua: $(TOOLS_DIR)/rc_gen.pl rc.template.lua
	$< rc.defaults < rc.template.lua > $(SCRIPT_DIR)/rc/defaults.lua

rc.example.lua: $(TOOLS_DIR)/rc_gen.pl rc.template.lua
	$< rc.example < rc.template.lua > rc.example.lua

scripts/prefabs/%.lua:
	mkdir -p $(@D)
	echo "return require '$(PROJECT_lc).prefabs.$*'" > $@

scripts/components/%.lua:
	mkdir -p $(@D)
	echo "return require('$(PROJECT_lc).' .. (...))" > $@

scripts/stategraphs/%.lua:
	mkdir -p $(@D)
	echo "return require('$(PROJECT_lc).' .. (...))" > $@

scripts/brains/%.lua:
	mkdir -p $(@D)
	echo "return require('$(PROJECT_lc).' .. (...))" > $@

Post.discussion: $(TOOLS_DIR)/postman.pl Post.template rc.example.lua
	$< discussion < Post.template > $@

Post.upload: $(TOOLS_DIR)/postman.pl Post.template rc.example.lua
	$< upload < Post.template > $@



## Utilities for distribution and similar purposes.

# Please don't run this inside a symbolic link.
$(PROJECT_ZIP): $(sort $(FILES))
	echo -e "$$PROJECT_NAME $$PROJECT_VERSION (http://forums.kleientertainment.com/showthread.php?$$PROJECT_FORUM_THREAD).\nCreated by $$PROJECT_AUTHOR.\nPackaged on `date +%F`." | \
		( cd ..; zip -FS -8 --archive-comment $(CURDIR)/$(PROJECT_ZIP) $(foreach f, $(FILES), $(notdir $(CURDIR))/$(f)) )

CLEANABLE_FILES:=$(PROJECT_ZIP)
ifndef IS_PERSISTENT
 CLEANABLE_FILES+=$(WICKER_GENERATED_FILES)
endif

clean:
	$(RM) $(CLEANABLE_FILES)

count: $(sort $(filter-out $(LICENSE_FILES), $(WICKER_PROJECT_FILES)))
	@(for i in $^; do [[ "$$(file -bi "$$i")" =~ "text/" ]] && wc -l $$i; done) | sort -s -g | perl -e '$$t = 0; while($$l = <>){ $$t += $$l; print $$l; } print "Total: $$t\n";'


include $(word $(words $(MAKEFILE_LIST)),$(MAKEFILE_LIST))/utils.mk


$(info Finished wicker Makefile rules set.)
