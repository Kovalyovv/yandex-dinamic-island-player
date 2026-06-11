import AppKit
import QuartzCore

/// Scrolling text label — scrolls right-to-left if text doesn't fit.
class MarqueeLabel: NSView {

    var text: String = "" {
        didSet {
            if text != oldValue {
                scrollOffset = 0
                isPaused = true
                pauseCountdown = initialPause
                needsDisplay = true
            }
        }
    }

    var font: NSFont = .systemFont(ofSize: 12, weight: .medium)
    var textColor: NSColor = .white

    private var scrollOffset: CGFloat = 0
    private var textWidth: CGFloat = 0
    private var timer: Timer?
    private let scrollSpeed: CGFloat = 0.6  // points per tick
    private let gap: CGFloat = 50           // gap between repeats
    private let initialPause: Int = 90      // ticks to pause at start (~3s at 30fps)
    private let loopPause: Int = 60         // ticks to pause after loop (~2s)
    private var isPaused: Bool = true
    private var pauseCountdown: Int = 90

    override init(frame: NSRect) {
        super.init(frame: frame)
        startTimer()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        startTimer()
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }

    var isRunning: Bool = true
    
    private func tick() {
        guard isRunning else { return }
        
        // Calculate text width
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: textColor]
        textWidth = (text as NSString).size(withAttributes: attrs).width

        // No need to scroll if text fits
        guard textWidth > bounds.width else {
            scrollOffset = 0
            return
        }

        if isPaused {
            pauseCountdown -= 1
            if pauseCountdown <= 0 {
                isPaused = false
            }
            return
        }

        scrollOffset += scrollSpeed
        let totalCycle = textWidth + gap
        if scrollOffset >= totalCycle {
            scrollOffset = 0
            isPaused = true
            pauseCountdown = loopPause
        }

        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        guard !text.isEmpty else { return }

        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: textColor
        ]
        let size = (text as NSString).size(withAttributes: attrs)
        textWidth = size.width
        let textY = (bounds.height - size.height) / 2

        NSGraphicsContext.current?.saveGraphicsState()
        NSBezierPath(rect: bounds).setClip()

        if textWidth <= bounds.width {
            // Static — draw left-aligned
            (text as NSString).draw(at: NSPoint(x: 0, y: textY), withAttributes: attrs)
        } else {
            // Scrolling — draw text twice for seamless loop
            let x1 = -scrollOffset
            let x2 = x1 + textWidth + gap

            (text as NSString).draw(at: NSPoint(x: x1, y: textY), withAttributes: attrs)
            (text as NSString).draw(at: NSPoint(x: x2, y: textY), withAttributes: attrs)
        }

        NSGraphicsContext.current?.restoreGraphicsState()
    }

    deinit {
        timer?.invalidate()
    }
}
