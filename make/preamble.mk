WICKER_T_MANDATORY_VARS:=PROJECT AUTHOR VERSION API_VERSION DESCRIPTION FORUM_THREAD FORUM_DOWNLOAD_ID

SHELL:=/usr/bin/bash


$(info Starting wicker Makefile preamble...)

define WICKER_T_DEFCHECK =
 ifndef $(1)
      $$(warning Variable $(1) is not defined)
      WICKER_T_HASERRORS:=1
 endif
endef

$(foreach var, $(WICKER_T_MANDATORY_VARS),$(eval $(call WICKER_T_DEFCHECK,$(var))))
ifdef WICKER_T_HASERRORS
 $(error There are undefined mandatory variables)
endif


ifndef ICON_DIR
 ifneq ($(wildcard favicon),)
  $(info ICON_DIR is not defined, defaulting to `favicon')
  ICON_DIR:=favicon
 else
  $(info ICON_DIR is not defined and `favicon' does not exist. Skipping icons...)
 endif
endif

ifndef WICKER_TOOLS_DIR
 $(info WICKER_TOOLS_DIR is not defined, defaulting to `tools')
 WICKER_TOOLS_DIR:=tools
endif


ifndef PROJECT_lc
 $(info Defining PROJECT_lc...)
 PROJECT_lc:=$(shell echo $(PROJECT) | tr A-Z a-z)
endif


ifndef SCRIPT_DIR
 ifdef SCRIPTS_DIR
  SCRIPT_DIR:=$(SCRIPTS_DIR)
 else
  $(info Defining SCRIPT_DIR...)
  SCRIPT_DIR:=scripts/$(PROJECT_lc)
 endif
endif
ifndef SCRIPTS_DIR
 SCRIPTS_DIR:=$(SCRIPT_DIR)
endif


ifdef ICON_DIR
 $(info Defining ICON and ICON_ATLAS...)
 ICON:=$(ICON_DIR)/$(PROJECT_lc).tex
 ICON_ATLAS:=$(ICON_DIR)/$(PROJECT_lc).xml

 MODINFO_ICON:="$(ICON)"
 MODINFO_ICON_ATLAS:="$(ICON_ATLAS)"
else
 MODINFO_ICON:=nil
 MODINFO_ICON_ATLAS:=nil
endif


$(info Defining utility function WICKER_ADD_MIRRORS...)
WICKER_ADD_MIRRORS=$(foreach x,$(2),scripts/$(1)/$(x) $(SCRIPTS_DIR)/$(1)/$(x))

$(info Defining utility functions WICKER_ADD_PREFABS, WICKER_ADD_COMPONENTS, WICKER_ADD_STATEGRAPHS and WICKER_ADD_BRAINS...)
WICKER_ADD_PREFABS=$(call WICKER_ADD_MIRRORS,prefabs,$(1))
WICKER_ADD_COMPONENTS=$(call WICKER_ADD_MIRRORS,components,$(1))
WICKER_ADD_STATEGRAPHS=$(call WICKER_ADD_MIRRORS,stategraphs,$(1))
WICKER_ADD_BRAINS=$(call WICKER_ADD_MIRRORS,brains,$(1))

$(info Defining and exporting MOD_INFO...)
define MOD_INFO =
--[[
Copyright (C) 2013  $(AUTHOR)

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.

The file $(ICON) is based on textures from Klei Entertainment's
Don't Starve and is not covered under the terms of this license.
]]--

name = "$(PROJECT)"
version = "$(VERSION)"
author = "$(AUTHOR)"

description = [=[$(DESCRIPTION)]=]

forumthread = "$(FORUM_THREAD)"

api_version = $(API_VERSION)
icon = $(MODINFO_ICON)
icon_atlas = $(MODINFO_ICON_ATLAS)
endef
export MOD_INFO


$(info Exporting project variables...)
PROJECT_NAME:=$(PROJECT)
PROJECT_VERSION:=$(VERSION)
PROJECT_AUTHOR:=$(AUTHOR)
PROJECT_FORUM_THREAD:=$(FORUM_THREAD)
PROJECT_FORUM_DOWNLOAD_ID:=$(FORUM_DOWNLOAD_ID)
export PROJECT_NAME
export PROJECT_VERSION
export PROJECT_AUTHOR
export PROJECT_FORUM_THREAD
export PROJECT_FORUM_DOWNLOAD_ID


$(info Finished wicker Makefile preamble.)
