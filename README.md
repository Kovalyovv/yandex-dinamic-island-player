# Yandex Music Island 🎵

A sleek, modern macOS menu bar widget for controlling Yandex Music. Designed to seamlessly integrate with your Mac, drawing inspiration from the Dynamic Island.

## Features ✨

*   **Dynamic Island Style**: Sits beautifully next to your macOS notch (or menu bar center) and smoothly expands when clicked.
*   **Media Controls**: Play/Pause, Next Track, and Previous Track right from the menu bar.
*   **Live Equalizer**: Animated equalizer bars that sync with the playing state.
*   **Track Marquee**: Smoothly scrolling track title and artist name in the compact view.
*   **No Interference**: Perfectly transparent areas allow you to click system icons beneath the widget without any issues.

## Screenshots 📸

| Compact Mode | Expanded Mode |
|:---:|:---:|
| <img src="assets/compact.png" width="400"/> | <img src="assets/expanded.png" width="400"/> |

## Installation 🚀

You can download the pre-compiled `.dmg` file from the **Releases** page on GitHub.
1. Open the downloaded `YandexMusicIsland.dmg` file.
2. Drag and drop **YandexMusicIsland.app** into your `Applications` folder.
3. Open Launchpad and launch the app.
4. *(Note: Upon first launch, macOS may ask for Accessibility permissions to control media keys and AppleScript).*

## Development 🛠️

To build the project from source, you need Xcode and Swift installed on your Mac.

1. Clone this repository:
   ```bash
   git clone https://github.com/Kovalyovv/yandex-dinamic-island-player.git
   cd yandex-dinamic-island-player
   ```
2. Run the build script:
   ```bash
   bash build.sh
   ```
   This will compile the Swift code, attach the custom app icon, and automatically install the `.app` bundle into `~/Applications`.

## Packaging 📦

To create a `.dmg` file for distribution:
```bash
bash build_dmg.sh
```
This will generate `YandexMusicIsland.dmg` in the root folder, ready to be uploaded to GitHub Releases.

## Requirements

*   macOS 12.0 or later
*   Yandex Music desktop app (or web player with media key support)
