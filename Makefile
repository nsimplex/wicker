PROJECT:=Wicker
AUTHOR:=simplex
VERSION:=2.0


PROJECT_NAME:=$(PROJECT)
PROJECT_VERSION:=$(VERSION)
PROJECT_AUTHOR=$(AUTHOR)
export PROJECT_NAME
export PROJECT_VERSION
export PROJECT_AUTHOR


.PHONY: count init init.lua boot


count:
	@(find . -path './.git/*' -prune -o -type f -name '*.lua' -exec bash -c '[[ "$$(file -bi "{}")" =~ "text/" ]] && wc -l "{}"' ';') | sort -s -g | perl -e '$$t = 0; while($$l = <>){ $$t += $$l; print $$l; } print "Total: $$t\n";'



init: init.lua

init.lua: tools/touch_modmain.pl
	perl -i $< $@

boot: tools/bootup_gen.pl
	find . -type f -name '*.lua' -exec perl $< '{}' wicker \;
