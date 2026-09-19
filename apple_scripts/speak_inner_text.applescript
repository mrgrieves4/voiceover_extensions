-- Speak Inner Text
--
-- Works around a VoiceOver bug: a heading (or other element) that contains
-- a child element sometimes gets announced as its child count (e.g.
-- "2 items") instead of its actual text. This speaks the combined text of
-- whatever the VoiceOver cursor is currently on instead.
--
-- Unlike the text-editing scripts in this project, this always uses the
-- VoiceOver cursor rather than the text-insertion caret - it's meant for
-- general VO navigation (headings, buttons, etc), not text fields.
--
-- Install: see README.md. Assign to a shortcut via VoiceOver Utility >
-- Commanders > Keyboard Commander, or add it to speak_menu.

use scripting additions

-- Set to true to write troubleshooting lines to ~/Library/Logs/VoiceOverExtensions.log.
-- Off by default so nothing accumulates on disk (the log can contain text you had
-- selected or focused). Recompile (see the Makefile) after changing this.
property debugLogging : false

on run
	set theText to ""
	try
		tell application "VoiceOver"
			set theText to text under cursor of vo cursor
		end tell
		my logDebug("innertext | text under cursor: [" & my previewOf(theText, 250) & "]")
	on error errMsg
		my logDebug("innertext | error: " & errMsg)
	end try

	if theText is "" then
		tell application "VoiceOver" to output "No text found"
		return
	end if

	tell application "VoiceOver" to output theText
end run

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

-- Truncates text to maxLen characters and replaces line breaks with visible
-- "\n"/"\r" markers so a preview stays on one log line.
on previewOf(theText, maxLen)
	set t to theText
	if (length of t) > maxLen then set t to (text 1 thru maxLen of t) & "…"

	set AppleScript's text item delimiters to linefeed
	set theParts to text items of t
	set AppleScript's text item delimiters to "\\n"
	set t to theParts as text

	set AppleScript's text item delimiters to return
	set theParts to text items of t
	set AppleScript's text item delimiters to "\\r"
	set t to theParts as text

	set AppleScript's text item delimiters to ""
	return t
end previewOf
