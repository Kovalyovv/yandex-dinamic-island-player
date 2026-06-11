import AppKit
import QuartzCore

/// Dynamic Island Content View
class NotchContentView: NSView {

    // MARK: - Geometry info
    var menuBarHeight: CGFloat = 37
    var compactPillWidth: CGFloat {
        let saved = UserDefaults.standard.double(forKey: "CompactPillWidth")
        return saved > 0 ? CGFloat(saved) : 300
    }
    var notchWidth: CGFloat = 240
    var expandedPlayerWidth: CGFloat = 500

    static let expandedHeight: CGFloat = 150
    static let expandedWidth: CGFloat = 1400

    // MARK: - Background
    private let bgView: NSVisualEffectView = {
        let v = NSVisualEffectView()
        v.material = .hudWindow
        v.blendingMode = .behindWindow
        v.state = .active
        v.wantsLayer = true
        v.layer?.masksToBounds = true
        return v
    }()

    // MARK: - Containers
    private let maskContainer: NSView = {
        let v = NSView()
        v.wantsLayer = true
        v.layer?.masksToBounds = true
        return v
    }()

    private let compactContainer: NSView = {
        let v = NSView()
        v.wantsLayer = true
        return v
    }()

    private let expandedContainer: NSView = {
        let v = NSView()
        v.wantsLayer = true
        v.alphaValue = 0 // Hidden by default
        return v
    }()

    // MARK: - Compact Elements
    private let compactArtwork: NSImageView = {
        let v = NSImageView()
        v.wantsLayer = true
        v.layer?.cornerRadius = 4
        v.layer?.masksToBounds = true
        v.imageScaling = .scaleProportionallyUpOrDown
        return v
    }()

    private let compactMarquee: MarqueeLabel = {
        let m = MarqueeLabel(frame: .zero)
        m.font = NSFont.systemFont(ofSize: 12, weight: .regular)
        m.textColor = .white
        return m
    }()

    private let compactTiming: NSTextField = {
        let l = NSTextField(labelWithString: "0:00")
        l.font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        l.textColor = .white
        l.alignment = .right
        return l
    }()

    private let compactEq: EqualizerBarsView = {
        return EqualizerBarsView(frame: .zero)
    }()

