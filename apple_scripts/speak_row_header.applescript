-- Speak Row Header
--
-- Speaks the header of the row the VoiceOver cursor is in, for when
-- VoiceOver doesn't announce one as you move across a wide table. Uses the
-- row's proper header if it has one; otherwise the text of the row's first
-- cell, or its second cell if the first has no text (e.g. a tickbox column).
--
-- Like speak_table_position, this finds the cell under the VoiceOver
-- cursor by hit-testing at the cursor's on-screen position, and leaves the
-- accessibility work (finding the table and the header or fallback cell,
-- and reading its text) to the compiled helper at helpers/ax_table_position
-- - see speak_table_position.applescript and helpers/ax_table_position.swift.
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
	set resultText to "Could not find a row header"

	try
		tell application "VoiceOver"
			set cursorBounds to bounds of vo cursor
		end tell
		set boundsList to cursorBounds as list
		my logDebug("rowheader | cursorBounds=" & (boundsList as text))

		set {x0, y0, x1, y1} to boundsList
		set midX to (x0 + x1) / 2
		set midY to (y0 + y1) / 2
		my logDebug("rowheader | hit-testing at " & midX & "," & midY)

		set helperOutput to do shell script quoted form of helperPath & " " & midX & " " & midY & " row-header"
		my logDebug("rowheader | helper output: " & helperOutput)

		if helperOutput is "TEXT" or helperOutput starts with "TEXT " then
			if length of helperOutput > 5 then
				set resultText to text 6 thru -1 of helperOutput
			else
				set resultText to "Blank"
			end if
		end if
	on error errMsg
		my logDebug("rowheader | error: " & errMsg)
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
