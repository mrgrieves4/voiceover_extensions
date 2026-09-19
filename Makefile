SOURCES := $(wildcard apple_scripts/*.applescript)
SCRIPTS := $(SOURCES:.applescript=.scpt)

.PHONY: all scripts helper

# Compile the AppleScripts (only those whose source has changed).
all: scripts
scripts: $(SCRIPTS)

apple_scripts/%.scpt: apple_scripts/%.applescript
	osacompile -o $@ $<

# Rebuild the Swift helper used by speak_table_position (needs swiftc).
helper: helpers/ax_table_position

helpers/ax_table_position: helpers/ax_table_position.swift
	swiftc $< -o $@
