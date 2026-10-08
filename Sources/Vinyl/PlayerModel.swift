import AppKit
import Combine
import SwiftUI

struct Track: Identifiable {
    let id = UUID()
    let title: String
    let artist: String
    let album: String
    let artwork: NSImage?
    let duration: Double
}

struct LyricLine: Identifiable {
    let id: Int
    let time: Double
    let text: String
}

enum LyricsState { case idle, loading, synced, plain, none }
enum Connection { case notInstalled, notRunning, needsPermission, connected }

/// Playback time lives in its own object so the frequent updates only redraw the progress bar.
@MainActor
final class PlaybackClock: ObservableObject {
    @Published var time = 0.0
}

/// Mirrors whatever the Spotify desktop app is playing.
@MainActor
final class PlayerModel: ObservableObject {
    @Published var isPlaying = false
    @Published var duration = 0.0
    @Published var tintA = Color(red: 0.47, green: 0.47, blue: 0.55)
    @Published var tintB = Color(red: 0.22, green: 0.22, blue: 0.30)
    @Published var lyricsOpen = false
    @Published var lyricsState = LyricsState.idle
    @Published var lyricsMessage = "No lyrics found for this song."
    @Published var syncedLines: [LyricLine] = []
    @Published var plainLines: [String] = []
    @Published var activeLine = -1
    @Published var connection = Connection.notRunning
    @Published private(set) var current: Track?

    let clock = PlaybackClock()

    private var lyricsTask: Task<Void, Never>?
    private var lastTrackID = ""
    @Published var debugNote = ""
    private var holdPlayState = Date.distantPast
    private var anchorPos = 0.0
    private var anchorDate = Date()

