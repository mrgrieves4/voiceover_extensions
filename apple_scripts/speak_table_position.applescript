-- Speak Table Position
--
-- Announces the row and column of the table cell currently under the
-- VoiceOver cursor (e.g. "Row 3, Column 4").
--
-- Uses the VoiceOver cursor's on-screen position to hit-test the
-- accessibility tree directly, rather than relying on real keyboard focus
-- (System Events' AXFocusedUIElement) - tables/outlines are usually
-- browsed with VoiceOver's own virtual cursor without moving real
-- keyboard focus at all, the same reason speak_inner_text exists for
-- headings.
--
-- The actual hit-testing and row/column lookup is done by the compiled
-- helper at helpers/ax_table_position (see helpers/ax_table_position.swift)
-- rather than in AppleScript directly: unpacking the accessibility API's
-- row/column range values isn't reliably possible from plain
-- AppleScriptObjC, but is straightforward in Swift.
--
-- Install: see README.md. Assign to a shortcut via VoiceOver Utility >
-- Commanders > Keyboard Commander, or add it to speak_menu.

use scripting additions

-- Set to true to write troubleshooting lines to ~/Library/Logs/VoiceOverExtensions.log.
-- Off by default so nothing accumulates on disk (the log can contain text you had
-- selected or focused). Recompile (see the Makefile) after changing this.
property debugLogging : false

-- Resolved at run time from this script's own location (see scriptFolder()
-- below), rather than hardcoded, so the repo can live anywhere. The helper
-- lives in ../helpers/ relative to this script's folder (apple_scripts/).
property helperPath : missing value

on run
	set helperPath to (my scriptFolder()) & "../helpers/ax_table_position"
	set resultText to "Could not determine table position"

	try
		tell application "VoiceOver"
			set cursorBounds to bounds of vo cursor
		end tell
		set boundsList to cursorBounds as list
		my logDebug("tableposition | cursorBounds=" & (boundsList as text))

		set {x0, y0, x1, y1} to boundsList
		set midX to (x0 + x1) / 2
		set midY to (y0 + y1) / 2
		my logDebug("tableposition | hit-testing at " & midX & "," & midY)

		set helperOutput to do shell script quoted form of helperPath & " " & midX & " " & midY
		my logDebug("tableposition | helper output: " & helperOutput)

		if helperOutput starts with "OK " then
			set theRest to text 4 thru -1 of helperOutput
			set AppleScript's text item delimiters to " "
			set theParts to text items of theRest
			set AppleScript's text item delimiters to ""
			set rowIndex to (item 1 of theParts) as integer
			set colIndex to (item 2 of theParts) as integer
			set resultText to "Row " & (rowIndex + 1) & ", Column " & (colIndex + 1)
		end if
	on error errMsg
		my logDebug("tableposition | error: " & errMsg)
	end try

	tell application "VoiceOver" to output resultText
end run

-- Returns the POSIX path (with trailing slash) of the folder containing
-- this running script, so helperPath tracks wherever the repo was cloned
-- to instead of a hardcoded path.
on scriptFolder()
	set scriptPosixPath to POSIX path of (path to me)
	return (do shell script "dirname " & quoted form of scriptPosixPath) & "/"
end scriptFolder

-- Appends a line to ~/Library/Logs/VoiceOverExtensions.log for troubleshooting.
-- Never lets a logging failure interrupt the main behaviour.
on logDebug(msg)
	if not debugLogging then return
	try
		set ts to (do shell script "date '+%Y-%m-%d %H:%M:%S'")
		set logPath to (POSIX path of (path to library folder from user domain)) & "Logs/VoiceOverExtensions.log"
		do shell script "printf '%s\n' " & quoted form of (ts & " | " & msg) & " >> " & quoted form of logPath
	end try
end logDebug
