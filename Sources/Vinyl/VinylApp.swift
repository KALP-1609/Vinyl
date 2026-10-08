import SwiftUI
import AppKit

@main
struct VinylApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var model = PlayerModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(model)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 340, height: 480)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillFinishLaunching(_ notification: Notification) {
        // Only ever run one copy: if Vinyl is already open, bring it forward and quit this one.
        if let id = Bundle.main.bundleIdentifier, !id.isEmpty {
            let others = NSRunningApplication.runningApplications(withBundleIdentifier: id)
                .filter { $0 != NSRunningApplication.current }
            if let other = others.first {
                other.activate()
                DispatchQueue.main.async { NSApp.terminate(nil) }
            }
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}

/// Makes the window float, go transparent, and sizes it exactly (340 wide, or 680 with lyrics).
struct WindowConfigurator: NSViewRepresentable {
    var lyricsOpen: Bool

    func makeNSView(context: Context) -> ConfigView {
        let v = ConfigView()
        v.lyricsOpen = lyricsOpen
        return v
    }
    func updateNSView(_ v: ConfigView, context: Context) { v.lyricsOpen = lyricsOpen }

    final class ConfigView: NSView {
        static let height: CGFloat = 480
        var lyricsOpen = false {
            didSet { if oldValue != lyricsOpen { resize(animated: true) } }
        }

        override func viewDidMoveToWindow() {
            guard let w = window else { return }
            w.level = .floating                                               // hover above other apps
            w.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]  // and over fullscreen apps
            w.styleMask.insert(.fullSizeContentView)
            w.styleMask.remove(.resizable)
            w.isOpaque = false
            w.backgroundColor = .clear
            w.hasShadow = true
            w.titlebarAppearsTransparent = true
            w.titleVisibility = .hidden
            w.isMovableByWindowBackground = true
            w.standardWindowButton(.zoomButton)?.isEnabled = false
            w.setFrameAutosaveName("VinylMainWindow")                         // remember where you left it
            resize(animated: false)
        }

        func resize(animated: Bool) {
            guard let w = window else { return }
            let width: CGFloat = lyricsOpen ? 680 : 340
            let old = w.frame
            var new = NSRect(x: old.minX, y: old.maxY - Self.height, width: width, height: Self.height)

            // If the saved position is on a screen that's no longer connected, bring it back.
            if !NSScreen.screens.contains(where: { $0.visibleFrame.intersects(new) }),
               let s = NSScreen.main?.visibleFrame {
                new.origin = CGPoint(x: s.midX - width / 2, y: s.midY - Self.height / 2)
            }
            // Keep the lyrics panel on screen when opening near the right edge.
            if let screen = w.screen?.visibleFrame, new.maxX > screen.maxX {
                new.origin.x = max(screen.minX, screen.maxX - width)
            }
            w.setFrame(new, display: true, animate: animated)
            w.invalidateShadow()
        }
    }
}
