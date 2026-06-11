import AppKit

/// Application delegate
class AppDelegate: NSObject, NSApplicationDelegate {

    private var panel: NotchPanel!
    private var contentView: NotchContentView!
    private var mediaBridge: MediaControlBridge!
    private var globalEventMonitor: Any?

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        // Setup status bar item for toggling
        setupStatusItem()

        // Create the borderless panel
        panel = NotchPanel()

        // Create content view
        let cv = NotchContentView(frame: NSRect(
            x: 0, y: 0,
            width: NotchContentView.expandedWidth,
            height: NotchContentView.expandedHeight
        ))

        self.contentView = cv
        panel.setNotchContentView(cv)

        // Show the panel
        panel.makeKeyAndOrderFront(nil)
        panel.repositionAtNotch()

        // Setup global click outside to dismiss
        globalEventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self = self else { return }
            if self.panel.isExpanded {
                self.panel.collapseAnimated()
                self.contentView.setExpanded(false, animated: true)
            }
        }

        // Setup Media Bridge
        mediaBridge = MediaControlBridge()
        mediaBridge.onUpdate = { [weak self] state in
            DispatchQueue.main.async {
                self?.contentView.update(with: state)
            }
        }
        
        contentView.setMediaBridge(mediaBridge)

        // Start media stream
        mediaBridge.start()

        // Initially compact state
        panel.collapseAnimated()
        contentView.setExpanded(false, animated: false)

        // Listen for screen changes to reposition
        NotificationCenter.default.addObserver(self, selector: #selector(screenDidChange), name: NSApplication.didChangeScreenParametersNotification, object: nil)
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        mediaBridge.stop()
    }

    // MARK: - Status Bar Item

    private var statusItem: NSStatusItem!

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "music.note", accessibilityDescription: "Yandex Music Island")
        }

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Показать/Скрыть", action: #selector(toggleVisibility), keyEquivalent: "h"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Выход", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        statusItem.menu = menu
    }

    @objc private func toggleVisibility() {
        if panel.isVisible {
            panel.orderOut(nil)
        } else {
            panel.makeKeyAndOrderFront(nil)
        }
    }

    @objc private func screenDidChange() {
        panel.repositionAtNotch()
    }
}