    init() {
        // first poll slightly later so the window is on screen before any permission prompt
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
            Task { @MainActor in self?.poll() }
        }
        // .common run-loop mode keeps these alive while the window is being dragged
        let poller = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.poll() }
        }
        let ticker = Timer(timeInterval: 0.25, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.extrapolate() }
        }
        RunLoop.main.add(poller, forMode: .common)
        RunLoop.main.add(ticker, forMode: .common)
    }

    // MARK: Messages / actions for the "not connected" states
    var message: String {
        switch connection {
        case .notInstalled: return "Spotify isn't installed"
        case .notRunning: return "Spotify isn't running"
        case .needsPermission: return "Allow Vinyl to control Spotify"
        case .connected: return debugNote.isEmpty ? "Play a song in Spotify" : "Spotify error \(debugNote)"
        }
    }

    var actionLabel: String? {
        switch connection {
        case .notInstalled: return "Get Spotify"
        case .notRunning: return "Open Spotify"
        case .needsPermission: return "Open Settings"
        case .connected: return nil
        }
    }

    func performAction() {
        switch connection {
        case .notInstalled: SpotifyBridge.openDownloadPage()
        case .notRunning: SpotifyBridge.launch()
        case .needsPermission: SpotifyBridge.openAutomationSettings()
        case .connected: break
        }
    }

    private func setConnection(_ c: Connection) {
        if connection != c { connection = c }
    }

    // MARK: Polling
    private func poll() {
        guard SpotifyBridge.isInstalled else { setConnection(.notInstalled); reset(); return }
        guard SpotifyBridge.isRunning else { setConnection(.notRunning); reset(); return }

        // Reading Spotify is also what makes macOS show the "control Spotify" prompt,
        // so there is no separate permission step that could get stuck.
        switch SpotifyBridge.readState() {
        case .playing(let s):
            setNote("")
            apply(s)
        case .stopped:
            setNote("")
            setConnection(.connected)
            if isPlaying, Date() > holdPlayState { isPlaying = false }
        case .failed(let code):
            NSLog("Vinyl readState failed: %d", code)
            if code == -1743 {              // permission denied
                setConnection(.needsPermission)
            } else {                        // Spotify still starting, timeout, etc.: retry next second
                if connection == .notRunning || connection == .notInstalled { setConnection(.connected) }
                if connection == .connected { setNote("\(code)") }
            }
        }
    }

    private func setNote(_ s: String) {
        if debugNote != s { debugNote = s }
    }

    /// Smooths the clock between the once-per-second polls so lyrics stay in sync.
    private func extrapolate() {
        guard isPlaying, current != nil, connection == .connected else { return }
        var t = anchorPos + Date().timeIntervalSince(anchorDate)
        if duration > 0 { t = min(t, duration) }
        tick(t)
    }

    /// Spotify quit or isn't available: go back to the idle state.
    private func reset() {
        setNote("")
        if isPlaying { isPlaying = false }
        guard current != nil else { return }
        current = nil
        lastTrackID = ""
        lyricsTask?.cancel()
        lyricsState = .idle
        syncedLines = []; plainLines = []; activeLine = -1
        duration = 0
        clock.time = 0
        updateTint(nil)
    }

    private func apply(_ s: SpotifyBridge.State) {
        setConnection(.connected)
        if s.trackID != lastTrackID || current == nil { newTrack(s) }
        if duration != s.duration { duration = s.duration }
        if Date() > holdPlayState, isPlaying != s.playing { isPlaying = s.playing }
        anchorPos = s.position
        anchorDate = Date()
        tick(s.position)
    }

    private func newTrack(_ s: SpotifyBridge.State) {
        lastTrackID = s.trackID
        let t = Track(title: s.isAd ? "Advertisement" : (s.title.isEmpty ? "Unknown track" : s.title),
                      artist: s.isAd ? "Spotify" : s.artist,
                      album: s.isAd ? "" : s.album,
                      artwork: nil,
                      duration: s.duration)
        current = t
        activeLine = -1

        if s.isAd {
            setNoLyrics("Lyrics are paused during ads")
        } else if s.isEpisode {
            setNoLyrics("Lyrics aren't available for podcasts")
        } else {
            fetchLyrics(t)
        }
        loadArtwork(s.artworkURL, trackID: s.trackID)
    }

    private func loadArtwork(_ urlString: String, trackID: String) {
        guard urlString.hasPrefix("http"), let url = URL(string: urlString) else {
            updateTint(nil)
            return
        }
        Task {
            guard let (data, _) = try? await URLSession.shared.data(from: url),
                  let img = NSImage(data: data) else { return }
            guard lastTrackID == trackID, let old = current else { return }
            current = Track(title: old.title, artist: old.artist, album: old.album,
                            artwork: img, duration: old.duration)
            updateTint(img)
        }
    }

    // MARK: Transport
    func toggle() {
        // Only bounce to Settings / download page / launch when Spotify genuinely can't be controlled.
        if connection == .notInstalled || connection == .needsPermission || !SpotifyBridge.isRunning {
            performAction()
            return
        }
        isPlaying.toggle()
        holdPlayState = Date().addingTimeInterval(1.0)   // don't let a stale poll flip it back
        SpotifyBridge.command("playpause")
    }

    func next() { SpotifyBridge.command("next track") }

    func previous() {
        if clock.time > 3 { seek(0) } else { SpotifyBridge.command("previous track") }
    }

    func seek(_ fraction: Double) {
        guard duration > 0 else { return }
        let t = min(max(fraction, 0), 1) * duration
        SpotifyBridge.seek(to: t)
        anchorPos = t
        anchorDate = Date()
        tick(t)
    }

    private func tick(_ s: Double) {
        guard s.isFinite else { return }
        clock.time = s
        if lyricsState == .synced {
            let i = syncedLines.lastIndex { $0.time <= s } ?? -1
            if i != activeLine { activeLine = i }
        }
    }

    // MARK: Colors from album art
    private func updateTint(_ image: NSImage?) {
        guard let image, let c = Self.averageColor(image) else {
            tintA = Color(red: 0.47, green: 0.47, blue: 0.55)
            tintB = Color(red: 0.22, green: 0.22, blue: 0.30)
            return
        }
        tintA = Color(red: c.r, green: c.g, blue: c.b)
        tintB = Color(red: c.r * 0.4, green: c.g * 0.4, blue: c.b * 0.4)
    }

    static func averageColor(_ image: NSImage) -> (r: Double, g: Double, b: Double)? {
        guard let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
        var px = [UInt8](repeating: 0, count: 4)
        guard let ctx = CGContext(data: &px, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
                                  space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        ctx.interpolationQuality = .medium
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: 1, height: 1))
        return (Double(px[0]) / 255, Double(px[1]) / 255, Double(px[2]) / 255)
    }

    // MARK: Lyrics
    private func setNoLyrics(_ message: String) {
        lyricsTask?.cancel()
        syncedLines = []; plainLines = []
        lyricsMessage = message
        lyricsState = .none
    }

    private func fetchLyrics(_ t: Track) {
        lyricsTask?.cancel()
        lyricsState = .loading
        syncedLines = []; plainLines = []
        lyricsTask = Task {
            let r = await LyricsService.fetch(title: t.title, artist: t.artist, duration: t.duration)
            if Task.isCancelled { return }
            if let s = r?.syncedLyrics, !s.isEmpty {
                syncedLines = LyricsService.parseLRC(s); lyricsState = .synced
            } else if let p = r?.plainLyrics, !p.isEmpty {
                plainLines = p.components(separatedBy: "\n"); lyricsState = .plain
            } else {
                setNoLyrics("No lyrics found for this song.")
            }
        }
    }
}