    private let compactNextBtn: NSButton = {
        let b = NSButton(title: "", target: nil, action: nil)
        b.bezelStyle = .inline
        b.isBordered = false
        b.image = NSImage(systemSymbolName: "forward.fill", accessibilityDescription: "Next")?.withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 16, weight: .bold))
        b.contentTintColor = .white
        return b
    }()

    // MARK: - Expanded Elements
    private let expandedArtwork: NSImageView = {
        let v = NSImageView()
        v.wantsLayer = true
        v.layer?.cornerRadius = 12
        v.layer?.masksToBounds = true
        v.imageScaling = .scaleProportionallyUpOrDown
        return v
    }()

    private let expandedTitle: NSTextField = {
        let l = NSTextField(labelWithString: "")
        l.font = NSFont.systemFont(ofSize: 16, weight: .bold)
        l.textColor = .white
        l.alignment = .center
        l.lineBreakMode = .byTruncatingTail
        return l
    }()

    private let expandedArtist: NSTextField = {
        let l = NSTextField(labelWithString: "")
        l.font = NSFont.systemFont(ofSize: 13, weight: .regular)
        l.textColor = NSColor.white.withAlphaComponent(0.8)
        l.alignment = .center
        l.lineBreakMode = .byTruncatingTail
        return l
    }()

    private let expandedProgress: GradientProgressBar = {
        return GradientProgressBar(frame: .zero)
    }()

    private let expandedElapsed: NSTextField = {
        let l = NSTextField(labelWithString: "0:00")
        l.font = NSFont.monospacedDigitSystemFont(ofSize: 10, weight: .medium)
        l.textColor = .white
        l.alignment = .right
        return l
    }()

    private let expandedDuration: NSTextField = {
        let l = NSTextField(labelWithString: "0:00")
        l.font = NSFont.monospacedDigitSystemFont(ofSize: 10, weight: .medium)
        l.textColor = .white
        l.alignment = .left
        return l
    }()

    private let expandedPrev: NSButton = {
        let b = NSButton(title: "", target: nil, action: nil)
        b.bezelStyle = .inline
        b.isBordered = false
        b.image = NSImage(systemSymbolName: "backward.fill", accessibilityDescription: "Previous")?.withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 16, weight: .bold))
        b.contentTintColor = .white
        return b
    }()

    private let expandedPlayPause: NSButton = {
        let b = NSButton(title: "", target: nil, action: nil)
        b.bezelStyle = .inline
        b.isBordered = false
        b.image = NSImage(systemSymbolName: "pause.fill", accessibilityDescription: "Play")?.withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 22, weight: .bold))
        b.contentTintColor = .white
        return b
    }()

    private let expandedNext: NSButton = {
        let b = NSButton(title: "", target: nil, action: nil)
        b.bezelStyle = .inline
        b.isBordered = false
        b.image = NSImage(systemSymbolName: "forward.fill", accessibilityDescription: "Next")?.withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 16, weight: .bold))
        b.contentTintColor = .white
        return b
    }()

    private let expandedEq: EqualizerBarsView = {
        return EqualizerBarsView(frame: .zero)
    }()

    // MARK: - State
    private(set) var isExpanded: Bool = false
    private var mediaBridge: MediaControlBridge?
    private var progressTimer: Timer?
    private var collapseTimer: Timer?
    private var currentState: NowPlayingState?
    private var isAnimatingLayout: Bool = false

    var onToggleExpand: (() -> Void)?

    // MARK: - Init
    override init(frame: NSRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        wantsLayer = true
        layer?.masksToBounds = false

        addSubview(bgView)
        bgView.addSubview(maskContainer)
        maskContainer.addSubview(compactContainer)
        maskContainer.addSubview(expandedContainer)

        // Add compact elements
        compactContainer.addSubview(compactArtwork)
        compactContainer.addSubview(compactMarquee)
        compactContainer.addSubview(compactTiming)
        compactContainer.addSubview(compactEq)
        compactContainer.addSubview(compactNextBtn)

        // Add expanded elements
        expandedContainer.addSubview(expandedArtwork)
        expandedContainer.addSubview(expandedTitle)
        expandedContainer.addSubview(expandedArtist)
        expandedContainer.addSubview(expandedProgress)
        expandedContainer.addSubview(expandedElapsed)
        expandedContainer.addSubview(expandedDuration)

        expandedProgress.onSeek = { [weak self] percentage in
            guard let self = self, let state = self.currentState, state.duration > 0 else { return }
            let targetSeconds = state.duration * percentage
            
            // Optimistic instant update
            state.elapsedTime = targetSeconds
            state.timestamp = Date().timeIntervalSince1970
            self.updateProgress(state)
            
            self.mediaBridge?.sendCommand("seek", String(targetSeconds))
        }

        expandedContainer.addSubview(expandedPrev)
        expandedContainer.addSubview(expandedPlayPause)
        expandedContainer.addSubview(expandedNext)
        expandedContainer.addSubview(expandedEq)

        // Actions
        compactNextBtn.target = self
        compactNextBtn.action = #selector(nextTrack)
        
        expandedPrev.target = self
        expandedPrev.action = #selector(prevTrack)
        expandedPlayPause.target = self
        expandedPlayPause.action = #selector(togglePlayPause)
        expandedNext.target = self
        expandedNext.action = #selector(nextTrack)

        // Timer
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.updateProgressFromTimer()
        }

        // Initial layout
        performLayout(animated: false)
    }



    // MARK: - Layout Logic

    private func performLayout(animated: Bool) {
        let b = bounds
        let centerX = b.width / 2
        let topY = b.height - menuBarHeight
        
        let pillX = centerX - notchWidth / 2 - compactPillWidth
        let playerMaxX = centerX - notchWidth / 2
        let playerX = playerMaxX - expandedPlayerWidth

        let compactRect = NSRect(x: pillX, y: topY, width: compactPillWidth, height: menuBarHeight)
        let expandedRect = NSRect(x: playerX, y: 0, width: expandedPlayerWidth, height: b.height)

        // Update fixed layouts inside containers
        layoutCompactContainer(NSRect(x: 0, y: 0, width: compactPillWidth, height: menuBarHeight))
        layoutExpandedContainer(NSRect(x: 0, y: 0, width: expandedPlayerWidth, height: b.height))

        let targetBgRect = isExpanded ? expandedRect : compactRect
        let targetRadius: CGFloat = isExpanded ? 24 : 18

        currentTargetBgRect = targetBgRect
        updateHoverTrackingArea(rect: targetBgRect)

        let txCompact = compactRect.minX - targetBgRect.minX
        let tyCompact = compactRect.minY - targetBgRect.minY
        
        let txExpanded = expandedRect.minX - targetBgRect.minX
        let tyExpanded = expandedRect.minY - targetBgRect.minY

        let maskRect = NSRect(origin: .zero, size: targetBgRect.size)

        compactMarquee.isRunning = false
        
        // Keep their bounds/frames constant so text doesn't re-layout or snap
        compactContainer.frame = NSRect(origin: .zero, size: compactRect.size)
        expandedContainer.frame = NSRect(origin: .zero, size: expandedRect.size)

        if animated {
            isAnimatingLayout = true
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.25
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                context.allowsImplicitAnimation = true
                
                self.bgView.animator().frame = targetBgRect
                self.bgView.layer?.cornerRadius = targetRadius
                
                self.maskContainer.animator().frame = maskRect
                self.maskContainer.layer?.cornerRadius = targetRadius
                
                self.compactContainer.layer?.transform = CATransform3DMakeTranslation(txCompact, tyCompact, 0)
                self.expandedContainer.layer?.transform = CATransform3DMakeTranslation(txExpanded, tyExpanded, 0)
            }, completionHandler: {
                self.compactMarquee.isRunning = !self.isExpanded
                self.isAnimatingLayout = false
            })
            
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.15
                context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                context.allowsImplicitAnimation = true
                
                self.compactContainer.animator().alphaValue = self.isExpanded ? 0 : 1
                self.expandedContainer.animator().alphaValue = self.isExpanded ? 1 : 0
            })
        } else {
            bgView.frame = targetBgRect
            bgView.layer?.cornerRadius = targetRadius
            
            maskContainer.frame = maskRect
            maskContainer.layer?.cornerRadius = targetRadius
            
            compactContainer.layer?.transform = CATransform3DMakeTranslation(txCompact, tyCompact, 0)
            expandedContainer.layer?.transform = CATransform3DMakeTranslation(txExpanded, tyExpanded, 0)
            
            compactContainer.alphaValue = isExpanded ? 0 : 1
            expandedContainer.alphaValue = isExpanded ? 1 : 0
            
            compactMarquee.isRunning = !isExpanded
        }
    }

    private func layoutCompactContainer(_ bounds: NSRect) {
        let smallArtSize: CGFloat = 24
        compactArtwork.frame = NSRect(x: 12, y: (bounds.height - smallArtSize) / 2, width: smallArtSize, height: smallArtSize)

        let btnSize: CGFloat = 20
        let nextX = bounds.width - 12 - btnSize
        compactNextBtn.frame = NSRect(x: nextX, y: (bounds.height - btnSize) / 2, width: btnSize, height: btnSize)

        let eqW: CGFloat = 16
        let eqH: CGFloat = 14
        let eqX = nextX - 12 - eqW
        compactEq.frame = NSRect(x: eqX, y: (bounds.height - eqH) / 2, width: eqW, height: eqH)

        let timingW: CGFloat = 45
        let timingX = eqX - 12 - timingW
        compactTiming.frame = NSRect(x: timingX, y: (bounds.height - 16) / 2, width: timingW, height: 16)

        let marqueeX = 12 + smallArtSize + 8
        compactMarquee.frame = NSRect(x: marqueeX, y: 0, width: timingX - marqueeX - 8, height: bounds.height)
    }

    private func layoutExpandedContainer(_ bounds: NSRect) {
        let centerX = bounds.width / 2

        let artSize: CGFloat = 80
        expandedArtwork.frame = NSRect(x: 20, y: (bounds.height - artSize) / 2, width: artSize, height: artSize)

        let eqW: CGFloat = 24
        let eqH: CGFloat = 20
        expandedEq.frame = NSRect(x: bounds.width - 20 - eqW, y: (bounds.height - eqH) / 2, width: eqW, height: eqH)

        let textW: CGFloat = 240
        let topY = bounds.height - 35
        
        expandedTitle.frame = NSRect(x: centerX - textW/2, y: topY - 20, width: textW, height: 20)
        expandedArtist.frame = NSRect(x: centerX - textW/2, y: topY - 40, width: textW, height: 16)

        let progressY = topY - 60
        let progressW: CGFloat = 160
        expandedProgress.frame = NSRect(x: centerX - progressW/2, y: progressY - 8, width: progressW, height: 20)

        let timeW: CGFloat = 40
        expandedElapsed.frame = NSRect(x: centerX - progressW/2 - timeW - 8, y: progressY - 5, width: timeW, height: 14)
        expandedDuration.frame = NSRect(x: centerX + progressW/2 + 8, y: progressY - 5, width: timeW, height: 14)

        let controlsY = progressY - 30
        let btnSize: CGFloat = 24
        let playSize: CGFloat = 32
        let spacing: CGFloat = 30

        expandedPlayPause.frame = NSRect(x: centerX - playSize/2, y: controlsY - playSize/2 + 4, width: playSize, height: playSize)
        expandedPrev.frame = NSRect(x: centerX - spacing - playSize/2 - btnSize/2, y: controlsY - btnSize/2 + 4, width: btnSize, height: btnSize)
        expandedNext.frame = NSRect(x: centerX + spacing + playSize/2 - btnSize/2, y: controlsY - btnSize/2 + 4, width: btnSize, height: btnSize)
    }

    // MARK: - State Management
    func setExpanded(_ expanded: Bool, animated: Bool = true) {
        guard isExpanded != expanded else { return }
        isExpanded = expanded
        performLayout(animated: animated)
    }

    func setCompactWidth(_ w: CGFloat) {
        UserDefaults.standard.set(Double(w), forKey: "CompactPillWidth")
        performLayout(animated: true)
    }

    // MARK: - Hover Tracking

    private var hoverTrackingArea: NSTrackingArea?
    private var currentTargetBgRect: NSRect = .zero

    private func updateHoverTrackingArea(rect: NSRect) {
        if let ta = hoverTrackingArea {
            removeTrackingArea(ta)
        }
        let options: NSTrackingArea.Options = [.mouseEnteredAndExited, .activeAlways]
        let ta = NSTrackingArea(rect: rect, options: options, owner: self, userInfo: nil)
        addTrackingArea(ta)
        hoverTrackingArea = ta
    }

    var expandOnHover: Bool {
        return UserDefaults.standard.value(forKey: "ExpandOnHover") as? Bool ?? true
    }

    override func mouseEntered(with event: NSEvent) {
        if !expandOnHover { return }
        collapseTimer?.invalidate()
        
        if !isExpanded {
            if let window = self.window as? NotchPanel {
                window.expandAnimated()
            }
            setExpanded(true, animated: true)
        }
    }

    override func mouseExited(with event: NSEvent) {
        if !expandOnHover { return }
        let localPoint = convert(event.locationInWindow, from: nil)
        if currentTargetBgRect.contains(localPoint) { return }

        if isExpanded {
            collapseTimer?.invalidate()
            collapseTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { [weak self] _ in
                guard let self = self else { return }
                if self.isExpanded {
                    if let window = self.window as? NotchPanel {
                        window.collapseAnimated()
                    }
                    self.setExpanded(false, animated: true)
                }
            }
        }
    }

    func update(with state: NowPlayingState) {
        currentState = state

        expandedTitle.stringValue = state.title
        expandedArtist.stringValue = state.artist
        
        if !state.artist.isEmpty && !state.title.isEmpty {
            compactMarquee.text = "\(state.artist) — \(state.title)"
        } else {
            compactMarquee.text = state.title
        }
        
        let symbolName = state.isPlaying ? "pause.fill" : "play.fill"
        let img = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)?.withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 22, weight: .bold))
        expandedPlayPause.image = img
        
        compactEq.isAnimating = state.isPlaying
        expandedEq.isAnimating = state.isPlaying

        if let data = state.artworkData, let img = NSImage(data: data) {
            compactArtwork.image = img
            expandedArtwork.image = img
        } else {
            compactArtwork.image = nil
            expandedArtwork.image = nil
        }

        updateProgress(state)
    }

    private func updateProgress(_ state: NowPlayingState) {
        let elapsed = state.estimatedElapsedTime
        compactTiming.stringValue = NowPlayingState.formatTime(elapsed)
        
        if state.duration > 0 {
            expandedProgress.progress = CGFloat(elapsed / state.duration)
        } else {
            expandedProgress.progress = 0
        }
        expandedElapsed.stringValue = NowPlayingState.formatTime(elapsed)
        expandedDuration.stringValue = NowPlayingState.formatTime(state.duration)
    }

    private func updateProgressFromTimer() {
        guard !isAnimatingLayout else { return }
        guard let state = currentState else { return }
        updateProgress(state)
    }

    // MARK: - Actions
    func setMediaBridge(_ bridge: MediaControlBridge) {
        self.mediaBridge = bridge
    }

    @objc private func togglePlayPause() {
        mediaBridge?.sendCommand("toggle-play-pause")
    }

    @objc private func prevTrack() {
        mediaBridge?.sendCommand("previous-track")
    }

    @objc private func nextTrack() {
        mediaBridge?.sendCommand("next-track")
    }

    deinit {
        progressTimer?.invalidate()
    }
}

