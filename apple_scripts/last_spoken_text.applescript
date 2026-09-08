-- Last Spoken Text
--
-- Some controls (e.g. PyCharm's project tree) don't expose readable text via
-- the Accessibility API or the VoiceOver cursor, so speak_inner_text and
-- speak_identifier_properly can't pick anything up there. This works
-- regardless of the control, because it doesn't inspect the control at all -
-- it asks VoiceOver directly for the last thing it spoke.
--
-- Captures that text and shows it in an editable field (pre-selected, so
-- Cmd-C copies it immediately) so it can be read with the usual
-- text-navigation shortcuts (VO-W to spell a word, VO-Shift-Left/Right to
-- move by character) - all of which work here because the field is a
-- normal, fully-accessible Cocoa text field, unlike whatever control
-- VoiceOver was originally reading. Press Return, or VO-Space the Close
-- button, to dismiss it; either way focus returns to whatever app/control
-- was active before the dialog appeared. Escape does NOT dismiss it - the
-- text field swallows it rather than passing it up to the button, a known
-- Cocoa quirk with editable-field dialogs that isn't fixable without a much
-- heavier custom panel, so Return is the keyboard way to close this.
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

	-- Remember what was focused before the dialog steals it, so it can be
	-- restored afterwards - dismissing this dialog doesn't hand focus back
	-- to whatever app/control you were using on its own, and VoiceOver ends
	-- up stranded on Finder with nothing to land on, reading blank as you
	-- move around.
	set previousAppName to ""
	try
		tell application "System Events"
			set previousAppName to name of (first process whose frontmost is true)
		end tell
		my logDebug("lastspoken | previousAppName=" & previousAppName)
	on error errMsg2
		my logDebug("lastspoken | previousAppName lookup FAILED: " & errMsg2)
	end try

	-- Show it via Finder rather than System Events: a dialog shown by this
	-- script's own process has nowhere to render under VoiceOver Commander
	-- and just hangs instead of erroring, but System Events is a background
	-- agent app that macOS won't actually bring to the real foreground -
	-- "activate" on it returns without error but "frontmost" stays false,
	-- so real key presses keep going to whatever was genuinely frontmost
	-- before, not to its dialog. Only VoiceOver's own accessibility-action
	-- clicks (e.g. VO-Space on a button) still worked through that, since
	-- those bypass real keyboard/window focus entirely. Finder is a normal
	-- foreground-capable app that's always running, so it actually gets
	-- real key presses - confirmed working for Return; Escape specifically
	-- still doesn't reach the cancel button (see the note above run).
	try
		tell application "Finder" to activate
	on error errMsg3
		my logDebug("lastspoken | activate Finder FAILED: " & errMsg3)
	end try

	-- The button is both the default and the cancel button, so both Return
	-- and a click/VO-Space on it raise the same "user cancelled" (-128)
	-- error - there's no button-press case that returns normally here.
	try
		tell application "Finder"
			display dialog "VoiceOver last said:" with title "Last Spoken Text" default answer theText buttons {"Close"} default button "Close" cancel button "Close"
		end tell
		my logDebug("lastspoken | dialog returned without an error (unexpected)")
	on error errMsg4 number errNum
		if errNum is -128 then
			my logDebug("lastspoken | dialog dismissed")
		else
			my logDebug("lastspoken | display dialog FAILED (" & errNum & "): " & errMsg4)
		end if
	end try

	if previousAppName is not "" then
		try
			tell application previousAppName to activate
			my logDebug("lastspoken | reactivated " & previousAppName)
		on error errMsg5
			my logDebug("lastspoken | reactivate " & previousAppName & " FAILED: " & errMsg5)
		end try
	end if
end run

-- Appends a line to ~/Library/Logs/VoiceOverExtensions.log for troubleshooting.
-- Never lets a logging failure interrupt the main behaviour.
on logDebug(msg)
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
