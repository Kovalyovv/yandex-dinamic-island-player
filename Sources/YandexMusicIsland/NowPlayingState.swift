import Foundation

/// Holds the current Now Playing state from media-control
class NowPlayingState {
    var title: String = ""
    var artist: String = ""
    var album: String = ""
    var artworkData: Data?
    var isPlaying: Bool = false
    var duration: Double = 0
    var elapsedTime: Double = 0
    var timestamp: Double = 0
    var playbackRate: Double = 0
    var contentItemIdentifier: String = ""

    var activeBundleID: String = ""
    var isHijacked: Bool = false
    var lastMusicAppName: String = ""
    var lastMusicAppBundleID: String = ""

    var ignorePositionUpdatesUntil: Date?

    /// Check if the incoming payload represents a valid music stream (not a live stream/Twitch)
    func isValidPayload(_ dict: [String: Any]) -> Bool {
        let incomingTitle = dict["title"] as? String ?? ""
        let incomingArtist = dict["artist"] as? String ?? ""
        
        if incomingTitle.isEmpty && incomingArtist.isEmpty { return false }
        // Allow streams (duration == 0)
        return true
    }

    /// Computed: estimate current elapsed time based on timestamp
    var estimatedElapsedTime: Double {
        guard isPlaying, timestamp > 0 else { return elapsedTime }
        let now = Date().timeIntervalSince1970
        let delta = now - timestamp
        return min(elapsedTime + delta * playbackRate, duration)
    }

    /// Format seconds to "m:ss"
    static func formatTime(_ seconds: Double) -> String {
        guard seconds.isFinite && seconds >= 0 else { return "0:00" }
        let totalSeconds = Int(seconds)
        let m = totalSeconds / 60
        let s = totalSeconds % 60
        return String(format: "%d:%02d", m, s)
    }

    /// Update state from media-control JSON dictionary
    func update(from dict: [String: Any]) {
        if let v = dict["title"] as? String { title = v }
        if let v = dict["artist"] as? String { artist = v }
        if let v = dict["album"] as? String { album = v }
        if let v = dict["playing"] as? Bool { isPlaying = v }
        if let num = dict["duration"] as? NSNumber { duration = num.doubleValue }
        
        let shouldIgnorePosition = ignorePositionUpdatesUntil != nil && Date() < ignorePositionUpdatesUntil!
        
        if !shouldIgnorePosition {
            if let num = dict["elapsedTime"] as? NSNumber { elapsedTime = num.doubleValue }
            if let num = dict["elapsedTimeNow"] as? NSNumber { elapsedTime = num.doubleValue }
            
            if let v = dict["timestamp"] as? String {
                let formatter = ISO8601DateFormatter()
                formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                if let date = formatter.date(from: v) ?? ISO8601DateFormatter().date(from: v) {
                    timestamp = date.timeIntervalSince1970
                }
            }
        } else if let ignoreUntil = ignorePositionUpdatesUntil, Date() >= ignoreUntil {
            ignorePositionUpdatesUntil = nil
        }
        
        if let num = dict["playbackRate"] as? NSNumber { playbackRate = num.doubleValue }
        if let v = dict["contentItemIdentifier"] as? String { contentItemIdentifier = v }

        // Artwork comes as base64 in the JSON
        if let v = dict["artworkData"] as? String, let data = Data(base64Encoded: v) {
            artworkData = data
        }
    }

    /// Returns true if there's actual track data
    var hasTrack: Bool {
        return !title.isEmpty
    }
}
