SOURCES := $(wildcard apple_scripts/*.applescript)
SCRIPTS := $(SOURCES:.applescript=.scpt)
LAST_SPOKEN_APP := helpers/LastSpokenText.app

.PHONY: all scripts helper

# Compile the AppleScripts (only those whose source has changed).
all: scripts
scripts: $(SCRIPTS)

apple_scripts/%.scpt: apple_scripts/%.applescript
	osacompile -o $@ $<

# Rebuild the Swift helpers (needs swiftc): the one used by the table
# scripts, and the window app used by last_spoken_text.
helper: helpers/ax_table_position $(LAST_SPOKEN_APP)

helpers/ax_table_position: helpers/ax_table_position.swift
	swiftc $< -o $@

$(LAST_SPOKEN_APP): helpers/last_spoken_text_window.swift helpers/LastSpokenText-Info.plist
	rm -rf $@
	mkdir -p $@/Contents/MacOS
	cp helpers/LastSpokenText-Info.plist $@/Contents/Info.plist
	swiftc $< -o $@/Contents/MacOS/LastSpokenText
	codesign --force --sign - $@
