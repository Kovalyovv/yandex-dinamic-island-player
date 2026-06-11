import AppKit

// Entry point — create NSApplication, set delegate, run
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
