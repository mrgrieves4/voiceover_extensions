-- Speak Table Position
--
-- Announces the row and column of the table cell currently in VoiceOver
-- focus (e.g. "Row 3, Column 4"), for when you just want a one-off check
-- rather than having VoiceOver announce it on every move.
--
-- This is a first attempt: it reads the AXRowIndexRange/AXColumnIndexRange
-- Accessibility attributes of the focused element. If those aren't present
-- (some tables expose position differently), it logs every attribute name
-- available on the element so the approach can be refined against real
-- data instead of guessing further blind.
--
-- Install: see README.md. Assign to a shortcut via VoiceOver Utility >
-- Commanders > Keyboard Commander, or add it to speak_menu.

use scripting additions

on run
	set resultText to "Could not determine table position"

	try
		tell application "System Events"
			set frontProcess to first process whose frontmost is true
			set focusedEl to value of attribute "AXFocusedUIElement" of frontProcess
		end tell

		set rowIndex to my tryGetRangeStart(focusedEl, "AXRowIndexRange")
		set colIndex to my tryGetRangeStart(focusedEl, "AXColumnIndexRange")

		if rowIndex is not missing value and colIndex is not missing value then
			set resultText to "Row " & (rowIndex + 1) & ", Column " & (colIndex + 1)
			my logDebug("tableposition | " & resultText)
		else
			my logDebug("tableposition | rowIndex=" & rowIndex & " colIndex=" & colIndex & " - dumping attributes")
			try
				tell application "System Events"
					set attrNames to name of every attribute of focusedEl
				end tell
				set AppleScript's text item delimiters to ", "
				set attrList to attrNames as text
				set AppleScript's text item delimiters to ""
				my logDebug("tableposition | available attributes: " & attrList)
			on error errMsg2
				my logDebug("tableposition | could not enumerate attributes: " & errMsg2)
			end try
		end if
	on error errMsg
		my logDebug("tableposition | error: " & errMsg)
	end try

	tell application "VoiceOver" to output resultText
end run

-- Reads an Accessibility range-valued attribute (e.g. AXRowIndexRange) from
-- theElement and returns just its 0-based start index, or missing value if
-- the attribute isn't present/readable.
on tryGetRangeStart(theElement, attrName)
	try
		tell application "System Events"
			set r to value of attribute attrName of theElement
		end tell
		return item 1 of r
	on error
		return missing value
	end try
end tryGetRangeStart

-- Appends a line to ~/Library/Logs/VoiceOverExtensions.log for troubleshooting.
-- Never lets a logging failure interrupt the main behaviour.
on logDebug(msg)
	try
		set ts to (do shell script "date '+%Y-%m-%d %H:%M:%S'")
		set logPath to (POSIX path of (path to library folder from user domain)) & "Logs/VoiceOverExtensions.log"
		do shell script "printf '%s\n' " & quoted form of (ts & " | " & msg) & " >> " & quoted form of logPath
	end try
end logDebug