// MARK: - Gradient Progress Bar
class GradientProgressBar: NSView {
    var progress: CGFloat = 0 { didSet { needsDisplay = true } }
    var onSeek: ((Double) -> Void)?

    override func mouseDown(with event: NSEvent) {
        let localPoint = convert(event.locationInWindow, from: nil)
        let percentage = Double(localPoint.x / bounds.width)
        onSeek?(max(0, min(1, percentage)))
    }
    override init(frame: NSRect) { super.init(frame: frame) ; wantsLayer = true }
    required init?(coder: NSCoder) { super.init(coder: coder) ; wantsLayer = true }
    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }

        let barH: CGFloat = 4
        let barY = (bounds.height - barH) / 2
        let barRect = NSRect(x: 0, y: barY, width: bounds.width, height: barH)

        ctx.setFillColor(NSColor(white: 1.0, alpha: 0.2).cgColor)
        let bgPath = NSBezierPath(roundedRect: barRect, xRadius: barH / 2, yRadius: barH / 2)
        bgPath.fill()

        guard progress > 0 else { return }
        let fillW = bounds.width * min(progress, 1.0)
        let fillRect = NSRect(x: 0, y: barY, width: fillW, height: barH)
        let fillPath = NSBezierPath(roundedRect: fillRect, xRadius: barH / 2, yRadius: barH / 2)
        ctx.setFillColor(NSColor(white: 1.0, alpha: 0.8).cgColor)
        fillPath.fill()

        // Draw thumb (бегунок)
        let thumbDiameter: CGFloat = 10
        let thumbRadius = thumbDiameter / 2
        let thumbX = min(max(0, fillW - thumbRadius), bounds.width - thumbDiameter)
        let thumbRect = NSRect(x: thumbX, y: (bounds.height - thumbDiameter) / 2, width: thumbDiameter, height: thumbDiameter)
        
        ctx.setFillColor(NSColor.white.cgColor)
        let thumbPath = NSBezierPath(ovalIn: thumbRect)
        thumbPath.fill()
    }
}

