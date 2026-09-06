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
	{label:"Speak Identifier Properly", scriptFile:"speak_identifier_properly.scpt"}, ¬
	{label:"Speak Indentation Level", scriptFile:"speak_indentation_level.scpt"}}

on run
	-- Remember what was focused before the picker steals focus, so the
	-- chosen script sees the real app/text field afterwards, not this dialog.
	set previousAppName to ""
	try
		tell application "System Events"
			set previousAppName to name of (first process whose frontmost is true)
		end tell
	end try

	set labels to {}
	repeat with anAction in menuActions
		set end of labels to label of anAction
	end repeat

	set chosen to choose from list labels with title "VoiceOver Extensions" with prompt "Choose an action:"
	if chosen is false then return

	if previousAppName is not "" then
		try
			tell application previousAppName to activate
			delay 0.15
		end try
	end if

	set chosenLabel to item 1 of chosen
	repeat with anAction in menuActions
		if label of anAction is chosenLabel then
			set targetScript to load script POSIX file (scriptsFolder & (scriptFile of anAction))
			run targetScript
			return
		end if
	end repeat
end run
