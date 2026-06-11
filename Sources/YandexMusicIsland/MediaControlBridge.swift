import Foundation

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
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.fetchInitialState()
            self?.startStream()
        }
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
                self.state.update(from: payload)
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.onUpdate?(self.state)
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
                
                // Completely ignore payloads from live streams (e.g. Twitch)
                if !self.state.isValidPayload(payload) {
                    continue
                }
                
                self.state.update(from: payload)
                
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.onUpdate?(self.state)
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
