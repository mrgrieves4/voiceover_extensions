# VoiceOver Extensions

Two AppleScripts for VoiceOver's "Commander" feature (custom keyboard shortcuts
assigned in VoiceOver Utility), addressing two everyday annoyances:

1. **`speak_identifier_properly`** — VoiceOver spells long camelCase/PascalCase
   identifiers letter-by-letter instead of reading them as words (e.g.
   `oneTwoThreeFourFiveSixSevenEight` gets spelled out). This script picks
   text at the cursor, inserts spaces at the case boundaries, and has
   VoiceOver speak the result — e.g. "one Two Three Four Five Six Seven
   Eight" instead of individual letters.

2. **`speak_indentation_level`** — announces the leading whitespace of the
   current line (e.g. "4 spaces", "1 tab", "No indentation"), no matter where
   on the line the text cursor actually is.

3. **`speak_menu`** — shows a list of the other scripts and runs whichever
   one is chosen, so a single shortcut can cover any number of scripts
   instead of needing a separate shortcut per script.

## How they find the text

Both scripts use the Accessibility API (via `System Events`) to read the
focused control's full text and the actual text-insertion caret position,
when the focus is a text control.

`speak_identifier_properly` picks what to speak, in this order:

1. If there's a selection confined to a single line, speaks the selection.
   A selection spanning multiple lines is ignored (treated as no selection)
   — VoiceOver leaves a selection behind in a text control as it navigates,
   to mark what it's reading, and that can span an arbitrary multi-line
   range unrelated to what the user wants read. A deliberate user selection
   is normally on one line, so this keeps the selection behaviour useful
   while ignoring VoiceOver's own navigation artifacts.
2. If the caret is touching a word (inside it, or immediately before or
   after it), speaks that word.
3. Otherwise (caret on whitespace/punctuation not touching any word),
   speaks the whole current line.

`speak_indentation_level` always looks at the whole current line, regardless
of caret position within it.

If the focus isn't a text control at all (or the Accessibility call fails —
e.g. some older macOS versions can't read `AXSelectedTextRange` via
AppleScript), both scripts fall back to whatever text the VoiceOver cursor
(`vo cursor`) is currently on.

## Files

- `apple_scripts/speak_identifier_properly.applescript` — source
- `apple_scripts/speak_identifier_properly.scpt` — compiled (use this one in VoiceOver Utility)
- `apple_scripts/speak_indentation_level.applescript` — source
- `apple_scripts/speak_indentation_level.scpt` — compiled (use this one in VoiceOver Utility)
- `apple_scripts/speak_menu.applescript` — source
- `apple_scripts/speak_menu.scpt` — compiled (use this one in VoiceOver Utility)

To recompile after editing a `.applescript` source file:

```bash
cd apple_scripts
osacompile -o speak_identifier_properly.scpt speak_identifier_properly.applescript
osacompile -o speak_indentation_level.scpt speak_indentation_level.applescript
osacompile -o speak_menu.scpt speak_menu.applescript
```

## Installing as VoiceOver shortcuts

1. Open **VoiceOver Utility** (VO-F8 while VoiceOver is running, or launch it directly).
2. Go to **Commanders → Keyboard Commander** (the trackpad commander also works for trackpad gestures).
3. Click **+** to add a new command.
4. Set **Type** to a keyboard shortcut (e.g. VO-Shift-I for "identifier", VO-Shift-L for "indent level").
5. Set the command's action to run a script, and browse to the `.scpt` file (`speak_identifier_properly.scpt` / `speak_indentation_level.scpt`).
6. Save.

Alternatively, assign a single shortcut to `speak_menu.scpt` and pick a
script from the list each time (arrow keys to move, type a letter to jump
to an item starting with it, Return to run it, Escape to cancel) — useful
once there are more scripts than shortcuts you want to remember.
`speak_menu.applescript` hardcodes the path to the `apple_scripts` folder in
its `scriptsFolder` property; update that if the repo moves. To add another
script to the menu, add one `{label:..., scriptFile:...}` record to its
`menuActions` list.

## Known limitations

- The camelCase splitter treats letters/digits/underscore as "word"
  characters; it won't do anything useful to non-identifier text.
- Indentation detection assumes plain spaces/tabs; it doesn't understand
  editor-specific soft-wrap or virtual indentation.
- If the focused control isn't a standard text-editing control (or doesn't
  expose `AXValue`/`AXSelectedTextRange`), both scripts fall back to the
  VoiceOver-cursor text, which may be a whole item rather than a single word
  or line.
- If a script appears to do nothing when triggered, check
  **System Settings → Privacy & Security → Accessibility** for the process
  running the script.

## Troubleshooting log

`speak_identifier_properly` writes one line per run to
`~/Library/Logs/VoiceOverExtensions.log`, recording which app/control was
focused, the caret/selection values it read, and what it decided to speak.
Useful when behaviour looks wrong in a specific app.
