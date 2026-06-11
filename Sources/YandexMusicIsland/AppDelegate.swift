import AppKit
import CoreGraphics

/// Application delegate
class AppDelegate: NSObject, NSApplicationDelegate {

    private var panel: NotchPanel!
    private var contentView: NotchContentView!
    private var mediaBridge: MediaControlBridge!
    private var globalEventMonitor: Any?

    // Fullscreen auto-hide
    private var fullscreenCheckTimer: Timer?
    private var mouseMoveMonitor: Any?
    private var isCurrentlyFullscreen: Bool = false
    private var isHiddenForFullscreen: Bool = false

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
        globalEventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown]) { [weak self] event in
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
                guard let self = self else { return }
                
                // Ensure it's visible if we hid it internally before (legacy support)
                if !self.panel.isVisible && !self.isUserHidden {
                    self.panel.makeKeyAndOrderFront(nil)
                }
                
                self.contentView.update(with: state)
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

        // Setup fullscreen detection
        setupFullscreenDetection()
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        mediaBridge.stop()
        fullscreenCheckTimer?.invalidate()
        if let monitor = mouseMoveMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }

    // MARK: - Fullscreen Detection

    private func setupFullscreenDetection() {
        // Check fullscreen state every second
        fullscreenCheckTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.checkFullscreenState()
        }

        // Monitor mouse movement globally to detect when cursor is near the top
        mouseMoveMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved]) { [weak self] event in
            self?.handleMouseMoveForFullscreen()
        }
        
        // Also monitor local mouse moves (when our panel is focused)
        NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved]) { [weak self] event in
            self?.handleMouseMoveForFullscreen()
            return event
        }
    }

    private func checkFullscreenState() {
        let hideInFullscreen = UserDefaults.standard.value(forKey: "HideInFullscreen") as? Bool ?? false
        guard hideInFullscreen else {
            if isHiddenForFullscreen {
                isHiddenForFullscreen = false
                isCurrentlyFullscreen = false
                showPanelForFullscreen()
            }
            return
        }

        let wasFullscreen = isCurrentlyFullscreen
        isCurrentlyFullscreen = detectFullscreen()

        if isCurrentlyFullscreen && !wasFullscreen {
            // Just entered fullscreen — hide the panel
            hidePanelForFullscreen()
        } else if !isCurrentlyFullscreen && wasFullscreen {
            // Just left fullscreen — show the panel
            showPanelForFullscreen()
        }
    }

    private func detectFullscreen() -> Bool {
        guard let screen = NSScreen.main else { return false }
        guard let windowList = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else { return false }

        let myPID = ProcessInfo.processInfo.processIdentifier

        for window in windowList {
            guard let boundsDict = window[kCGWindowBounds as String] as? [String: Any],
                  let layer = window[kCGWindowLayer as String] as? Int,
                  let ownerPID = window[kCGWindowOwnerPID as String] as? Int32 else { continue }

            // Skip our own windows and non-standard layers
            if ownerPID == myPID || layer != 0 { continue }

            let width = boundsDict["Width"] as? CGFloat ?? 0
            let height = boundsDict["Height"] as? CGFloat ?? 0

            if width >= screen.frame.width && height >= screen.frame.height {
                return true
            }
        }
        return false
    }

    private func handleMouseMoveForFullscreen() {
        let hideInFullscreen = UserDefaults.standard.value(forKey: "HideInFullscreen") as? Bool ?? false
        guard hideInFullscreen, isCurrentlyFullscreen else { return }

        guard let screen = NSScreen.main else { return }
        let mouseLocation = NSEvent.mouseLocation
        
        // Menu bar area: top ~36px of the screen (includes notch area)
        let menuBarThreshold: CGFloat = 36
        let isNearTop = mouseLocation.y >= (screen.frame.maxY - menuBarThreshold)

        if isNearTop && isHiddenForFullscreen {
            showPanelForFullscreen()
        } else if !isNearTop && !isHiddenForFullscreen && isCurrentlyFullscreen {
            hidePanelForFullscreen()
        }
    }

    private func hidePanelForFullscreen() {
        isHiddenForFullscreen = true
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.25
            self.panel.animator().alphaValue = 0.0
        }
    }

    private func showPanelForFullscreen() {
        isHiddenForFullscreen = false
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.2
            self.panel.animator().alphaValue = 1.0
        }
    }

    // MARK: - Status Bar Item

    private var statusItem: NSStatusItem!

    private var expandOnHoverMenuItem: NSMenuItem!
    private var hideInFullscreenMenuItem: NSMenuItem!

    private func buildContextMenu() -> NSMenu {
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Увеличить ширину (+)", action: #selector(increaseWidth), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Уменьшить ширину (-)", action: #selector(decreaseWidth), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        
        expandOnHoverMenuItem = NSMenuItem(title: "Раскрывать по наведению", action: #selector(toggleExpandOnHover), keyEquivalent: "")
        let isHover = UserDefaults.standard.value(forKey: "ExpandOnHover") as? Bool ?? true
        expandOnHoverMenuItem.state = isHover ? .on : .off
        menu.addItem(expandOnHoverMenuItem)

        hideInFullscreenMenuItem = NSMenuItem(title: "Скрывать в полноэкранном режиме", action: #selector(toggleHideInFullscreen), keyEquivalent: "")
        let isHideFS = UserDefaults.standard.value(forKey: "HideInFullscreen") as? Bool ?? false
        hideInFullscreenMenuItem.state = isHideFS ? .on : .off
        menu.addItem(hideInFullscreenMenuItem)
        
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Показать/Скрыть", action: #selector(toggleVisibility), keyEquivalent: "h"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Выход", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        return menu
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "music.note", accessibilityDescription: "Yandex Music Island")
        }
        statusItem.menu = buildContextMenu()
    }

    /// Called by NotchContentView/NotchPanel on right-click
    func showContextMenu(at event: NSEvent) {
        let menu = buildContextMenu()
        NSMenu.popUpContextMenu(menu, with: event, for: contentView)
    }

    @objc private func toggleExpandOnHover() {
        let currentState = UserDefaults.standard.value(forKey: "ExpandOnHover") as? Bool ?? true
        let newState = !currentState
        UserDefaults.standard.set(newState, forKey: "ExpandOnHover")
        expandOnHoverMenuItem.state = newState ? .on : .off
    }

    @objc private func toggleHideInFullscreen() {
        let currentState = UserDefaults.standard.value(forKey: "HideInFullscreen") as? Bool ?? false
        let newState = !currentState
        UserDefaults.standard.set(newState, forKey: "HideInFullscreen")
        hideInFullscreenMenuItem.state = newState ? .on : .off
        
        // If disabling, immediately show the panel
        if !newState && isHiddenForFullscreen {
            showPanelForFullscreen()
            isCurrentlyFullscreen = false
        }
    }

    @objc private func increaseWidth() {
        let newWidth = min(contentView.compactPillWidth + 20, 800)
        contentView.setCompactWidth(newWidth)
    }

    @objc private func decreaseWidth() {
        let newWidth = max(contentView.compactPillWidth - 20, 100)
        contentView.setCompactWidth(newWidth)
    }

    private var isUserHidden: Bool = false

    @objc private func toggleVisibility() {
        if panel.isVisible {
            isUserHidden = true
            panel.orderOut(nil)
        } else {
            isUserHidden = false
            panel.makeKeyAndOrderFront(nil)
        }
    }

    @objc private func screenDidChange() {
        panel.repositionAtNotch()
    }
}
