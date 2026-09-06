-- Speak Table Position
--
-- Announces the row and column of the table cell currently in VoiceOver
-- focus (e.g. "Row 3, Column 4"), for when you just want a one-off check
-- rather than having VoiceOver announce it on every move.
--
-- Tries, in order:
--   1. The focused element itself has AXRowIndexRange/AXColumnIndexRange
--      (it IS a cell).
--   2. The focused element is the table/outline itself (has
--      AXSelectedRows/AXSelectedCells) - drills into the first selected
--      row/cell and looks for AXIndex or AXRowIndexRange/
--      AXColumnIndexRange there instead.
-- If neither works, logs the attribute names available on the focused
-- element (and on the selected row/cell, if found) so the approach can be
-- refined against real data instead of guessing further blind.
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

		-- Strategy 1: the focused element is itself a cell.
		set rowIndex to my tryGetRangeStart(focusedEl, "AXRowIndexRange")
		set colIndex to my tryGetRangeStart(focusedEl, "AXColumnIndexRange")

		if rowIndex is not missing value and colIndex is not missing value then
			set resultText to "Row " & (rowIndex + 1) & ", Column " & (colIndex + 1)
			my logDebug("tableposition | (direct on focused element) " & resultText)
		else
			-- Strategy 2: the focused element is the table/outline itself;
			-- drill into its selected row/cell instead.
			set selectedRow to my tryGetFirstOf(focusedEl, "AXSelectedRows")
			set selectedCell to my tryGetFirstOf(focusedEl, "AXSelectedCells")

			set rowIndex to missing value
			set colIndex to missing value

			if selectedRow is not missing value then
				set rowIndex to my tryGetValue(selectedRow, "AXIndex")
				if rowIndex is missing value then set rowIndex to my tryGetRangeStart(selectedRow, "AXRowIndexRange")
			end if

			if selectedCell is not missing value then
				set colIndex to my tryGetRangeStart(selectedCell, "AXColumnIndexRange")
				if colIndex is missing value then set colIndex to my tryGetValue(selectedCell, "AXIndex")
				if rowIndex is missing value then set rowIndex to my tryGetRangeStart(selectedCell, "AXRowIndexRange")
			end if

			if rowIndex is not missing value and colIndex is not missing value then
				set resultText to "Row " & (rowIndex + 1) & ", Column " & (colIndex + 1)
				my logDebug("tableposition | (via selected row/cell) " & resultText)
			else
				my logDebug("tableposition | unresolved: rowIndex=" & rowIndex & " colIndex=" & colIndex)
				my logDumpAttributes(focusedEl, "focusedEl")
				if selectedRow is not missing value then my logDumpAttributes(selectedRow, "selectedRow")
				if selectedCell is not missing value then my logDumpAttributes(selectedCell, "selectedCell")
			end if
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

-- Reads a plain-valued attribute (e.g. AXIndex), or missing value if it
-- isn't present/readable.
on tryGetValue(theElement, attrName)
	try
		tell application "System Events"
			return value of attribute attrName of theElement
		end tell
	on error
		return missing value
	end try
end tryGetValue

-- Returns the first item of a list-valued attribute (e.g. AXSelectedRows),
-- or missing value if it's absent/empty/unreadable.
on tryGetFirstOf(theElement, attrName)
	try
		tell application "System Events"
			set theList to value of attribute attrName of theElement
		end tell
		if (count of theList) > 0 then
			return item 1 of theList
		else
			return missing value
		end if
	on error
		return missing value
	end try
end tryGetFirstOf

-- Logs the AXRole and every attribute name available on theElement, for
-- troubleshooting when row/column can't be determined automatically.
on logDumpAttributes(theElement, labelText)
	try
		set roleText to my tryGetValue(theElement, "AXRole")
		tell application "System Events"
			set attrNames to name of every attribute of theElement
		end tell
		set AppleScript's text item delimiters to ", "
		set attrList to attrNames as text
		set AppleScript's text item delimiters to ""
		my logDebug("tableposition | " & labelText & " (role=" & roleText & ") attributes: " & attrList)
	on error errMsg
		my logDebug("tableposition | could not enumerate " & labelText & " attributes: " & errMsg)
	end try
end logDumpAttributes

-- Appends a line to ~/Library/Logs/VoiceOverExtensions.log for troubleshooting.
-- Never lets a logging failure interrupt the main behaviour.
on logDebug(msg)
	try
		set ts to (do shell script "date '+%Y-%m-%d %H:%M:%S'")
		set logPath to (POSIX path of (path to library folder from user domain)) & "Logs/VoiceOverExtensions.log"
		do shell script "printf '%s\n' " & quoted form of (ts & " | " & msg) & " >> " & quoted form of logPath
	end try
end logDebug
