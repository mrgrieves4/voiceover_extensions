-- Speak Identifier Properly
--
-- Fixes VoiceOver's letter-by-letter spelling of long camelCase / PascalCase
-- identifiers (e.g. "oneTwoThreeFourFiveSixSevenEight") by re-speaking the
-- word with spaces inserted at case boundaries, e.g. "one Two Three Four...".
--
-- When the focused control is a text field/editor, uses the real
-- text-insertion caret (via the Accessibility API) and picks what to speak
-- in this order:
--   1. If there's a selection, speak the selection.
--   2. If the caret is touching a word (inside it, or immediately before
--      or after it), speak that word.
--   3. Otherwise (caret sitting only on whitespace/punctuation, not
--      touching any word) speak the whole current line.
-- If the focused control isn't a text field at all (e.g. focus is in the
-- terminal, or on some other kind of UI element), speaks whatever text the
-- VoiceOver cursor is currently on instead.
--
-- Install: see README.md. Assign to a shortcut via VoiceOver Utility >
-- Commanders > Keyboard Commander.

use scripting additions

on run
	set spokenText to ""
	set handledInTextControl to false
	set debugInfo to "identifier |"

	try
		tell application "System Events"
			set frontProcess to first process whose frontmost is true
			set frontAppName to name of frontProcess
			set focusedEl to value of attribute "AXFocusedUIElement" of frontProcess
			set focusedRole to value of attribute "AXRole" of focusedEl
			set selRange to value of attribute "AXSelectedTextRange" of focusedEl
			set fullText to value of attribute "AXValue" of focusedEl
		end tell

		set textLen to length of fullText
		set axLocation to item 1 of selRange
		set axLength to item 2 of selRange

		set spokenText to my resolveSpokenText(fullText, textLen, axLocation, axLength)
		set handledInTextControl to true

		set debugInfo to debugInfo & " frontApp=" & frontAppName & " role=" & focusedRole & " textLen=" & textLen & " axLocation=" & axLocation & " axLength=" & axLength & " resolved=[" & my previewOf(spokenText, 150) & "] fullTextPreview=[" & my previewOf(fullText, 250) & "]"
	on error errMsg
		set debugInfo to debugInfo & " SystemEvents-ERROR: " & errMsg
	end try

	-- Not a text control (or the Accessibility call failed): fall back to
	-- whatever text the VoiceOver cursor is currently on.
	if not handledInTextControl then
		try
			tell application "VoiceOver"
				set spokenText to text under cursor of vo cursor
			end tell
			set debugInfo to debugInfo & " VOcursorFallback=[" & my previewOf(spokenText, 250) & "]"
		on error errMsg2
			set debugInfo to debugInfo & " VOcursorFallback-ERROR: " & errMsg2
		end try
	end if

	my logDebug(debugInfo)

	if spokenText is "" then
		tell application "VoiceOver" to output "Nothing to read"
		return
	end if

	tell application "VoiceOver" to output my splitCamelCase(spokenText)
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

-- Decides what to speak for a focused text control, given its full value
-- and the raw (0-based) Accessibility selection location/length:
--   1. A real, single-line selection -> the selection.
--   2. Caret touching a word -> that word.
--   3. Otherwise -> the whole current line.
--
-- A selection that spans multiple lines is treated as if there were no
-- selection at all: VoiceOver itself leaves a selection behind in a text
-- control as it navigates (to visually mark what it's reading), and that
-- can span a large multi-line range with no relation to what the user
-- actually wants read. A deliberate user selection is normally confined to
-- one line, so this heuristic keeps rule 1 for genuine selections while
-- ignoring VoiceOver's own navigation artifacts.
on resolveSpokenText(fullText, textLen, axLocation, axLength)
	if textLen is 0 then return ""

	if axLength > 0 then
		set selStart to axLocation + 1
		set selEnd to axLocation + axLength
		if selStart < 1 then set selStart to 1
		if selEnd > textLen then set selEnd to textLen
		if selStart <= selEnd then
			set selText to text selStart thru selEnd of fullText
			if (selText does not contain linefeed) and (selText does not contain return) then
				return selText
			end if
		end if
	end if

	-- AXSelectedTextRange location is 0-based; AppleScript text is 1-based.
	set caretPos to axLocation + 1
	if caretPos > textLen then set caretPos to textLen
	if caretPos < 1 then set caretPos to 1

	set wordText to my extractIdentifierAt(fullText, textLen, caretPos)
	if wordText is not "" then return wordText

	return my currentLineText(fullText, textLen, caretPos)
end resolveSpokenText

-- Given the full text of a field, its length, and a 1-based caret index,
-- returns the contiguous run of identifier characters (letters, digits,
-- underscore) touching the caret - either inside a word, or immediately
-- before/after one. Returns "" if the caret isn't touching a word at all.
on extractIdentifierAt(fullText, textLen, caretPos)
	set wordChars to "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_"

	set atCaretIsWord to wordChars contains (character caretPos of fullText)
	set beforeCaretIsWord to (caretPos > 1) and (wordChars contains (character (caretPos - 1) of fullText))

	if not atCaretIsWord and not beforeCaretIsWord then return ""

	set probePos to caretPos
	if not atCaretIsWord then set probePos to caretPos - 1

	set startPos to probePos
	repeat while startPos > 1 and (wordChars contains (character (startPos - 1) of fullText))
		set startPos to startPos - 1
	end repeat

	set endPos to probePos
	repeat while endPos < textLen and (wordChars contains (character (endPos + 1) of fullText))
		set endPos to endPos + 1
	end repeat

	return text startPos thru endPos of fullText
end extractIdentifierAt

-- Returns the text of the line containing the 1-based position caretPos
-- within fullText (splitting on CR or LF).
on currentLineText(fullText, textLen, caretPos)
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

-- Inserts spaces at camelCase / PascalCase / acronym boundaries and turns
-- underscores into spaces, so VoiceOver reads real words instead of
-- spelling the identifier letter by letter.
on splitCamelCase(theWord)
	set shellCmd to "printf '%s' " & quoted form of theWord & ¬
		" | perl -CSD -pe 's/([a-z0-9])([A-Z])/$1 $2/g; s/([A-Z]+)([A-Z][a-z])/$1 $2/g; s/_/ /g'"
	return do shell script shellCmd
end splitCamelCase
