-- VoiceOver Extensions Menu
--
-- Shows a list of the available VoiceOver Extensions scripts and runs
-- whichever one is chosen. Bind a single VoiceOver Commander shortcut to
-- this menu instead of one shortcut per script - each script stays its
-- own separate, independently runnable file; this just links them.
--
-- Use the arrow keys to move through the list (typing a letter jumps to
-- the next item starting with that letter), then press Return to run it,
-- or Escape to cancel.
--
-- To add another script to the menu, add one record to menuActions below.
--
-- Install: assign this script's .scpt to a VoiceOver Commander shortcut.
-- The individual scripts can still be assigned to their own shortcuts too,
-- if you want direct access to any of them as well.

use scripting additions

property scriptsFolder : "/Users/johncarpenter/projects/voiceover_extensions/apple_scripts/"

property menuActions : {¬
	{label:"Identifiers", scriptFile:"speak_identifier_properly.scpt"}, ¬
	{label:"Indentation", scriptFile:"speak_indentation_level.scpt"}}

on run
	my logDebug("menu | run started")

	-- Remember what was focused before the picker steals focus, so the
	-- chosen script sees the real app/text field afterwards, not this dialog.
	set previousAppName to ""
	try
		tell application "System Events"
			set previousAppName to name of (first process whose frontmost is true)
		end tell
		my logDebug("menu | previousAppName=" & previousAppName)
	on error errMsg
		my logDebug("menu | previousAppName lookup FAILED: " & errMsg)
	end try

	set labels to {}
	repeat with anAction in menuActions
		set end of labels to label of anAction
	end repeat

	-- Show the picker via System Events rather than directly: a dialog shown
	-- by the script's own process has no window to render in under
	-- VoiceOver Commander (it just hangs, taking Commander down with it),
	-- since whatever runs Commander scripts isn't a normal foreground GUI
	-- process. System Events is always running as a proper GUI-capable
	-- process, so routing the dialog through it gives it somewhere to show.
	try
		tell application "System Events" to activate
	on error errMsg
		my logDebug("menu | activate System Events FAILED: " & errMsg)
	end try

	try
		tell application "System Events"
			set chosen to choose from list labels with title "VoiceOver Extensions" with prompt "Choose an action:"
		end tell
		my logDebug("menu | choose from list returned: " & (chosen as text))
	on error errMsg number errNum
		my logDebug("menu | choose from list FAILED (" & errNum & "): " & errMsg)
		return
	end try

	if chosen is false then
		my logDebug("menu | user cancelled")
		return
	end if

	if previousAppName is not "" then
		try
			tell application previousAppName to activate
			delay 0.15
		on error errMsg
			my logDebug("menu | re-activate " & previousAppName & " FAILED: " & errMsg)
		end try
	end if

	set chosenLabel to item 1 of chosen
	my logDebug("menu | chosenLabel=" & chosenLabel)

	repeat with anAction in menuActions
		if label of anAction is chosenLabel then
			try
				set targetScript to load script POSIX file (scriptsFolder & (scriptFile of anAction))
				run targetScript
				my logDebug("menu | ran " & (scriptFile of anAction))
			on error errMsg
				my logDebug("menu | running " & (scriptFile of anAction) & " FAILED: " & errMsg)
			end try
			return
		end if
	end repeat

	my logDebug("menu | no matching action for label: " & chosenLabel)
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
