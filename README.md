# VoiceOver Extensions

Two AppleScripts for VoiceOver's "Commander" feature (custom keyboard shortcuts
you assign in VoiceOver Utility), addressing two everyday annoyances:

1. **`speak_identifier_properly`** — VoiceOver spells long camelCase/PascalCase
   identifiers letter-by-letter instead of reading them as words (e.g.
   `oneTwoThreeFourFiveSixSevenEight` gets spelled out). This script grabs the
   identifier at your text cursor (or under the VO cursor), inserts spaces at
   the case boundaries, and has VoiceOver speak the result — so you hear
   "one Two Three Four Five Six Seven Eight" instead of individual letters.

2. **`speak_indentation_level`** — announces the leading whitespace of the
   current line (e.g. "4 spaces", "1 tab", "No indentation"), no matter where
   on the line your text cursor actually is.

## How they find the text

Both scripts try two approaches, in order:

1. **Real text caret (preferred).** Uses the Accessibility API (via
   `System Events`) to read the focused control's full text and the actual
   text-insertion caret position, then extracts just the identifier or line
   you're on. This is what makes both scripts work correctly in a code
   editor / text field where the caret can be anywhere — not just where the
   VoiceOver cursor happens to be.
2. **VoiceOver cursor fallback.** If there's no focused text control (or the
   Accessibility call fails), it falls back to whatever text the VoiceOver
   cursor (`vo cursor`) is currently on.

This was verified against this Mac's actual `System Events` behavior — some
older macOS versions can't read `AXSelectedTextRange` via AppleScript at all,
but on this system (macOS 26.6.2) it works correctly.

## Files

- `apple_scripts/speak_identifier_properly.applescript` — source
- `apple_scripts/speak_identifier_properly.scpt` — compiled (use this one in VoiceOver Utility)
- `apple_scripts/speak_indentation_level.applescript` — source
- `apple_scripts/speak_indentation_level.scpt` — compiled (use this one in VoiceOver Utility)

If you edit the `.applescript` source, recompile with:

```bash
cd apple_scripts
osacompile -o speak_identifier_properly.scpt speak_identifier_properly.applescript
osacompile -o speak_indentation_level.scpt speak_indentation_level.applescript
```

## Installing as VoiceOver shortcuts

1. Open **VoiceOver Utility** (VO-F8 while VoiceOver is running, or launch it directly).
2. Go to **Commanders → Keyboard Commander** (the trackpad commander also works if you prefer trackpad gestures).
3. Click **+** to add a new command.
4. Set **Type** to a keyboard shortcut of your choice (pick something not already bound — e.g. VO-Shift-I for "identifier" and VO-Shift-L for "indent level").
5. Set the command's action to run a script, and browse to the `.scpt` file (`speak_identifier_properly.scpt` / `speak_indentation_level.scpt`).
6. Save, and try it out.

## Testing

I deliberately did not trigger these scripts myself (calling the `VoiceOver`
app via AppleScript activates VoiceOver, which I didn't want to do
unannounced on your live session). I did test all the underlying logic
(word-boundary extraction, camelCase splitting, indentation counting) directly
against the compiled scripts, bypassing the VoiceOver calls — that part is
verified correct, e.g.:

- `XMLHttpRequestParser` → "XML Http Request Parser"
- `oneTwoThreeFourFiveSixSevenEight` → "one Two Three Four Five Six Seven Eight"
- caret on `.` right after `barBaz` in `barBaz.qux` → correctly picks "barBaz"
- 4-space indented line → "4 spaces"; 2-tab line → "2 tabs"; blank line → "Blank line, no indentation"

What still needs real-world testing with VoiceOver actually running:

- Whether the `AXSelectedTextRange` offset is exactly right in every app you
  care about (some apps report offsets slightly differently — if a word
  extraction is consistently off by one character, that's an easy fix).
- Behavior in specific editors (Xcode, VS Code, BBEdit, Terminal, etc.) —
  some apps expose their text view to the Accessibility API differently.
- Whether VO Commander scripts run with enough Accessibility permission out
  of the box, or whether you need to explicitly add something under
  **System Settings → Privacy & Security → Accessibility**. If a script
  silently does nothing, that's the first thing to check — try running the
  `.scpt` directly via Script Editor or `osascript apple_scripts/speak_identifier_properly.scpt`
  while focused in a text field, and see if it errors.

## Known limitations

- The camelCase splitter treats letters/digits/underscore as "word"
  characters; it won't do anything useful to non-identifier text.
- Indentation detection assumes plain spaces/tabs; it doesn't understand
  editor-specific soft-wrap or virtual indentation.
- If the focused control isn't a standard text-editing control (or doesn't
  expose `AXValue`/`AXSelectedTextRange`), both scripts fall back to the
  VoiceOver-cursor text, which may be a whole item rather than a single word
  or line.

Report back what you see when you try these (which app, which shortcut, what
it said vs. what you expected) and I can tune the caret/offset handling or
the word-boundary logic accordingly.
