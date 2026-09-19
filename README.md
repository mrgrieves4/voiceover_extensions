# VoiceOver Extensions

Apple Scripts to help overcome some of VoiceOver's little annoyances.
These can be assigned using VoiceOver Utility COmmands section.


1. **`speak_identifier_properly`** — VoiceOver spells long camelCase/PascalCase
   identifiers letter-by-letter instead of reading them as words (e.g.
   `oneTwoThreeFourFiveSixSevenEight` gets spelled out). This script will speak the text under the text or VO cursor properly. (Note: pressing VO+Shift+C afterwards will copy the text with spaces, not the original version)

2. **`speak_indentation_level`** — announces the leading whitespace of the
   current line (e.g. "4 spaces", "1 tab", "No indentation"). This is similar to the bilt-in VO function except it is triggered as and when rather than being a toggle. 

3. **`speak_inner_text`** — works around a VoiceOver bug where a heading (or
   other element) containing a child element gets announced as its child
   count (e.g. "2 items") instead of its actual text. Speaks the combined
   text of whatever the VoiceOver cursor is currently on instead. Can be used in conjunction with th normal navigate to heading.

4. **`speak_table_position`** — announces the row and column of the table
   cell currently in VoiceOver focus (e.g. "Row 3, Column 4"), for a
   one-off check without turning on VoiceOver's own automatic
   row/column announcement.

5. **`last_spoken_text`** — this pops up the last spoken text into a text box.
This is handy for the times VO struggles to pronounce something properly and saves having to copy/paste the text elsewhere.
Note: pressing enter on this dialog will close it.


6. **`speak_menu`** — shows a list of the other scripts and runs whichever
   one is chosen, so a single shortcut can cover any number of scripts
   instead of needing a separate shortcut per script. Useful if you have scripts you only use occasionally.
   Note: the last spoken text script is not listed here as it doesn't really make sense.



## Compiling

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
2. Go to the Commands category
3. Find Command set: Edit… and press VO+Space
4. Open Custom Commands and choose Run apple script
5. Choose a key shortcut. Note you may have to use the option key (aka keyboard commander) for this to work. 
6. Select the .scpt file you want to use.

Also there is a setting in VO Utility under General "Allow VoiceOver to be controlled with AppleScript" which may be enabled for some functions.

The last spoken text script needs an extra one-time permission**, beyond the Accessibility
grant the other scripts need: the first time it runs, macOS may prompt to
let the process running your Commander scripts control `Finder` - allow
it. If it instead just silently fails with no visible text box (check
`~/Library/Logs/VoiceOverExtensions.log` for `display dialog FAILED
(-1743)`), that permission was denied or never prompted; grant it manually
under **System Settings → Privacy & Security → Automation**, by finding
the entry for whatever process runs your Commander scripts and enabling
its `Finder` checkbox.

## Troubleshooting log

All the scripts except `speak_indentation_level` write one line per run to
`~/Library/Logs/VoiceOverExtensions.log`, recording relevant details - e.g.
which app/control was focused, the caret/selection values read, what was
decided to speak; for `speak_table_position`, the VoiceOver cursor's
on-screen bounds, the point it hit-tested, and the helper's raw output
(including the chain of roles walked and attribute names available, when it
couldn't resolve a row/column). Useful when behaviour looks wrong in a
specific app.
