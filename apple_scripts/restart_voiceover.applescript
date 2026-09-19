-- Restart VoiceOver
--
-- VoiceOver occasionally gets into an odd state that only turning it off and
-- on again fixes. Doing that by hand means toggling it off, guessing when
-- it has actually finished shutting down, then toggling it on. This does
-- the whole thing in one go.
--
-- launchctl kickstart would be the obvious way, but SIP blocks it for
-- VoiceOver's launch agent. Instead this asks the running VoiceOver to
-- terminate, waits until that process has actually gone, starts it again
-- through launchd (the same route as a normal VO on/off toggle) and waits
-- until the new process is actually running. Both waits poll for the real
-- state rather than sleeping for a guessed interval, so it takes only as
-- long as VoiceOver itself needs (about 1.5s in practice).
--
-- The work is handed to a detached shell rather than done inline, so it
-- still completes if whatever runs this script is torn down along with
-- VoiceOver. Each wait gives up after 10s (and says so in the log) rather
-- than waiting forever, so a stuck restart can't block later commands.
-- Note "running" means the process exists, not that it has started
-- speaking - there may be a brief moment before speech resumes.
--
-- Install: assign this script's .scpt to a VoiceOver Commander shortcut,
-- or pick it from speak_menu.

use scripting additions

-- Set to true to log restart progress to ~/Library/Logs/VoiceOverExtensions.log.
-- Off by default so nothing accumulates on disk. Recompile (see the Makefile)
-- after changing this.
property debugLogging : false

on run
	set logPath to (POSIX path of (path to library folder from user domain)) & "Logs/VoiceOverExtensions.log"
	if not debugLogging then set logPath to "/dev/null"

	set restartScript to "
log() { printf '%s | restart | %s\\n' \"$(date '+%Y-%m-%d %H:%M:%S')\" \"$1\" >> " & quoted form of logPath & "; }

log 'terminating VoiceOver'
pkill -TERM -x VoiceOver
i=0
while pgrep -x VoiceOver >/dev/null; do
	i=$((i + 1))
	if [ $i -gt 500 ]; then log 'FAILED: VoiceOver still running 10s after SIGTERM - leaving it alone'; exit 1; fi
	sleep 0.02
done
log 'VoiceOver exited'

open -b com.apple.VoiceOver
i=0
until pgrep -x VoiceOver >/dev/null; do
	i=$((i + 1))
	if [ $i -gt 500 ]; then log 'FAILED: VoiceOver not running 10s after open'; exit 1; fi
	sleep 0.02
done
log 'VoiceOver running again'
"

	try
		do shell script "nohup /bin/sh -c " & quoted form of restartScript & " >/dev/null 2>&1 &"
	on error errMsg
		try
			do shell script "printf '%s\\n' " & quoted form of ("restart | launching restart FAILED: " & errMsg) & " >> " & quoted form of logPath
		end try
	end try
end run
