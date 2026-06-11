import AppKit

/// Borderless panel for the widget
class NotchPanel: NSPanel {

    func setNotchContentView(_ cv: NotchContentView) {
        cv.frame = self.contentRect(forFrameRect: self.frame)
        cv.autoresizingMask = [.width, .height]
        self.contentView = cv
    }

    private var collapseTimer: Timer?
    private(set) var isExpanded: Bool = false

    init() {
        // ALWAYS keep the height at 140. This prevents macOS from hiding the window behind the notch!
        let w = NotchContentView.expandedWidth
        let h = NotchContentView.expandedHeight
        
        let screen = NSScreen.screens.first(where: { $0.safeAreaInsets.top > 0 }) ?? NSScreen.main ?? NSScreen.screens[0]
        let x = screen.frame.midX - w / 2.0
        let y = screen.frame.maxY - h
        
        let rect = NSRect(x: x, y: y, width: w, height: h)

        super.init(contentRect: rect,
                   styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered,
                   defer: false)

        isFloatingPanel = true
        level = .statusBar
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        
        backgroundColor = .clear
        isOpaque = false
        hasShadow = false
        hidesOnDeactivate = false
    }

    // MARK: - Animations
    // The panel frame no longer animates (it is permanently 140 tall to bypass notch clipping).
    // All animations happen inside NotchContentView.

    func expandAnimated() {
        isExpanded = true
        collapseTimer?.invalidate()
    }

    func collapseAnimated() {
        isExpanded = false
        collapseTimer?.invalidate()
    }

    func scheduleAutoCollapse(delay: TimeInterval = 4.0) {
        collapseTimer?.invalidate()
        collapseTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            self?.collapseAnimated()
            (self?.contentView as? NotchContentView)?.setExpanded(false, animated: true)
        }
    }

    func repositionAtNotch() {
        let screen = NSScreen.screens.first(where: { $0.safeAreaInsets.top > 0 }) ?? NSScreen.main ?? NSScreen.screens[0]

        let w = NotchContentView.expandedWidth
        let h: CGFloat = 150
        let x = screen.frame.midX - w / 2.0
        let y = screen.frame.maxY - h

        let newFrame = NSRect(x: x, y: y, width: w, height: h)
        setFrame(newFrame, display: true)
    }

    // MARK: - Event Handling

    override var canBecomeKey: Bool { return true }
    override var canBecomeMain: Bool { return false }

    override func mouseDown(with event: NSEvent) {
        if let cv = contentView as? NotchContentView {
            let locationInWindow = event.locationInWindow
            if let hitView = cv.hitTest(cv.convert(locationInWindow, from: nil)) {
                // Find if the hit view or any ancestor is an interactive element
                var target: NSView? = hitView
                while target != nil {
                    if target is InteractiveArtworkView || target is GradientProgressBar || target is NSButton {
                        target!.mouseDown(with: event)
                        return
                    }
                    target = target?.superview
                }
            }
            if cv.isExpanded {
                collapseAnimated()
                cv.setExpanded(false, animated: true)
            } else {
                expandAnimated()
                cv.setExpanded(true, animated: true)
            }
        }
    }

    override func rightMouseDown(with event: NSEvent) {
        if let appDelegate = NSApp.delegate as? AppDelegate {
            appDelegate.showContextMenu(at: event)
        }
    }

    // CRITICAL: Prevent macOS from constraining the window below the menu bar / notch
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
        return frameRect
    }
}
