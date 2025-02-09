# https://github.com/FarManagerLegacy/HelpDown-scripts

# required user setting
BASE:=D:\repo\HelpDown-scripts
PANDOC:=C:\Apps\pandoc\pandoc.exe
HTMLTOFARHELP:="$(FARPROFILE)\tools\HtmlToFarHelp\HtmlToFarHelp.exe"

# plug base Makefile
include $(BASE)/Makefile
.DEFAULT_GOAL:=hlf

# optional local customization
%.hlfhtml: FLAGS+=--lua-filter addRefs.lua
%: FLAGS+= --toc --lua-filter TitleH1LevelDown.lua --shift-heading-level-by=1

README.md: askai.ru.md
	@echo $@
	@if exist $@ del $@
	@ren $< $@

.PHONY: all post
all: hlf forum README.md

post: askai.ru.forum
	@env \
	  PASSWORD=$(shell KeePassCommand.cmd getfieldraw forum.farmanager.com Password) \
	  USERNAME="John Doe" \
	  POST_ID=178068 \
	  FILE="$<" \
	  CLEANUP=false \
	  $(BASE)/update_post.sh
