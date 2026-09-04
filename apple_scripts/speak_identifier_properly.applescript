-- Speak Identifier Properly
--
-- Fixes VoiceOver's letter-by-letter spelling of long camelCase / PascalCase
-- identifiers (e.g. "oneTwoThreeFourFiveSixSevenEight") by re-speaking the
-- word with spaces inserted at case boundaries, e.g. "one Two Three Four...".
--
-- Two ways it finds the word to speak, tried in order:
--   1. The text-insertion caret of the currently focused control (works in
--      any text editor / code editor: it looks at the real caret position,
--      not the VoiceOver cursor, so it works even if the VO cursor is
--      sitting on a whole text area rather than a single word).
--   2. Fallback: whatever text the VoiceOver cursor is currently on.
--
-- Install: see README.md. Assign to a shortcut via VoiceOver Utility >
-- Commanders > Keyboard Commander.

use scripting additions

on run
	set wordText to ""
	set gotWord to false

	-- 1. Preferred: real text caret, via the Accessibility API.
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

			set wordText to my extractIdentifierAt(fullText, caretPos)
			if wordText is not "" then set gotWord to true
		end if
	end try

	-- 2. Fallback: text under the VoiceOver cursor.
	if not gotWord then
		try
			tell application "VoiceOver"
				set wordText to text under cursor of vo cursor
			end tell
		end try
	end if

	if wordText is "" then
		tell application "VoiceOver" to output "Nothing to read"
		return
	end if

	set spokenText to my splitCamelCase(wordText)
	tell application "VoiceOver" to output spokenText
end run

-- Given the full text of a field and a 1-based caret index, return the
-- contiguous run of identifier characters (letters, digits, underscore)
-- touching the caret. If the caret sits between words, prefers the word
-- immediately to its left (normal "cursor is on this word" behaviour).
on extractIdentifierAt(fullText, caretPos)
	set wordChars to "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_"
	set textLen to length of fullText
	if textLen is 0 then return ""

	set probePos to caretPos
	if probePos > textLen then set probePos to textLen
	if probePos < 1 then set probePos to 1

	set atCaretIsWord to wordChars contains (character probePos of fullText)
	set beforeCaretIsWord to (probePos > 1) and (wordChars contains (character (probePos - 1) of fullText))

	if not atCaretIsWord and beforeCaretIsWord then
		set probePos to probePos - 1
	end if

	if not (wordChars contains (character probePos of fullText)) then return ""

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

-- Inserts spaces at camelCase / PascalCase / acronym boundaries and turns
-- underscores into spaces, so VoiceOver reads real words instead of
-- spelling the identifier letter by letter.
on splitCamelCase(theWord)
	set shellCmd to "printf '%s' " & quoted form of theWord & ¬
		" | perl -CSD -pe 's/([a-z0-9])([A-Z])/$1 $2/g; s/([A-Z]+)([A-Z][a-z])/$1 $2/g; s/_/ /g'"
	return do shell script shellCmd
end splitCamelCase
