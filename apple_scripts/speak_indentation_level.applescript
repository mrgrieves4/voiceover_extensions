-- Speak Indentation Level
--
-- Announces the leading whitespace of the current line, e.g. "4 spaces",
-- "1 tab", "No indentation", regardless of where on the line the text
-- caret currently sits.
--
-- Uses the real text-insertion caret (via the Accessibility API) to find
-- the current line inside the focused control's full text, then counts
-- leading tabs/spaces on that line.
--
-- Install: see README.md. Assign to a shortcut via VoiceOver Utility >
-- Commanders > Keyboard Commander.

use scripting additions

on run
	set lineText to ""
	set gotLine to false

	try
		tell application "System Events"
			set frontProcess to first process whose frontmost is true
			set focusedEl to value of attribute "AXFocusedUIElement" of frontProcess
			set selRange to value of attribute "AXSelectedTextRange" of focusedEl
			set fullText to value of attribute "AXValue" of focusedEl
		end tell

		set textLen to length of fullText
		if textLen > 0 then
			-- AXSelectedTextRange location is 0-based; AppleScript text is 1-based.
			set caretPos to (item 1 of selRange) + 1
			if caretPos > textLen then set caretPos to textLen
			if caretPos < 1 then set caretPos to 1

			set lineText to my currentLineText(fullText, caretPos)
			set gotLine to true
		end if
	end try

	-- Fallback: whatever text the VoiceOver cursor is on (e.g. if VO's own
	-- line navigation already isolated the current line).
	if not gotLine then
		try
			tell application "VoiceOver"
				set lineText to text under cursor of vo cursor
			end tell
		end try
	end if

	set spokenText to my describeIndentation(lineText)
	tell application "VoiceOver" to output spokenText
end run

-- Returns the text of the line containing the 1-based position caretPos
-- within fullText (splitting on CR or LF).
on currentLineText(fullText, caretPos)
	set textLen to length of fullText
	if textLen is 0 then return ""
	if caretPos > textLen then set caretPos to textLen
	if caretPos < 1 then set caretPos to 1

	set startPos to caretPos
	repeat while startPos > 1 and (character (startPos - 1) of fullText is not linefeed) and (character (startPos - 1) of fullText is not return)
		set startPos to startPos - 1
	end repeat

	set endPos to caretPos
	if (character endPos of fullText is linefeed) or (character endPos of fullText is return) then
		set endPos to endPos - 1
	else
		repeat while endPos < textLen and (character (endPos + 1) of fullText is not linefeed) and (character (endPos + 1) of fullText is not return)
			set endPos to endPos + 1
		end repeat
	end if

	if startPos > endPos then return ""
	return text startPos thru endPos of fullText
end currentLineText

-- Counts leading tabs/spaces on a line and describes them in words.
on describeIndentation(lineText)
	set n to length of lineText
	set spaceCount to 0
	set tabCount to 0
	set i to 1
	repeat while i ≤ n
		set c to character i of lineText
		if c is tab then
			set tabCount to tabCount + 1
		else if c is space then
			set spaceCount to spaceCount + 1
		else
			exit repeat
		end if
		set i to i + 1
	end repeat

	if tabCount is 0 and spaceCount is 0 then
		if n is 0 then
			return "Blank line, no indentation"
		else
			return "No indentation"
		end if
	end if

	set parts to {}
	if tabCount is 1 then
		set end of parts to "1 tab"
	else if tabCount > 1 then
		set end of parts to (tabCount as text) & " tabs"
	end if
	if spaceCount is 1 then
		set end of parts to "1 space"
	else if spaceCount > 1 then
		set end of parts to (spaceCount as text) & " spaces"
	end if

	set AppleScript's text item delimiters to " and "
	set resultText to parts as text
	set AppleScript's text item delimiters to ""

	if tabCount > 0 and spaceCount > 0 then
		set resultText to resultText & ", mixed indentation"
	end if

	return resultText
end describeIndentation
