#!/bin/bash
set -Eeuo pipefail

LABEL="com.openai.stormylakewallpaper"
ROOT="$HOME/Library/Application Support/StormyLakeWallpaper"
SOURCE="$ROOT/StormyLakeWallpaper.swift"
BINARY="$ROOT/StormyLakeWallpaper"
VIDEO="$ROOT/stormy-wallpaper.mp4"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
VIDEO_URL="https://raw.githubusercontent.com/mawaqit/mobile-assets/main/weather-videos/thunderstorm.mp4"
UID_NUMBER="$(id -u)"

fail() {
  printf '\nInstallation stopped: %s\n' "$1" >&2
  /usr/bin/osascript -e "display dialog \"Stormy wallpaper could not be installed.\\n\\n$1\" buttons {\"OK\"} default button \"OK\" with icon stop" >/dev/null 2>&1 || true
  exit 1
}

printf '\nInstalling the animated storm wallpaper…\n'
mkdir -p "$ROOT" "$HOME/Library/LaunchAgents"

printf 'Downloading the animation…\n'
TMP_VIDEO="$VIDEO.download"
rm -f "$TMP_VIDEO"
/usr/bin/curl -fL --retry 4 --retry-delay 2 --connect-timeout 20 \
  "$VIDEO_URL" -o "$TMP_VIDEO" || fail "The animation download failed. Check the internet connection and run the same command again."
[[ -s "$TMP_VIDEO" ]] || fail "The downloaded animation was empty."
mv -f "$TMP_VIDEO" "$VIDEO"

if ! /usr/bin/xcrun --find swiftc >/dev/null 2>&1; then
  /usr/bin/xcode-select --install >/dev/null 2>&1 || true
  fail "Apple Command Line Tools are not installed. Approve Apple's installation window, then run the same Terminal command once more."
fi

cat > "$SOURCE" <<'SWIFT'
import AppKit
import AVFoundation
import QuartzCore
import CoreGraphics

final class WallpaperDelegate: NSObject, NSApplicationDelegate {
    private var windows: [NSWindow] = []
    private var players: [AVQueuePlayer] = []
    private var loopers: [AVPlayerLooper] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        guard CommandLine.arguments.count >= 2 else {
            NSApp.terminate(nil)
            return
        }

        let videoURL = URL(fileURLWithPath: CommandLine.arguments[1])
        guard FileManager.default.fileExists(atPath: videoURL.path) else {
            NSApp.terminate(nil)
            return
        }

        for screen in NSScreen.screens {
            installWallpaper(on: screen, videoURL: videoURL)
        }
    }

    private func installWallpaper(on screen: NSScreen, videoURL: URL) {
        let window = NSWindow(
            contentRect: screen.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false,
            screen: screen
        )

        window.isOpaque = true
        window.backgroundColor = .black
        window.hasShadow = false
        window.ignoresMouseEvents = true
        window.hidesOnDeactivate = false
        window.isReleasedWhenClosed = false
        window.level = NSWindow.Level(
            rawValue: Int(CGWindowLevelForKey(.desktopWindow)) + 1
        )
        window.collectionBehavior = [
            .canJoinAllSpaces,
            .stationary,
            .ignoresCycle
        ]

        let container = NSView(frame: NSRect(origin: .zero, size: screen.frame.size))
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor.black.cgColor

        let item = AVPlayerItem(url: videoURL)
        let player = AVQueuePlayer()
        player.isMuted = true
        let looper = AVPlayerLooper(player: player, templateItem: item)

        let videoLayer = AVPlayerLayer(player: player)
        videoLayer.frame = container.bounds
        videoLayer.videoGravity = .resizeAspectFill
        videoLayer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
        container.layer?.addSublayer(videoLayer)

        window.contentView = container
        window.setFrame(screen.frame, display: true)
        window.orderFrontRegardless()
        player.playImmediately(atRate: 1.0)

        windows.append(window)
        players.append(player)
        loopers.append(looper)
    }
}

let application = NSApplication.shared
let delegate = WallpaperDelegate()
application.delegate = delegate
application.run()
SWIFT

printf 'Building the wallpaper player…\n'
/usr/bin/xcrun swiftc -O \
  -framework AppKit \
  -framework AVFoundation \
  -framework QuartzCore \
  -framework CoreGraphics \
  "$SOURCE" -o "$BINARY" || fail "The Mac wallpaper player did not compile."
chmod 755 "$BINARY"

cat > "$PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>$LABEL</string>
  <key>ProgramArguments</key>
  <array>
    <string>$BINARY</string>
    <string>$VIDEO</string>
  </array>
  <key>RunAtLoad</key>
  <true/>
  <key>KeepAlive</key>
  <true/>
  <key>ProcessType</key>
  <string>Interactive</string>
  <key>LimitLoadToSessionType</key>
  <string>Aqua</string>
  <key>StandardOutPath</key>
  <string>$ROOT/wallpaper.log</string>
  <key>StandardErrorPath</key>
  <string>$ROOT/wallpaper-error.log</string>
</dict>
</plist>
PLIST

/bin/launchctl bootout "gui/$UID_NUMBER" "$PLIST" >/dev/null 2>&1 || true
/bin/launchctl bootstrap "gui/$UID_NUMBER" "$PLIST" || fail "macOS would not register the wallpaper at login."
/bin/launchctl kickstart -k "gui/$UID_NUMBER/$LABEL" >/dev/null 2>&1 || true

sleep 2
if /usr/bin/pgrep -f "$BINARY" >/dev/null 2>&1; then
  printf '\nDone — the animated storm wallpaper is running and will start automatically at login.\n'
  /usr/bin/osascript -e 'display notification "The animated storm wallpaper is now running." with title "Wallpaper installed"' >/dev/null 2>&1 || true
else
  fail "The player installed but did not remain running."
fi