// MARK: - Equalizer Bars Animation
class EqualizerBarsView: NSView {
    var isAnimating: Bool = false {
        didSet { if isAnimating != oldValue { isAnimating ? startAnimation() : stopAnimation() } }
    }
    private var barLayers: [CALayer] = []
    private let barCount = 4
    private let barSpacing: CGFloat = 3
    private let barWidth: CGFloat = 3
    override init(frame: NSRect) { super.init(frame: frame) ; wantsLayer = true ; setupBars() }
    required init?(coder: NSCoder) { super.init(coder: coder) ; wantsLayer = true ; setupBars() }
    private func setupBars() {
        barLayers.forEach { $0.removeFromSuperlayer() }
        barLayers.removeAll()
        for i in 0..<barCount {
            let bar = CALayer()
            bar.backgroundColor = NSColor(red: 0.1, green: 0.8, blue: 0.3, alpha: 1.0).cgColor
            bar.cornerRadius = 1.5
            let x = CGFloat(i) * (barWidth + barSpacing)
            bar.frame = CGRect(x: x, y: 0, width: barWidth, height: 4)
            bar.anchorPoint = CGPoint(x: 0.5, y: 0)
            bar.position = CGPoint(x: x + barWidth / 2, y: 0)
            layer?.addSublayer(bar)
            barLayers.append(bar)
        }
    }
    private func startAnimation() {
        for (i, bar) in barLayers.enumerated() {
            bar.removeAllAnimations()
            let anim = CABasicAnimation(keyPath: "bounds.size.height")
            anim.fromValue = 4
            anim.toValue = bounds.height * CGFloat.random(in: 0.6...1.0)
            anim.duration = 0.3 + Double(i) * 0.1
            anim.autoreverses = true
            anim.repeatCount = .infinity
            anim.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            bar.add(anim, forKey: "equalize")
        }
    }
    private func stopAnimation() {
        for bar in barLayers {
            bar.removeAllAnimations()
            bar.frame.size.height = 4
        }
    }
}
