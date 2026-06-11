import AppKit

for screen in NSScreen.screens {
    print("Screen frame: \(screen.frame)")
    print("Screen visibleFrame: \(screen.visibleFrame)")
    if #available(macOS 12.0, *) {
        print("safeAreaInsets: \(screen.safeAreaInsets)")
        print("auxTopLeft: \(String(describing: screen.auxiliaryTopLeftArea))")
        print("auxTopRight: \(String(describing: screen.auxiliaryTopRightArea))")
    }
}
