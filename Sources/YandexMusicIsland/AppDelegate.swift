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

        // Request accessibility permissions so AXFullScreen detection works
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        let trusted = AXIsProcessTrustedWithOptions(options as CFDictionary)
        NSLog("[YMIsland] Accessibility trusted: \(trusted)")

        // Setup desktop tracker for permission-less fullscreen detection
        setupDesktopTracker()

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
                self.contentView.update(with: state)
                
                // Always keep the panel in the window list so it can be hovered.
                if !self.panel.isVisible {
                    self.panel.makeKeyAndOrderFront(nil)
                }
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
        // Check fullscreen state frequently
        fullscreenCheckTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.checkFullscreenState()
        }

        // Immediately react to space changes (entering/leaving fullscreen spaces)
        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(spaceDidChange),
            name: NSWorkspace.activeSpaceDidChangeNotification, object: nil
        )

        // KVO on presentationOptions — fires when system UI mode changes
        // (value 4 = fullscreen mode via setPresentationOptions)
        NSApp.addObserver(self, forKeyPath: "currentSystemPresentationOptions",
                          options: .new, context: nil)

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

    override func observeValue(forKeyPath keyPath: String?, of object: Any?,
                               change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == "currentSystemPresentationOptions" {
            DispatchQueue.main.async { [weak self] in
                self?.checkFullscreenState()
            }
        }
    }

    @objc private func spaceDidChange() {
        // Small delay to let the system update its state
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            self?.checkFullscreenState()
        }
    }

    private func checkFullscreenState() {
        let hideInFullscreen = UserDefaults.standard.value(forKey: "HideInFullscreen") as? Bool ?? true
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

    private var debugLogCounter = 0
    private var desktopTrackerWindow: NSWindow!
    
    private func setupDesktopTracker() {
        let rect = NSRect(x: 0, y: 0, width: 1, height: 1)
        desktopTrackerWindow = NSWindow(contentRect: rect, styleMask: .borderless, backing: .buffered, defer: false)
        desktopTrackerWindow.alphaValue = 0.0
        desktopTrackerWindow.isOpaque = false
        desktopTrackerWindow.ignoresMouseEvents = true
        // Crucial: Moves to all normal desktop spaces, but CANNOT join fullscreen spaces
        desktopTrackerWindow.collectionBehavior = [.moveToActiveSpace]
        desktopTrackerWindow.orderBack(nil)
    }

    private func detectFullscreen() -> Bool {
        var reasons: [String] = []
        
        // 1. Tracker Window Check (100% permission-free)
        // If the tracker window is NOT on the active space, it means the active space is a Fullscreen space.
        if !desktopTrackerWindow.isOnActiveSpace {
            reasons.append("TrackerWindowNotOnSpace")
        }
        
        // 2. Check WindowList for any window covering the panel's screen (fixes 'fake' fullscreen and some multi-monitor cases)
        if let windows = CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID),
           let panelScreen = panel?.screen ?? NSScreen.main {
            let screenFrame = panelScreen.frame
            
            for window in windows as NSArray {
                guard let winInfo = window as? NSDictionary else { continue }
                let ownerName = winInfo["kCGWindowOwnerName"] as? String ?? ""
                
                // Ignore background system processes, Notification Center, and ourselves
                if ownerName == "Dock" || ownerName == "Window Server" || ownerName == "YandexMusicIsland" || 
                   ownerName.contains("Notification Center") || ownerName.contains("Центр уведомлени") || ownerName == "Control Center" || ownerName == "Пункт управления" {
                    continue
                }
                
                // Ignore background layers (like Desktop wallpaper owned by Finder/Wallpaper)
                let layer = winInfo["kCGWindowLayer"] as? Int ?? 0
                if layer < 0 {
                    continue
                }
                
                if let boundsDict = winInfo["kCGWindowBounds"] as? NSDictionary,
                   let bounds = CGRect(dictionaryRepresentation: boundsDict) {
                    
                    // If a user window covers the entire screen, it's a fullscreen app
                    if bounds.width >= screenFrame.width - 1 && bounds.height >= screenFrame.height - 1 {
                        // Also check if it's on the same screen (by intersection)
                        if bounds.intersects(screenFrame) {
                            reasons.append("WindowCoversScreen(\(ownerName))")
                            break
                        }
                    }
                }
            }
        }
        
        // 3. Accessibility API (Primary, if permissions are granted)
        if let frontApp = NSWorkspace.shared.frontmostApplication {
            let pid = frontApp.processIdentifier
            let appElement = AXUIElementCreateApplication(pid)
            
            var focusedWindow: AnyObject?
            let result = AXUIElementCopyAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, &focusedWindow)
            
            if result == .success, let window = focusedWindow {
                let axWindow = window as! AXUIElement
                
                var fullscreenValue: AnyObject?
                let fsResult = AXUIElementCopyAttributeValue(axWindow, "AXFullScreen" as CFString, &fullscreenValue)
                
                if fsResult == .success, let isFS = fullscreenValue as? Bool, isFS {
                    reasons.append("AXFullScreen")
                }
            }
        }
        
        // If ANY method detects fullscreen, we trust it.
        let result = !reasons.isEmpty
        
        // Write debug log to file every ~2 seconds
        debugLogCounter += 1
        if debugLogCounter % 4 == 0 {
            let ts = ISO8601DateFormatter().string(from: Date())
            let frontAppName = NSWorkspace.shared.frontmostApplication?.localizedName ?? "?"
            let line = "\(ts) | fullscreen=\(result) | reasons=\(reasons) | frontApp=\(frontAppName) | hidden=\(isHiddenForFullscreen)\n"
            if let data = line.data(using: .utf8) {
                if FileManager.default.fileExists(atPath: "/tmp/ymisland_debug.log") {
                    if let fh = FileHandle(forWritingAtPath: "/tmp/ymisland_debug.log") {
                        fh.seekToEndOfFile()
                        fh.write(data)
                        fh.closeFile()
                    }
                } else {
                    FileManager.default.createFile(atPath: "/tmp/ymisland_debug.log", contents: data)
                }
            }
        }
        
        return result
    }

    private func handleMouseMoveForFullscreen() {
        let hideInFullscreen = UserDefaults.standard.value(forKey: "HideInFullscreen") as? Bool ?? true
        guard hideInFullscreen, isCurrentlyFullscreen else { return }

        guard let screen = NSScreen.main else { return }
        let mouseLocation = NSEvent.mouseLocation
        
        // Menu bar area: top ~36px of the screen (includes notch area)
        let menuBarThreshold: CGFloat = 36
        let isNearTop = mouseLocation.y >= (screen.frame.maxY - menuBarThreshold)
        
        // Also check if mouse is inside the panel's current frame
        let isInsidePanel = panel.frame.contains(mouseLocation)

        if isNearTop && isHiddenForFullscreen {
            showPanelForFullscreen(forcedCollapse: true)
        } else if !isNearTop && !isInsidePanel && !isHiddenForFullscreen && isCurrentlyFullscreen {
            hidePanelForFullscreen()
        }
    }

    private func hidePanelForFullscreen() {
        NSLog("[YMIsland] Hiding panel for fullscreen")
        isHiddenForFullscreen = true
        panel.ignoresMouseEvents = true
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.3
            panel.animator().alphaValue = 0.0
        }
    }

    private func showPanelForFullscreen(forcedCollapse: Bool = false) {
        guard !isUserHidden else { return }
        NSLog("[YMIsland] Showing panel from fullscreen")
        isHiddenForFullscreen = false
        panel.ignoresMouseEvents = false
        
        if forcedCollapse {
            panel.collapseAnimated()
            contentView.setExpanded(false, animated: false)
        }
        
        // Ensure it's in the correct position if resolution changed
        panel.repositionAtNotch()
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.3
            panel.animator().alphaValue = 1.0
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
        let isHideFS = UserDefaults.standard.value(forKey: "HideInFullscreen") as? Bool ?? true
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
        let currentState = UserDefaults.standard.value(forKey: "HideInFullscreen") as? Bool ?? true
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
        if !isUserHidden {
            // Hide
            isUserHidden = true
            panel.ignoresMouseEvents = true
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.3
                panel.animator().alphaValue = 0.0
            }
        } else {
            // Unhide
            isUserHidden = false
            if !isHiddenForFullscreen {
                panel.ignoresMouseEvents = false
                NSAnimationContext.runAnimationGroup { context in
                    context.duration = 0.3
                    panel.animator().alphaValue = 1.0
                }
            }
        }
    }

    @objc private func screenDidChange() {
        panel.repositionAtNotch()
    }
}
