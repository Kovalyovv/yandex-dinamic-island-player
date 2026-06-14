import AppKit
import QuartzCore

/// Dynamic Island Content View
class NotchContentView: NSView {

    // MARK: - Geometry info
    var menuBarHeight: CGFloat = 37
    var compactPillWidth: CGFloat {
        if currentState?.hasTrack == false {
            return 50 // just for a small music icon
        }
        let saved = UserDefaults.standard.double(forKey: "CompactPillWidth")
        return saved > 0 ? CGFloat(saved) : 300
    }
    var notchWidth: CGFloat = 240
    var expandedPlayerWidth: CGFloat = 440

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
    
    private let bgTintView: NSView = {
        let v = NSView()
        v.wantsLayer = true
        v.layer?.backgroundColor = NSColor.clear.cgColor
        v.autoresizingMask = [.width, .height]
        return v
    }()
    
    private var lastArtworkData: Data?

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
    private let expandedArtwork: InteractiveArtworkView = {
        let v = InteractiveArtworkView()
        v.wantsLayer = true
        v.layer?.cornerRadius = 12
        v.layer?.masksToBounds = true
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

    private let returnButton: NSButton = {
        let b = NSButton(title: "Вернуться в Яндекс Музыку", target: nil, action: #selector(returnToMusicApp))
        b.isBordered = false
        b.bezelStyle = .inline
        if #available(macOS 14.0, *) {
            b.contentTintColor = NSColor.systemBlue.withAlphaComponent(0.8)
        } else {
            b.contentTintColor = NSColor.systemBlue
        }
        b.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        b.isHidden = true
        return b
    }()

    // MARK: - Placeholder UI
    private let placeholderContainer: NSView = {
        let v = NSView()
        v.isHidden = true
        return v
    }()

    private let placeholderTitle: NSTextField = {
        let l = NSTextField(labelWithString: "Ничего не играет")
        l.font = NSFont.systemFont(ofSize: 18, weight: .bold)
        l.textColor = .white
        l.alignment = .center
        return l
    }()

    private let placeholderSubtitle: NSTextField = {
        let l = NSTextField(labelWithString: "Включите музыку в одном из приложений:")
        l.font = NSFont.systemFont(ofSize: 13, weight: .regular)
        l.textColor = NSColor(white: 1.0, alpha: 0.6)
        l.alignment = .center
        return l
    }()

    private let launcherStack: NSStackView = {
        let s = NSStackView()
        s.orientation = .horizontal
        s.spacing = 24
        s.alignment = .centerY
        return s
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

    private func openPlayingApp() {
        // Run nowplaying-cli get-raw to find bundle ID
        DispatchQueue.global(qos: .userInitiated).async {
            let task = Process()
            // We use standard shell to resolve nowplaying-cli from PATH or fallback to hardcoded path
            task.executableURL = URL(fileURLWithPath: "/bin/zsh")
            task.arguments = ["-c", "/opt/homebrew/bin/nowplaying-cli get-raw || nowplaying-cli get-raw"]
            let pipe = Pipe()
            task.standardOutput = pipe
            do {
                try task.run()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                if let str = String(data: data, encoding: .utf8) {
                    if let range = str.range(of: "kMRMediaRemoteNowPlayingInfoClientBundleIdentifier = \"([^\"]+)\"", options: .regularExpression) {
                        let match = String(str[range])
                        let components = match.components(separatedBy: "\"")
                        if components.count >= 2 {
                            let bundleId = components[1]
                            let openTask = Process()
                            openTask.executableURL = URL(fileURLWithPath: "/usr/bin/open")
                            openTask.arguments = ["-b", bundleId]
                            try? openTask.run()
                            return
                        }
                    }
                }
            } catch {
                print("Failed to run nowplaying-cli")
            }
            
            // Fallback to Yandex Music if nowplaying-cli isn't found or fails
            let openTask = Process()
            openTask.executableURL = URL(fileURLWithPath: "/usr/bin/open")
            openTask.arguments = ["-b", "ru.yandex.desktop.music"]
            try? openTask.run()
        }
    }

    private func setup() {
        wantsLayer = true
        layer?.masksToBounds = false

        addSubview(bgView)
        bgView.addSubview(bgTintView)
        bgTintView.frame = bgView.bounds
        bgView.addSubview(maskContainer)
        maskContainer.addSubview(compactContainer)
        maskContainer.addSubview(expandedContainer)

        // Add compact elements
        compactContainer.addSubview(compactArtwork)
        compactContainer.addSubview(compactMarquee)
        compactContainer.addSubview(compactTiming)
        compactContainer.addSubview(compactEq)
        compactEq.onClick = { [weak self] in
            self?.togglePlayPause()
        }
        compactContainer.addSubview(compactNextBtn)

        // Add expanded elements
        expandedContainer.addSubview(expandedArtwork)
        expandedArtwork.onClick = { [weak self] in
            self?.openPlayingApp()
        }
        expandedContainer.addSubview(expandedTitle)
        expandedContainer.addSubview(expandedArtist)
        expandedContainer.addSubview(expandedProgress)
        expandedContainer.addSubview(expandedElapsed)
        expandedContainer.addSubview(expandedDuration)
        expandedContainer.addSubview(expandedPrev)
        expandedContainer.addSubview(expandedPlayPause)
        expandedContainer.addSubview(expandedNext)
        expandedContainer.addSubview(expandedEq)
        expandedContainer.addSubview(returnButton)

        expandedProgress.onSeek = { [weak self] percentage in
            guard let self = self, let state = self.currentState, state.duration > 0 else { return }
            let targetSeconds = state.duration * percentage
            
            // Optimistic instant update
            state.elapsedTime = targetSeconds
            state.timestamp = Date().timeIntervalSince1970
            state.ignorePositionUpdatesUntil = Date().addingTimeInterval(2.0)
            self.updateProgress(state)
            
            self.mediaBridge?.sendCommand("seek", String(targetSeconds))
        }

        // Add placeholder
        expandedContainer.addSubview(placeholderContainer)
        placeholderContainer.addSubview(placeholderTitle)
        placeholderContainer.addSubview(placeholderSubtitle)
        placeholderContainer.addSubview(launcherStack)
        
        setupLaunchers()

        // Actions
        compactNextBtn.target = self
        compactNextBtn.action = #selector(nextTrack)
        
        expandedPrev.target = self
        expandedPrev.action = #selector(prevTrack)
        expandedPlayPause.target = self
        expandedPlayPause.action = #selector(togglePlayPause)
        expandedNext.target = self
        expandedNext.action = #selector(nextTrack)
        returnButton.target = self
        returnButton.action = #selector(returnToMusicApp)

        // Timer
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.updateProgressFromTimer()
        }

        // Initial layout
        performLayout(animated: false)
    }

    private func setupLaunchers() {
        let apps = [
            ("ru.yandex.desktop.music", "Yandex Music"),
            ("com.spotify.client", "Spotify"),
            ("com.apple.Music", "Apple Music")
        ]
        
        for app in apps {
            if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: app.0) {
                let icon = NSWorkspace.shared.icon(forFile: url.path)
                let btn = NSButton(image: icon, target: self, action: #selector(launcherClicked(_:)))
                btn.isBordered = false
                btn.bezelStyle = .regularSquare
                btn.imageScaling = .scaleProportionallyUpOrDown
                btn.toolTip = app.1
                btn.identifier = NSUserInterfaceItemIdentifier(app.0)
                btn.translatesAutoresizingMaskIntoConstraints = false
                btn.widthAnchor.constraint(equalToConstant: 40).isActive = true
                btn.heightAnchor.constraint(equalToConstant: 40).isActive = true
                launcherStack.addView(btn, in: .center)
            }
        }
        
        // Add SoundCloud as a web link
        if let scIcon = NSImage(systemSymbolName: "globe", accessibilityDescription: "SoundCloud")?.withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 24, weight: .regular)) {
            let scBtn = NSButton(image: scIcon, target: self, action: #selector(launcherClicked(_:)))
            scBtn.isBordered = false
            scBtn.bezelStyle = .regularSquare
            scBtn.contentTintColor = .white
            scBtn.toolTip = "SoundCloud"
            scBtn.identifier = NSUserInterfaceItemIdentifier("soundcloud_web")
            scBtn.translatesAutoresizingMaskIntoConstraints = false
            scBtn.widthAnchor.constraint(equalToConstant: 40).isActive = true
            scBtn.heightAnchor.constraint(equalToConstant: 40).isActive = true
            launcherStack.addView(scBtn, in: .center)
        }
    }

