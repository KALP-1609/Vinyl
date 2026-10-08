import AppKit
import CoreServices

/// Talks to the Spotify desktop app through macOS AppleScript.
/// NSAppleScript is only safe on the main thread, so every script call happens there
/// (each call is a few milliseconds and has a 2 second timeout).
enum SpotifyBridge {
    static let bundleID = "com.spotify.client"

    struct State {
        var title: String
        var artist: String
        var album: String
        var artworkURL: String
        var duration: Double   // seconds
        var position: Double   // seconds
        var playing: Bool
        var trackID: String

        var isAd: Bool { trackID.hasPrefix("spotify:ad:") }
        var isEpisode: Bool { trackID.hasPrefix("spotify:episode:") }
    }

    enum Read {
        case playing(State)
        case stopped
        case failed(Int)
    }

    // MARK: App state
    static var installedURL: URL? { NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) }
    static var isInstalled: Bool { installedURL != nil }
    static var isRunning: Bool { !NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).isEmpty }

    static func launch() {
        guard let url = installedURL else { openDownloadPage(); return }
        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration()) { _, _ in }
    }

    static func openDownloadPage() {
        NSWorkspace.shared.open(URL(string: "https://www.spotify.com/download")!)
    }

    static func openAutomationSettings() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation")!)
    }

    // MARK: Permission (Automation)
    private static let permissionQueue = DispatchQueue(label: "vinyl.permission")

    /// 0 = allowed, -1743 = denied, -1744 = not asked yet. With prompt == true macOS shows its
    /// permission dialog. Runs off the main thread because the call blocks while the dialog is up.
    static func permission(prompt: Bool) async -> Int {
        await withCheckedContinuation { cont in
            permissionQueue.async {
                let target = NSAppleEventDescriptor(bundleIdentifier: bundleID)
                let status = AEDeterminePermissionToAutomateTarget(target.aeDesc, typeWildCard, typeWildCard, prompt)
                cont.resume(returning: Int(status))
            }
        }
    }

    // MARK: Reading state
    private static let stateScript: NSAppleScript? = {
        let source = """
        with timeout of 2 seconds
            tell application id "com.spotify.client"
                if player state is stopped then return "STOPPED"
                set sep to (ASCII character 31)
                set t to current track
                set tName to ""
                set tArtist to ""
                set tAlbum to ""
                set tArt to ""
                set tID to ""
                set dur to 0
                set pos to 0
                try
                    set tName to name of t
                end try
                try
                    set tArtist to artist of t
                end try
                try
                    set tAlbum to album of t
                end try
                try
                    set a to artwork url of t
                    if a is not missing value then set tArt to a as text
                end try
                try
                    set tID to id of t
                end try
                try
                    set dur to duration of t
                end try
                try
                    set pos to player position
                end try
                return tName & sep & tArtist & sep & tAlbum & sep & tArt & sep & (dur as text) & sep & (pos as text) & sep & (player state as text) & sep & tID
            end tell
        end timeout
        """
        let s = NSAppleScript(source: source)
        var err: NSDictionary?
        s?.compileAndReturnError(&err)
        return s
    }()

    static func readState() -> Read {
        guard let script = stateScript else { return .failed(-1) }
        var err: NSDictionary?
        let out = script.executeAndReturnError(&err)
        if let err { return .failed((err[NSAppleScript.errorNumber] as? Int) ?? -1) }
        guard let s = out.stringValue else { return .failed(-2) }
        if s == "STOPPED" { return .stopped }

        let p = s.components(separatedBy: "\u{1F}")
        guard p.count >= 8 else { return .failed(-3) }
        func num(_ x: String) -> Double { Double(x.replacingOccurrences(of: ",", with: ".")) ?? 0 }
        return .playing(State(title: p[0], artist: p[1], album: p[2], artworkURL: p[3],
                              duration: num(p[4]) / 1000,
                              position: num(p[5]),
                              playing: p[6].lowercased().contains("playing"),
                              trackID: p[7]))
    }

    // MARK: Commands
    static func command(_ c: String) {
        guard isRunning else { return }   // never accidentally launch Spotify
        var err: NSDictionary?
        _ = NSAppleScript(source: "with timeout of 2 seconds\ntell application id \"\(bundleID)\" to \(c)\nend timeout")?
            .executeAndReturnError(&err)
    }

    static func seek(to seconds: Double) {
        command("set player position to \(String(format: "%.2f", seconds))")
    }
}
