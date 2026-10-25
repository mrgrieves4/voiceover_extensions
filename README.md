last
## VoiceOver Extensions

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
   text of whatever the VoiceOver cursor is currently on instead. Can be used in conjunction with the normal navigate to heading.

4. **`speak_table_position`** — announces the row and column of the table
   cell currently in VoiceOver focus (e.g. "Row 3, Column 4"), for a
   one-off check without turning on VoiceOver's own automatic
   row/column announcement.

5. **`speak_row_header`** — speaks the header of the row the VoiceOver
   cursor is in. If the row has no proper header, it speaks the first cell
   in the row instead, or the second cell if the first has no text (e.g. a
   tickbox). Handy in wide tables where VoiceOver doesn't announce what
   row you're on.

6. **`speak_column_header`** — speaks the header of the column the
   VoiceOver cursor is in, including the non-interactive header row many
   Mac app tables have. If there's no header, it speaks the top cell in the
   column instead.
   
   This is useful if a table has not been marked up properly or you don't wish to turn on the constant announcement as you move around.

7. **`last_spoken_text_window_text`** — this pops up the last spoken text into a text box.
This is handy if you just can't figure out what VoiceOver is saying and VO+W or interacting with the text letter by letter isn't an option.
Saves having to copy/paste the text elsewhere.

8. **`speak_menu`** — shows a list of the other scripts and runs whichever
   one is chosen, so a single shortcut can cover any number of scripts
   instead of needing a separate shortcut per script. Useful if you have scripts you only use occasionally.
   Note: the last spoken text script is not listed here as it doesn't really make sense.

9. **`restart_voiceover`** — restarts VoiceOver in one go, for the times it
   gets into an odd state and needs turning off and on again. Marginally quicker than Cmd+F5 twice.


## Compiling

To recompile after editing a `.applescript` source file:

```bash
make
```

This only rebuilds the scripts whose source has changed.

To rebuild the Swift helpers after editing `ax_table_position.swift` or
`last_spoken_text_window.swift`:

```bash
make helper
```

`last_spoken_text_window.swift` builds `helpers/LastSpokenText.app`, the
window the last spoken text script opens.

The `ax_table_position` helper is shared by `speak_table_position`, `speak_row_header` and
`speak_column_header`. If they never find anything (always
"Could not determine table position" / "Could not find a row/column header" with
no log entries at all, rather than an "UNRESOLVED" entry), the helper binary itself may need to be granted access under
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


## Troubleshooting log

Logging is off by default so nothing builds up on disk (the log can contain
text you had selected or focused, and nothing ever trims it). To turn it on,
set `property debugLogging : false` to `true` near the top of the script you
want to investigate, then run `make` to recompile it.

With it on, all the scripts except `speak_indentation_level` write one line
per event to `~/Library/Logs/VoiceOverExtensions.log`, recording relevant
details - e.g. which app/control was focused, the caret/selection values
read, what was decided to speak; for `speak_table_position`, the VoiceOver
cursor's on-screen bounds, the point it hit-tested, and the helper's raw
output (including the chain of roles walked and attribute names available,
when it couldn't resolve a row/column). Useful when behaviour looks wrong in
a specific app. Set it back to `false` (and delete the log file) when done.


# Known Issues

If you open the menu and then switch away from it without closing it,
then you can block other Apple scripts from running with VoiceOver for a time. (This is why the menu gives up after 20 seconds).

If you run into this, you can use VO+F1, F1 to find the menu, and then close it properly.

The compiled Swift code only works for Apple Silicon - Intel Mac users will have to recompile.