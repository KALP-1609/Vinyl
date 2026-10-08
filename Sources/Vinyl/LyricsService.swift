import Foundation

struct LyricsResult: Decodable {
    let syncedLyrics: String?
    let plainLyrics: String?
}

enum LyricsService {
    private static let session: URLSession = {
        let c = URLSessionConfiguration.default
        c.timeoutIntervalForRequest = 8
        c.timeoutIntervalForResource = 15
        return URLSession(configuration: c)
    }()

    private static func get(_ url: URL) async -> Data? {
        var req = URLRequest(url: url)
        req.setValue("Vinyl macOS player (github.com)", forHTTPHeaderField: "User-Agent")
        guard let (data, resp) = try? await session.data(for: req),
              (resp as? HTTPURLResponse)?.statusCode == 200 else { return nil }
        return data
    }

    /// Free lyrics API: https://lrclib.net  (only the song title/artist/length are sent)
    static func fetch(title: String, artist: String, duration: Double) async -> LyricsResult? {
        var c = URLComponents(string: "https://lrclib.net/api/get")!
        c.queryItems = [URLQueryItem(name: "track_name", value: title),
                        URLQueryItem(name: "artist_name", value: artist)]
        if duration > 0 { c.queryItems?.append(URLQueryItem(name: "duration", value: String(Int(duration.rounded())))) }
        if let url = c.url, let data = await get(url),
           let r = try? JSONDecoder().decode(LyricsResult.self, from: data) { return r }

        // Fallback: search with a cleaned-up title ("Song - Remastered 2011" -> "Song")
        var s = URLComponents(string: "https://lrclib.net/api/search")!
        s.queryItems = [URLQueryItem(name: "q", value: "\(artist) \(cleaned(title))".trimmingCharacters(in: .whitespaces))]
        if let url = s.url, let data = await get(url),
           let list = try? JSONDecoder().decode([LyricsResult].self, from: data) {
            return list.first { !($0.syncedLyrics ?? "").isEmpty } ?? list.first
        }
        return nil
    }

    static func cleaned(_ title: String) -> String {
        var t = title
        let patterns = [#"\s*[-–]\s*(remaster|live|mono|stereo|radio edit|single|version|\d{4}).*$"#,
                        #"\s*\((feat|ft|with)\.?[^)]*\)"#,
                        #"\s*\[[^\]]*\]"#]
        for p in patterns {
            t = t.replacingOccurrences(of: p, with: "", options: [.regularExpression, .caseInsensitive])
        }
        return t.trimmingCharacters(in: .whitespaces)
    }

    static func parseLRC(_ text: String) -> [LyricLine] {
        guard let re = try? NSRegularExpression(pattern: #"^\[(\d+):(\d+(?:\.\d+)?)\](.*)$"#) else { return [] }
        var out: [LyricLine] = []
        for line in text.components(separatedBy: "\n") {
            let ns = line as NSString
            guard let m = re.firstMatch(in: line, range: NSRange(location: 0, length: ns.length)) else { continue }
            let min = Double(ns.substring(with: m.range(at: 1))) ?? 0
            let sec = Double(ns.substring(with: m.range(at: 2))) ?? 0
            let txt = ns.substring(with: m.range(at: 3)).trimmingCharacters(in: .whitespaces)
            out.append(LyricLine(id: out.count, time: min * 60 + sec, text: txt.isEmpty ? "♪" : txt))
        }
        return out
    }
}
