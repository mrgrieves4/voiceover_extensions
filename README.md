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

5. **`last_spoken_text`** — for when VoiceOver says something too fast/
   garbled to catch, and neither VO-W (spell word) nor VO-Shift-Left/Right
   (move by character) work on the control it was reading (e.g. PyCharm's
   project tree). Grabs the text of the last thing VoiceOver spoke and
   shows it in an editable field (pre-selected, so Cmd-C copies it
   immediately) so it can be read with those same shortcuts - which work
   here regardless of the original control, because the field is a normal,
   fully-accessible Cocoa text field. Return (or VO-Space on the Close
   button) dismisses it and hands focus straight back to whatever was
   active before - Escape doesn't work here (see "How `last_spoken_text`
   works" below for why). That section also explains why it needs its own
   direct shortcut instead of going through `speak_menu`.

6. **`speak_menu`** — shows a list of the other scripts and runs whichever
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
cursor directly rather than the text-insertion caret or `System Events`'
real keyboard focus, since they're meant for general VO navigation
(headings, table cells, etc): tables/outlines/headings are normally browsed
with VoiceOver's own virtual cursor without moving real keyboard focus at
all, so `AXFocusedUIElement` doesn't reliably track what VoiceOver is
actually looking at.

`speak_table_position` hit-tests the accessibility tree directly at the
VoiceOver cursor's on-screen position, then walks up from whatever's there
looking for `AXRowIndexRange`/`AXColumnIndexRange`. That hit-testing and
attribute extraction is done by a small compiled helper,
`helpers/ax_table_position` (source: `helpers/ax_table_position.swift`),
rather than in AppleScript directly - AppleScriptObjC can't reliably pass a
raw `AXUIElementRef` between two Accessibility API calls, or unpack the
`CFRange` struct that a row/column range attribute returns, but both are
straightforward in Swift. The AppleScript just shells out to it and parses
its output. If it can't find a row/column range after 8 parent hops, it
logs the chain of roles it walked through and the attribute names available
on the element it hit, to help pin down the right approach for that case.

## How `last_spoken_text` works

Rather than reading any control's text at all, `last_spoken_text` asks
VoiceOver itself for the text of the last phrase it spoke, via the
`last phrase` object in VoiceOver's own AppleScript dictionary (`tell
application "VoiceOver" to get content of last phrase`) - the same
dictionary `speak_inner_text` already uses for `vo cursor`. This is what
makes it work in places the other scripts can't reach: it doesn't matter
whether the control exposes `AXValue`, `AXSelectedTextRange`, or anything
else via the Accessibility API (PyCharm's project tree exposes none of
these - `speak_identifier_properly` and `speak_inner_text` both fail there),
because nothing about the control is ever inspected. If VoiceOver spoke it,
this can retrieve it.

**This script must be bound to its own direct Commander shortcut - never
added to `speak_menu`.** Picking it from that menu means arrowing through a
list first, and VoiceOver announcing each menu item as you arrow to it
overwrites its "last phrase" before `last_spoken_text` ever runs - so it
would show you the menu item's own text instead of whatever you actually
wanted captured. Run directly from its own shortcut, it captures `last
phrase` as the very first thing it does, before anything else has a chance
to make VoiceOver speak again.

The dialog is routed through `Finder` rather than `System Events` (which is
what `speak_menu`'s picker uses - see below). `System Events` is a
background agent app that macOS never actually brings to the real
foreground: `activate` on it returns without error, but it never becomes
truly key, so real key presses keep going to whatever app was genuinely
frontmost before, not to its dialog. VoiceOver's own VO-Space-on-a-button
still worked through that, because it presses buttons via the
accessibility API directly rather than a real key/click event. `Finder` is
a normal foreground-capable app that's always running, so it actually gets
real keyboard focus - confirmed by Return closing the dialog correctly.

**Escape doesn't dismiss the dialog, even though the button is set as its
`cancel button`** (which the `display dialog` documentation says should
bind Escape to it) - Return works, but Escape appears to be consumed by the
editable text field itself (a known Cocoa quirk: a field editor's own key
binding for Escape can swallow it before it bubbles up to the panel's
cancel-button handling) rather than passed up to the dialog. This isn't
fixable without replacing `display dialog` with a hand-built panel via
AppleScriptObjC, which is a lot of extra complexity for a "press Escape
instead of Return" difference - use Return (or VO-Space on Close) instead.

Because it's a dialog owned by `Finder` rather than a window of your actual
app, dismissing it doesn't return keyboard focus to whatever you were using
on its own - so the script records the frontmost process before showing
the dialog and reactivates it afterwards.

**This needs one extra one-time permission**, beyond the Accessibility
grant the other scripts need: the first time it runs, macOS may prompt to
let the process running your Commander scripts control `Finder` - allow
it. If it instead just silently fails with no visible text box (check
`~/Library/Logs/VoiceOverExtensions.log` for `display dialog FAILED
(-1743)`), that permission was denied or never prompted; grant it manually
under **System Settings → Privacy & Security → Automation**, by finding
the entry for whatever process runs your Commander scripts and enabling
its `Finder` checkbox.

## Files

Each script has a `.applescript` source file and a compiled `.scpt` file
(use the `.scpt` one in VoiceOver Utility) under `apple_scripts/`:
`speak_identifier_properly`, `speak_indentation_level`, `speak_inner_text`,
`speak_table_position`, `last_spoken_text`, `speak_menu`.

`helpers/ax_table_position.swift` is the compiled helper `speak_table_position`
shells out to; the compiled binary (`helpers/ax_table_position`) is checked
in too.

To recompile after editing a `.applescript` source file:

```bash
cd apple_scripts
osacompile -o speak_identifier_properly.scpt speak_identifier_properly.applescript
osacompile -o speak_indentation_level.scpt speak_indentation_level.applescript
osacompile -o speak_inner_text.scpt speak_inner_text.applescript
osacompile -o speak_table_position.scpt speak_table_position.applescript
osacompile -o last_spoken_text.scpt last_spoken_text.applescript
osacompile -o speak_menu.scpt speak_menu.applescript
```

To rebuild the helper after editing `ax_table_position.swift`:

```bash
cd helpers
swiftc ax_table_position.swift -o ax_table_position
```

If `speak_table_position` never finds anything (always "Could not determine
table position" with no log entries at all, rather than an "UNRESOLVED"
entry), the helper binary itself may need to be granted access under
**System Settings → Privacy & Security → Accessibility** — it calls the
Accessibility API directly rather than going through `System Events`, so it
needs its own permission entry, added via the **+** button and browsing to
`helpers/ax_table_position`.

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
- `last_spoken_text` needs a one-time Automation permission grant to
  control `Finder` (see "How `last_spoken_text` works" above); until
  that's granted, it fails silently instead of showing its text box.
- If a script appears to do nothing when triggered, check
  **System Settings → Privacy & Security → Accessibility** for the process
  running the script.

## Troubleshooting log

All the scripts except `speak_indentation_level` write one line per run to
`~/Library/Logs/VoiceOverExtensions.log`, recording relevant details - e.g.
which app/control was focused, the caret/selection values read, what was
decided to speak; for `speak_table_position`, the VoiceOver cursor's
on-screen bounds, the point it hit-tested, and the helper's raw output
(including the chain of roles walked and attribute names available, when it
couldn't resolve a row/column). Useful when behaviour looks wrong in a
specific app.
