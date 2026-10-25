-- Last Spoken Text
--
-- Some controls (e.g. PyCharm's project tree) don't expose readable text via
-- the Accessibility API or the VoiceOver cursor, so speak_inner_text and
-- speak_identifier_properly can't pick anything up there. This works
-- regardless of the control, because it doesn't inspect the control at all -
-- it asks VoiceOver directly for the last thing it spoke.
--
-- Captures that text and shows it in a read-only text area (pre-selected, so
-- Cmd-C copies it immediately) so it can be read with the usual
-- text-navigation shortcuts (VO-W to spell a word, arrow keys to move by
-- character) - all of which work here because it's a normal, fully-accessible
-- Cocoa text view, unlike whatever control VoiceOver was originally reading.
-- Press Return or Escape, or VO-Space the Close button, to dismiss it; focus
-- then returns to whatever app was active before.
--
-- The window is a small app of its own, helpers/LastSpokenText.app (see
-- helpers/last_spoken_text_window.swift for why it isn't a display dialog
-- any more). This script just launches it with the text and finishes, so
-- leaving the window open doesn't hold up other Commander commands. It shows
-- up as "Last Spoken Text" in VoiceOver's application chooser if you lose
-- track of it, and running this again replaces any window still open.
--
-- IMPORTANT: assign this to its own direct Commander shortcut. Do not run it
-- through speak_menu - picking it from that list means arrowing through the
-- menu first, and VoiceOver announcing each menu item overwrites its "last
-- phrase" before this script ever runs, so it would show the menu item's
-- text instead of what you actually wanted.
--
-- Install: see README.md. Assign to a shortcut via VoiceOver Utility >
-- Commanders > Keyboard Commander.

use scripting additions

-- Set to true to write troubleshooting lines to ~/Library/Logs/VoiceOverExtensions.log.
-- Off by default so nothing accumulates on disk (the log can contain text you had
-- selected or focused). Recompile (see the Makefile) after changing this.
property debugLogging : false

on run
	-- Capture first, before anything else this script does might cause
	-- VoiceOver to speak again and overwrite it.
	set theText to ""
	try
		tell application "VoiceOver"
			set theText to content of last phrase
		end tell
		my logDebug("lastspoken | captured=[" & my previewOf(theText, 250) & "]")
	on error errMsg
		my logDebug("lastspoken | reading last phrase FAILED: " & errMsg)
	end try

	if theText is "" then
		tell application "VoiceOver" to output "No last spoken text"
		return
	end if

	-- The app lives in ../helpers/ relative to this script's folder
	-- (apple_scripts/). "open -n" starts a fresh copy each time, since args
	-- are only passed to a newly launched copy; the app closes any older one.
	-- open returns as soon as the app has launched, without waiting for the
	-- window to be closed.
	set appPath to (my scriptFolder()) & "../helpers/LastSpokenText.app"
	try
		do shell script "open -n " & quoted form of appPath & " --args " & quoted form of theText
		my logDebug("lastspoken | opened " & appPath)
	on error errMsg2
		my logDebug("lastspoken | opening " & appPath & " FAILED: " & errMsg2)
		tell application "VoiceOver" to output "Could not open the Last Spoken Text window"
	end try
end run

-- Returns the POSIX path (with trailing slash) of the folder containing
-- this running script, so appPath tracks wherever the repo was cloned to
-- instead of a hardcoded path.
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