    @objc private func launcherClicked(_ sender: NSButton) {
        guard let id = sender.identifier?.rawValue else { return }
        if id == "soundcloud_web" {
            if let url = URL(string: "https://soundcloud.com") {
                NSWorkspace.shared.open(url)
            }
        } else {
            if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id) {
                NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration(), completionHandler: nil)
            }
        }
        
        setExpanded(false)
    }

    // MARK: - Layout Logic

    private func performLayout(animated: Bool) {
        let b = bounds
        let centerX = b.width / 2
        
        let screen = NSScreen.screens.first(where: { $0.safeAreaInsets.top > 0 }) ?? NSScreen.main
        let actualMenuBarHeight = screen.flatMap { $0.frame.maxY - $0.visibleFrame.maxY } ?? menuBarHeight
        let actualMBH = actualMenuBarHeight > 10 ? actualMenuBarHeight : menuBarHeight
        
        let compactHeight: CGFloat = 37
        let y2 = b.height
        let y1 = b.height - actualMBH
        let topY = y1 + ((y2 - y1) - compactHeight) / 2.0
        
        let pillX = centerX - notchWidth / 2 - compactPillWidth
        let playerMaxX = centerX - notchWidth / 2
        let playerX = playerMaxX - expandedPlayerWidth

        let compactRect = NSRect(x: pillX, y: topY, width: compactPillWidth, height: compactHeight)
        let expandedRect = NSRect(x: playerX, y: 0, width: expandedPlayerWidth, height: b.height)

        // Update fixed layouts inside containers
        layoutCompactContainer(NSRect(x: 0, y: 0, width: compactPillWidth, height: compactHeight))
        layoutExpandedContainer(NSRect(x: 0, y: 0, width: expandedPlayerWidth, height: b.height))

        let targetBgRect = isExpanded ? expandedRect : compactRect
        let targetRadius: CGFloat = isExpanded ? 24 : 12

        var trackingRect = targetBgRect
        if !isExpanded, currentState?.hasTrack == true {
            // Limit hover area to artwork and marquee (exclude timing, EQ, Next Button)
            trackingRect.size.width = compactMarquee.frame.maxX
        }

        currentTargetBgRect = targetBgRect
        updateHoverTrackingArea(rect: trackingRect)

        let txCompact = compactRect.minX - targetBgRect.minX
        let tyCompact = compactRect.minY - targetBgRect.minY
        
        let txExpanded = expandedRect.minX - targetBgRect.minX
        let tyExpanded = expandedRect.minY - targetBgRect.minY

        let maskRect = NSRect(origin: .zero, size: targetBgRect.size)

        compactMarquee.isRunning = false
        
        // Keep their bounds/frames constant so text doesn't re-layout or snap
        compactContainer.frame = NSRect(origin: .zero, size: compactRect.size)
        expandedContainer.frame = NSRect(origin: .zero, size: expandedRect.size)
        
        compactContainer.isHidden = false
        expandedContainer.isHidden = false

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
                self.compactContainer.isHidden = self.isExpanded
                self.expandedContainer.isHidden = !self.isExpanded
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
            
            compactContainer.isHidden = isExpanded
            expandedContainer.isHidden = !isExpanded
            
            compactMarquee.isRunning = !isExpanded
        }
    }

    private func layoutCompactContainer(_ bounds: NSRect) {
        if currentState?.hasTrack == false {
            compactEq.isHidden = true
            compactTiming.isHidden = true
            compactMarquee.isHidden = true
            compactNextBtn.isHidden = true
            
            let iconSize: CGFloat = 16
            compactArtwork.frame = NSRect(x: (bounds.width - iconSize) / 2, y: (bounds.height - iconSize) / 2, width: iconSize, height: iconSize)
            return
        }
        
        compactEq.isHidden = false
        compactTiming.isHidden = false
        compactMarquee.isHidden = false
        compactNextBtn.isHidden = false

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
        if currentState?.hasTrack == false {
            expandedArtwork.isHidden = true
            expandedTitle.isHidden = true
            expandedArtist.isHidden = true
            expandedProgress.isHidden = true
            expandedElapsed.isHidden = true
            expandedDuration.isHidden = true
            expandedPlayPause.isHidden = true
            expandedNext.isHidden = true
            expandedPrev.isHidden = true
            expandedEq.isHidden = true
            returnButton.isHidden = true
            
            placeholderContainer.isHidden = false
            placeholderContainer.frame = bounds
            
            placeholderTitle.frame = NSRect(x: 0, y: bounds.height - 50, width: bounds.width, height: 24)
            placeholderSubtitle.frame = NSRect(x: 0, y: bounds.height - 75, width: bounds.width, height: 20)
            launcherStack.frame = NSRect(x: 0, y: bounds.height - 130, width: bounds.width, height: 40)
            return
        }
        
        expandedArtwork.isHidden = false
        expandedTitle.isHidden = false
        expandedArtist.isHidden = false
        expandedProgress.isHidden = false
        expandedElapsed.isHidden = false
        expandedDuration.isHidden = false
        expandedPlayPause.isHidden = false
        expandedNext.isHidden = false
        expandedPrev.isHidden = false
        expandedEq.isHidden = false
        placeholderContainer.isHidden = true

        let margin: CGFloat = 20
        let artSize: CGFloat = 80
        expandedArtwork.frame = NSRect(x: margin, y: (bounds.height - artSize) / 2, width: artSize, height: artSize)

        let eqW: CGFloat = 24
        let eqH: CGFloat = 20
        let eqX = bounds.width - margin - eqW
        expandedEq.frame = NSRect(x: eqX, y: (bounds.height - eqH) / 2, width: eqW, height: eqH)

        // Calculate the exact center between the artwork and the EQ to ensure perfectly equal gaps
        let artMaxX = expandedArtwork.frame.maxX
        let centerBlockX = artMaxX + (eqX - artMaxX) / 2

        let textW: CGFloat = 240
        let topY = bounds.height - 35
        
        expandedTitle.frame = NSRect(x: centerBlockX - textW/2, y: topY - 20, width: textW, height: 20)
        expandedArtist.frame = NSRect(x: centerBlockX - textW/2, y: topY - 40, width: textW, height: 16)

        let progressY = topY - 60
        let progressW: CGFloat = 160
        expandedProgress.frame = NSRect(x: centerBlockX - progressW/2, y: progressY - 8, width: progressW, height: 20)

        let timeW: CGFloat = 40
        expandedElapsed.frame = NSRect(x: centerBlockX - progressW/2 - timeW - 8, y: progressY - 5, width: timeW, height: 14)
        expandedDuration.frame = NSRect(x: centerBlockX + progressW/2 + 8, y: progressY - 5, width: timeW, height: 14)

        let controlsY = progressY - 30
        let btnSize: CGFloat = 24
        let playSize: CGFloat = 32
        let spacing: CGFloat = 30

        expandedPlayPause.frame = NSRect(x: centerBlockX - playSize/2, y: controlsY - playSize/2 + 4, width: playSize, height: playSize)
        expandedPrev.frame = NSRect(x: centerBlockX - spacing - playSize/2 - btnSize/2, y: controlsY - btnSize/2 + 4, width: btnSize, height: btnSize)
        expandedNext.frame = NSRect(x: centerBlockX + spacing + playSize/2 - btnSize/2, y: controlsY - btnSize/2 + 4, width: btnSize, height: btnSize)
        
        let returnBtnW: CGFloat = 200
        let returnBtnH: CGFloat = 16
        returnButton.frame = NSRect(x: centerBlockX - returnBtnW/2, y: 4, width: returnBtnW, height: returnBtnH)
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
        let previousHasTrack = currentState?.hasTrack ?? false
        currentState = state

        if previousHasTrack != state.hasTrack {
            performLayout(animated: true)
        }

        expandedTitle.stringValue = state.title
        expandedArtist.stringValue = state.artist
        
        if !state.artist.isEmpty && !state.title.isEmpty {
            compactMarquee.text = "\(state.artist) — \(state.title)"
        } else {
            compactMarquee.text = state.title
        }
        
        if state.isPlaying {
            compactEq.isAnimating = true
            expandedEq.isAnimating = true
        } else {
            compactEq.isAnimating = false
            expandedEq.isAnimating = false
        }
        
        if state.isHijacked && !state.lastMusicAppName.isEmpty {
            returnButton.title = "Вернуться в \(state.lastMusicAppName)"
            returnButton.isHidden = false
        } else {
            returnButton.isHidden = true
        }

        let symbolName = state.isPlaying ? "pause.fill" : "play.fill"
        let img = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)?.withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 22, weight: .bold))
        expandedPlayPause.image = img
        
        compactEq.isAnimating = state.isPlaying
        expandedEq.isAnimating = state.isPlaying

        if let data = state.artworkData, let img = NSImage(data: data) {
            compactArtwork.image = img
            expandedArtwork.image = img
            
            if lastArtworkData != data {
                lastArtworkData = data
                DispatchQueue.global(qos: .userInitiated).async {
                    if let color = img.averageColor() {
                        DispatchQueue.main.async {
                            NSAnimationContext.runAnimationGroup { context in
                                context.duration = 1.0
                                self.bgTintView.animator().layer?.backgroundColor = color.withAlphaComponent(0.35).cgColor
                            }
                        }
                    }
                }
            }
        } else {
            if !state.hasTrack {
                compactArtwork.image = NSImage(systemSymbolName: "music.note", accessibilityDescription: nil)
            } else {
                compactArtwork.image = nil
            }
            expandedArtwork.image = nil
            
            if lastArtworkData != nil {
                lastArtworkData = nil
                NSAnimationContext.runAnimationGroup { context in
                    context.duration = 1.0
                    self.bgTintView.animator().layer?.backgroundColor = NSColor.clear.cgColor
                }
            }
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
        sendTargetedCommand("toggle-play-pause")
    }

    @objc private func prevTrack() {
        sendTargetedCommand("previous-track")
    }

    @objc private func nextTrack() {
        sendTargetedCommand("next-track")
    }
    
    @objc private func returnToMusicApp() {
        guard let bundleID = currentState?.lastMusicAppBundleID else { return }

        let runningApps = NSWorkspace.shared.runningApplications
        if let targetApp = runningApps.first(where: { $0.bundleIdentifier == bundleID }) {
            DispatchQueue.main.async {
                targetApp.activate(options: [])
            }
        }
    }

    private func sendTargetedCommand(_ command: String) {
        if currentState?.isHijacked == true {
            mediaBridge?.sendCommand(command)
            return
        }

        let allowedApps = ["ru.yandex.desktop.music", "com.spotify.client", "com.apple.Music"]
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            var activeBundleID = ""
            var cliPath = "/opt/homebrew/bin/nowplaying-cli"
            if !FileManager.default.fileExists(atPath: cliPath) {
                cliPath = "/usr/local/bin/nowplaying-cli"
            }
            if FileManager.default.fileExists(atPath: cliPath) {
                let task = Process()
                task.executableURL = URL(fileURLWithPath: cliPath)
                task.arguments = ["get-raw"]
                let pipe = Pipe()
                task.standardOutput = pipe
                if (try? task.run()) != nil {
                    task.waitUntilExit()
                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let bundle = json["kMRMediaRemoteNowPlayingInfoClientBundleIdentifier"] as? String {
                        activeBundleID = bundle
                    }
                }
            }

            // If the active audio session is one of our music apps, just send the command globally.
            if allowedApps.contains(activeBundleID) {
                self.mediaBridge?.sendCommand(command)
                return
            }
            
            // Otherwise find the first allowed app that is running
            let runningApps = NSWorkspace.shared.runningApplications
            var targetApp: NSRunningApplication? = nil
            var targetBundleID = ""
            
            for app in runningApps {
                if let bID = app.bundleIdentifier, allowedApps.contains(bID) {
                    targetApp = app
                    targetBundleID = bID
                    break
                }
            }
            
            guard let appToPause = targetApp else {
                self.mediaBridge?.sendCommand(command)
                return
            }

            if targetBundleID == "com.apple.Music" {
                let script = command == "toggle-play-pause" ? "playpause" : (command == "next-track" ? "next track" : "previous track")
                let source = "tell application id \"com.apple.Music\" to \(script)"
                NSAppleScript(source: source)?.executeAndReturnError(nil)
                return
            }

            if targetBundleID == "com.spotify.client" {
                let script = command == "toggle-play-pause" ? "playpause" : (command == "next-track" ? "next track" : "previous track")
                let source = "tell application id \"com.spotify.client\" to \(script)"
                NSAppleScript(source: source)?.executeAndReturnError(nil)
                return
            }

            // Yandex Music temporary activation
            if !appToPause.isActive {
                DispatchQueue.main.async {
                    let currentApp = NSWorkspace.shared.frontmostApplication
                    appToPause.activate(options: [])
                    
                    DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 0.15) {
                        let task = Process()
                        task.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/nowplaying-cli")
                        task.arguments = [command]
                        try? task.run()
                        task.waitUntilExit()
                        
                        DispatchQueue.main.async {
                            currentApp?.activate(options: [])
                        }
                    }
                }
            } else {
                self.mediaBridge?.sendCommand(command)
            }
        }
    }

    deinit {
        progressTimer?.invalidate()
    }
    override func hitTest(_ point: NSPoint) -> NSView? {
        // Convert point to local coordinates
        let localPoint = self.convert(point, from: self.superview)
        
        // Only accept clicks if they hit the visible background area.
        if bgView.frame.contains(localPoint) {
            return super.hitTest(point)
        }
        
        // Ignore clicks in the transparent regions around the player
        return nil
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

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        return true
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
    var onClick: (() -> Void)?
    
    override init(frame: NSRect) { super.init(frame: frame) ; wantsLayer = true ; setupBars() }
    required init?(coder: NSCoder) { super.init(coder: coder) ; wantsLayer = true ; setupBars() }
    
    override func mouseDown(with event: NSEvent) {
        if onClick != nil {
            onClick?()
        } else {
            super.mouseDown(with: event)
        }
    }
    
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

// MARK: - Interactive Artwork View
class InteractiveArtworkView: NSView {
    private let imageView = NSImageView()
    private let overlayView: NSView = {
        let v = NSView()
        v.wantsLayer = true
        v.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.65).cgColor
        v.alphaValue = 0
        return v
    }()
    private let iconView = NSImageView()
    private let label = NSTextField(labelWithString: "Открыть")
    
    var onClick: (() -> Void)?
    
    var image: NSImage? {
        get { return imageView.image }
        set { imageView.image = newValue }
    }
    
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
        layer?.cornerRadius = 10
        layer?.masksToBounds = true
        
        imageView.imageScaling = .scaleProportionallyUpOrDown
        addSubview(imageView)
        
        // Dark overlay — NSView so it renders above imageView
        addSubview(overlayView)
        
        if let icon = NSImage(systemSymbolName: "arrow.up.forward.app", accessibilityDescription: nil) {
            let config = NSImage.SymbolConfiguration(pointSize: 20, weight: .medium)
            iconView.image = icon.withSymbolConfiguration(config)
        }
        iconView.contentTintColor = .white
        iconView.alphaValue = 0
        addSubview(iconView)
        
        label.font = NSFont.systemFont(ofSize: 10, weight: .semibold)
        label.textColor = .white
        label.alignment = .center
        label.isEditable = false
        label.isSelectable = false
        label.isBordered = false
            label.backgroundColor = .clear
        label.alphaValue = 0
        addSubview(label)
    }

    override func layout() {
        super.layout()
        imageView.frame = bounds
        overlayView.frame = bounds
        
        let iconSize: CGFloat = 24
        iconView.frame = NSRect(x: (bounds.width - iconSize) / 2, y: (bounds.height / 2) + 2, width: iconSize, height: iconSize)
        label.frame = NSRect(x: 0, y: (bounds.height / 2) - 16, width: bounds.width, height: 14)
    }
    
    override func mouseEntered(with event: NSEvent) {
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.15
            self.overlayView.animator().alphaValue = 1
            self.iconView.animator().alphaValue = 1
            self.label.animator().alphaValue = 1
        }
    }
    
    override func mouseExited(with event: NSEvent) {
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.15
            self.overlayView.animator().alphaValue = 0
            self.iconView.animator().alphaValue = 0
            self.label.animator().alphaValue = 0
        }
    }
    
    override func mouseDown(with event: NSEvent) {
        // Visual feedback
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.08
            self.overlayView.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.8).cgColor
        }, completionHandler: {
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.08
                self.overlayView.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.65).cgColor
            }
        })
        onClick?()
    }
    
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        return true
    }
    
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach { removeTrackingArea($0) }
        let trackingArea = NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeAlways], owner: self, userInfo: nil)
        addTrackingArea(trackingArea)
    }
}
