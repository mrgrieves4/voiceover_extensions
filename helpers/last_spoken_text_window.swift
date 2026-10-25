// last_spoken_text_window
//
// Shows the text passed as its first argument in a small read-only window,
// for last_spoken_text.applescript. Built into helpers/LastSpokenText.app
// (see the Makefile) and launched with `open`, so it's a normal foreground
// app that properly becomes the active app when it opens.
//
// This replaces a `display dialog` hosted by System Events. System Events is
// a background-only process: "activate" on it returns without error, but it
// never actually becomes the frontmost app, so VoiceOver - which follows
// focus by tracking the active app - only sometimes noticed the dialog's
// text field had keyboard focus. In practice it missed it the first time
// after login and the first time after speak_menu's picker (also hosted by
// System Events), leaving arrow keys reading nothing until a VO-Right,
// VO-Left shuffle. A real app activating gives VoiceOver the usual
// app-activated/focus-changed notifications to follow.
//
// It also means:
// - The text is read-only, so Return and Escape can both close the window
//   (an editable dialog field swallowed Escape and Return was the only way).
// - The calling script doesn't wait for the window to close, so it no longer
//   holds up other Commander commands while it's open, and doesn't need to
//   give up after a timeout.
//
// The text starts fully selected, so Cmd-C copies it straight away. Return,
// Enter, Escape, Cmd-W, Cmd-Q or the Close button all close the window and
// hand focus back to whichever app was frontmost when this was launched.
// Launching another copy closes any copy that's still open, so stray windows
// don't pile up.
//
// Usage: open -n LastSpokenText.app --args <text>

import AppKit

// Seconds after the window opens before announcing the text (see
// applicationDidFinishLaunching). Raise it if the full preamble still
// sometimes gets read out before or after the text.
let announceDelay = 0.4

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    let text: String
    // Whichever app was frontmost at launch (i.e. what you were using when
    // you pressed the shortcut), to give focus back to on close. Not if that
    // was an older copy of this one, which is about to be closed - macOS then
    // picks the app behind on its own, which is normally the right one.
    let previousApp: NSRunningApplication?
    var window: NSWindow!

    init(text: String) {
        self.text = text
        let front = NSWorkspace.shared.frontmostApplication
        let isThisApp = front?.processIdentifier == getpid()
            || (front?.bundleIdentifier != nil && front?.bundleIdentifier == Bundle.main.bundleIdentifier)
        previousApp = isThisApp ? nil : front
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        closeOtherCopies()
        buildMenu()
        buildWindow()

        // Return/Enter/Escape close the window wherever focus is in it,
        // including on the Close button. Modified presses (e.g. Cmd-Return)
        // are left alone.
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            let modifiers = event.modifierFlags.intersection([.command, .option, .control, .shift])
            if modifiers.isEmpty, [36, 76, 53].contains(event.keyCode) { // Return, Enter, Escape
                self?.close()
                return nil
            }
            return event
        }

        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)

        // On opening, VoiceOver reads out the app name, the window title, the
        // text and "has keyboard focus" all in one go. Once it has started on
        // that, a high-priority announcement of just the text cuts it short,
        // so mostly only the text is heard. Too early and VoiceOver's own
        // focus speech would cut off the announcement instead.
        DispatchQueue.main.asyncAfter(deadline: .now() + announceDelay) { [weak self] in
            guard let self, !self.text.isEmpty else { return }
            NSAccessibility.post(
                element: NSApp as Any,
                notification: .announcementRequested,
                userInfo: [
                    .announcement: self.text,
                    .priority: NSAccessibilityPriorityLevel.high.rawValue,
                ])
        }
    }

    func windowWillClose(_ notification: Notification) {
        previousApp?.activate()
        NSApp.terminate(nil)
    }

    @objc func close() {
        window.close()
    }

    private func closeOtherCopies() {
        guard let bundleID = Bundle.main.bundleIdentifier else { return }
        for app in NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
        where app.processIdentifier != getpid() {
            app.terminate()
        }
    }

    // Without a main menu, Cmd-C/Cmd-A/Cmd-W/Cmd-Q do nothing in an app
    // like this, since those key equivalents are dispatched via the menu.
    private func buildMenu() {
        let mainMenu = NSMenu()
        func addSubmenu(_ title: String) -> NSMenu {
            let submenu = NSMenu(title: title)
            mainMenu.addItem(withTitle: title, action: nil, keyEquivalent: "").submenu = submenu
            return submenu
        }

        addSubmenu("Last Spoken Text")
            .addItem(withTitle: "Quit Last Spoken Text", action: #selector(close), keyEquivalent: "q")
            .target = self

        addSubmenu("File")
            .addItem(withTitle: "Close", action: #selector(close), keyEquivalent: "w")
            .target = self

        // No target: these go to the text view as first responder.
        let editMenu = addSubmenu("Edit")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")

        NSApp.mainMenu = mainMenu
    }

    private func buildWindow() {
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 240),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false)
        window.title = "Last Spoken Text"
        window.delegate = self
        window.isReleasedWhenClosed = false

        let content = window.contentView!

        let scrollView = NSTextView.scrollableTextView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.borderType = .bezelBorder
        let textView = scrollView.documentView as! NSTextView
        textView.string = text
        textView.isEditable = false
        textView.isSelectable = true
        textView.isRichText = false
        textView.font = NSFont.systemFont(ofSize: NSFont.systemFontSize + 2)
        textView.textContainerInset = NSSize(width: 4, height: 4)

        let button = NSButton(title: "Close", target: self, action: #selector(close))
        button.translatesAutoresizingMaskIntoConstraints = false
        button.bezelStyle = .rounded

        content.addSubview(scrollView)
        content.addSubview(button)
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: content.topAnchor, constant: 16),
            scrollView.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 16),
            scrollView.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -16),
            button.topAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: 12),
            button.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -16),
            button.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -16),
        ])

        window.center()
        window.initialFirstResponder = textView
        window.makeFirstResponder(textView)
        textView.selectAll(nil)
    }
}

let args = CommandLine.arguments
let text = args.count > 1 ? args[1] : ""

let app = NSApplication.shared
app.setActivationPolicy(.regular)
let delegate = AppDelegate(text: text)
app.delegate = delegate
app.run()
