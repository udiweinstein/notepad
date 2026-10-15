import AppKit

// Entry point – no storyboard / nib, everything is built in code.
let app = NSApplication.shared
let appDelegate = AppDelegate()
app.delegate = appDelegate
app.setActivationPolicy(.regular)
app.run()
