# VoiceOver Extensions

AppleScripts for VoiceOver's "Commander" feature (custom keyboard shortcuts
assigned in VoiceOver Utility), addressing everyday annoyances:

1. **`speak_identifier_properly`** — VoiceOver spells long camelCase/PascalCase
   identifiers letter-by-letter instead of reading them as words (e.g.
   `oneTwoThreeFourFiveSixSevenEight` gets spelled out). This script picks
   text at the cursor, inserts spaces at the case boundaries, and has
   VoiceOver speak the result — e.g. "one Two Three Four Five Six Seven
   Eight" instead of individual letters.

2. **`speak_indentation_level`** — announces the leading whitespace of the
   current line (e.g. "4 spaces", "1 tab", "No indentation"), no matter where
   on the line the text cursor actually is.

3. **`speak_inner_text`** — works around a VoiceOver bug where a heading (or
   other element) containing a child element gets announced as its child
   count (e.g. "2 items") instead of its actual text. Speaks the combined
   text of whatever the VoiceOver cursor is currently on instead.

4. **`speak_table_position`** — announces the row and column of the table
   cell currently in VoiceOver focus (e.g. "Row 3, Column 4"), for a
   one-off check without turning on VoiceOver's own automatic
   row/column announcement.

5. **`speak_menu`** — shows a list of the other scripts and runs whichever
   one is chosen, so a single shortcut can cover any number of scripts
   instead of needing a separate shortcut per script.

## How they find the text

`speak_identifier_properly` and `speak_indentation_level` use the
Accessibility API (via `System Events`) to read the focused control's full
text and the actual text-insertion caret position, when the focus is a text
control.

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

`speak_inner_text` and `speak_table_position` always use the VoiceOver
cursor directly rather than the text-insertion caret, since they're meant
for general VO navigation (headings, table cells, etc), not text editing.
`speak_table_position` reads the `AXRowIndexRange`/`AXColumnIndexRange`
Accessibility attributes of the focused element; if a particular table
doesn't expose those, it logs every attribute name available on the element
instead, to help figure out the right ones for that case.

## Files

Each script has a `.applescript` source file and a compiled `.scpt` file
(use the `.scpt` one in VoiceOver Utility) under `apple_scripts/`:
`speak_identifier_properly`, `speak_indentation_level`, `speak_inner_text`,
`speak_table_position`, `speak_menu`.

To recompile after editing a `.applescript` source file:

```bash
cd apple_scripts
osacompile -o speak_identifier_properly.scpt speak_identifier_properly.applescript
osacompile -o speak_indentation_level.scpt speak_indentation_level.applescript
osacompile -o speak_inner_text.scpt speak_inner_text.applescript
osacompile -o speak_table_position.scpt speak_table_position.applescript
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

`speak_menu` shows its picker via `tell application "System Events" to choose
from list ...` rather than a plain `choose from list`. A dialog shown
directly by the script's own process has nowhere to render under VoiceOver
Commander (Commander doesn't run scripts as a normal foreground GUI
process), and hangs instead of erroring — which then blocks Commander from
dispatching any further shortcuts until a reboot. Routing the dialog through
System Events, an always-running GUI-capable process, avoids that.

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

All the scripts except `speak_indentation_level` write one line per run to
`~/Library/Logs/VoiceOverExtensions.log`, recording relevant details (e.g.
which app/control was focused, the caret/selection values read, what was
decided to speak, or - for `speak_table_position` - the full attribute list
when row/column can't be determined). Useful when behaviour looks wrong in
a specific app.
