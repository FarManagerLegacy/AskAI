# https://github.com/FarManagerLegacy/HelpDown-scripts

# required user setting
BASE:=D:\repo\HelpDown-scripts
PANDOC:=C:\Apps\pandoc\pandoc.exe
HTMLTOFARHELP:=$(FARPROFILE)\tools\HtmlToFarHelp\HtmlToFarHelp.exe

# plug base Makefile
include $(BASE)\Makefile
.DEFAULT_GOAL:=hlf

# optional local customization
%.hlfhtml: FLAGS+=--lua-filter addRefs.lua
%: FLAGS+= --toc

README.md: askai.ru.md
	@echo $@
	@if exist $@ del $@
	@ren $< $@

.PHONY: all
all: hlf forum README.md
