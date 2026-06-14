import Foundation
import AppKit

/// Bridge to `media-control` CLI tool.
/// Launches `media-control stream --no-diff` as a subprocess and parses JSON output.
/// Fixed: proper line buffering to handle partial reads from stdout.
class MediaControlBridge {
    private var process: Process?
    private var pipe: Pipe?
    private var dataBuffer = Data()

    var onUpdate: ((NowPlayingState) -> Void)?
    var onError: ((String) -> Void)?

    let state = NowPlayingState()
    private let mediaControlPath: String

    init() {
        // Find media-control binary
        if FileManager.default.fileExists(atPath: "/opt/homebrew/bin/media-control") {
            mediaControlPath = "/opt/homebrew/bin/media-control"
        } else if FileManager.default.fileExists(atPath: "/usr/local/bin/media-control") {
            mediaControlPath = "/usr/local/bin/media-control"
        } else {
            mediaControlPath = "media-control"
        }
    }

    /// Start streaming now playing info
    func start() {
        // Observe app termination to clear state if no music app is left running
        NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didTerminateApplicationNotification, object: nil, queue: .main) { [weak self] _ in
            guard let self = self else { return }
            if !self.isAnyAllowedMusicAppRunning() {
                self.clearState()
            }
        }
        
        // Initial check: if it's not running, clear state immediately
        if !isAnyAllowedMusicAppRunning() {
            clearState()
        }

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.fetchInitialState()
            self?.startStream()
        }
    }
    
    private let allowedMusicApps = [
        "ru.yandex.desktop.music",
        "com.spotify.client",
        "com.apple.Music",
        "com.soundcloud.desktop"
    ]
    
    private let appNames = [
        "ru.yandex.desktop.music": "Яндекс Музыку",
        "com.apple.Music": "Apple Music",
        "com.spotify.client": "Spotify",
        "com.soundcloud.desktop": "SoundCloud"
    ]

    private var lastKnownContentIdentifier = ""
    private var lastKnownBundleID = ""
    private var isFetchingBundleID = false
    private var pendingBundleIDCallbacks: [(String) -> Void] = []
    
    private func determineBundleID(payload: [String: Any], completion: @escaping (String) -> Void) {
        let currentIdentifier = (payload["title"] as? String) ?? ""
        
        if currentIdentifier == lastKnownContentIdentifier && !lastKnownBundleID.isEmpty {
            completion(lastKnownBundleID)
            return
        }
        
        if isFetchingBundleID {
            pendingBundleIDCallbacks.append(completion)
            return
        }
        
        lastKnownContentIdentifier = currentIdentifier
        isFetchingBundleID = true
        pendingBundleIDCallbacks.append(completion)
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
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
            
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.lastKnownBundleID = activeBundleID
                self.isFetchingBundleID = false
                let callbacks = self.pendingBundleIDCallbacks
                self.pendingBundleIDCallbacks.removeAll()
                callbacks.forEach { $0(activeBundleID) }
            }
        }
    }

    private func isAnyAllowedMusicAppRunning() -> Bool {
        return NSWorkspace.shared.runningApplications.contains { app in
            guard let bundleID = app.bundleIdentifier else { return false }
            return allowedMusicApps.contains(bundleID)
        }
    }
    
    private func clearState() {
        state.title = ""
        state.artist = ""
        state.album = ""
        state.artworkData = nil
        state.isPlaying = false
        state.duration = 0
        state.elapsedTime = 0
        onUpdate?(state)
    }

    private func fetchInitialState() {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: mediaControlPath)
        task.arguments = ["get"]
        
        let outPipe = Pipe()
        task.standardOutput = outPipe
        task.standardError = FileHandle.nullDevice
        
        do {
            try task.run()
            task.waitUntilExit()
            
            let data = outPipe.fileHandleForReading.readDataToEndOfFile()
            if let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                let payload = (dict["payload"] as? [String: Any]) ?? dict
                guard self.isAnyAllowedMusicAppRunning() else { return }
                if self.state.isValidPayload(payload) {
                    self.determineBundleID(payload: payload) { [weak self] activeBundleID in
                        guard let self = self else { return }
                        if self.allowedMusicApps.contains(activeBundleID) {
                            self.state.isHijacked = false
                            self.state.lastMusicAppBundleID = activeBundleID
                            self.state.lastMusicAppName = self.appNames[activeBundleID] ?? "Плеер"
                        } else {
                            self.state.isHijacked = true
                        }
                        self.state.update(from: payload)
                        DispatchQueue.main.async { [weak self] in
                            guard let self = self else { return }
                            self.onUpdate?(self.state)
                        }
                    }
                }
            }
        } catch {
            print("Failed to fetch initial state: \(error)")
        }
    }

    private func startStream() {
        stop() // Kill any existing process

        let task = Process()
        task.executableURL = URL(fileURLWithPath: mediaControlPath)
        task.arguments = ["stream", "--no-diff"]

        let outPipe = Pipe()
        task.standardOutput = outPipe
        task.standardError = FileHandle.nullDevice

        dataBuffer = Data()

        // Handle process termination — auto-restart
        task.terminationHandler = { [weak self] proc in
            guard let self = self else { return }
            DispatchQueue.main.async {
                if proc.terminationStatus != 0 {
                    self.onError?("media-control exited with status \(proc.terminationStatus)")
                }
            }
            // Restart after a delay
            DispatchQueue.global().asyncAfter(deadline: .now() + 3) { [weak self] in
                guard let self = self, self.process == task else { return }
                self.startStream()
            }
        }

        // Read stdout with proper line buffering
        outPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty, let self = self else { return }

            self.dataBuffer.append(data)

            // Process complete lines (each JSON object is one line)
            guard let fullString = String(data: self.dataBuffer, encoding: .utf8) else { return }
            var lines = fullString.components(separatedBy: "\n")

            // The last element is either empty (if data ended with \n) or an incomplete line
            let remainder = lines.removeLast()
            self.dataBuffer = Data(remainder.utf8)

            for line in lines {
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { continue }
                guard let jsonData = trimmed.data(using: .utf8),
                      let dict = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any]
                else { continue }

                let payload = (dict["payload"] as? [String: Any]) ?? dict
                guard self.isAnyAllowedMusicAppRunning() else { continue }
                
                // Completely ignore payloads from empty streams
                if !self.state.isValidPayload(payload) {
                    continue
                }
                
                self.determineBundleID(payload: payload) { [weak self] activeBundleID in
                    guard let self = self else { return }
                    if self.allowedMusicApps.contains(activeBundleID) {
                        self.state.isHijacked = false
                        self.state.lastMusicAppBundleID = activeBundleID
                        self.state.lastMusicAppName = self.appNames[activeBundleID] ?? "Плеер"
                    } else {
                        self.state.isHijacked = true
                    }
                    self.state.update(from: payload)
                    
                    DispatchQueue.main.async { [weak self] in
                        guard let self = self else { return }
                        self.onUpdate?(self.state)
                    }
                }
            }
        }

        do {
            try task.run()
            process = task
            pipe = outPipe
        } catch {
            onError?("Failed to start media-control: \(error.localizedDescription)")
        }
    }

    /// Send a media command (play, pause, next, previous, seek, etc.)
    func sendCommand(_ args: String...) {
        DispatchQueue.global(qos: .userInteractive).async { [weak self] in
            guard let self = self else { return }
            guard self.isAnyAllowedMusicAppRunning() else { return }
            let task = Process()
            task.executableURL = URL(fileURLWithPath: self.mediaControlPath)
            task.arguments = args
            task.standardOutput = FileHandle.nullDevice
            task.standardError = FileHandle.nullDevice
            try? task.run()
            task.waitUntilExit()
        }
    }

    func stop() {
        pipe?.fileHandleForReading.readabilityHandler = nil
        if let proc = process, proc.isRunning {
            proc.terminate()
        }
        process = nil
        pipe = nil
    }

    deinit {
        stop()
    }
}
