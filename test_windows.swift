import AppKit

let options = CGWindowListOption(arrayLiteral: .optionOnScreenOnly)
if let info = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] {
    for window in info {
        if let owner = window[kCGWindowOwnerName as String] as? String, owner == "YandexMusicIsland" {
            print("Window: \(window)")
        }
    }
}
