import SwiftUI
import AppKit
import Combine

// MARK: - Root
struct ContentView: View {
    @EnvironmentObject var model: PlayerModel

    var body: some View {
        ZStack(alignment: .leading) {
            PlayerPane()
                .frame(width: 340)
            if model.lyricsOpen {
                LyricsPane()
                    .frame(width: 340)
                    .offset(x: 340)
                    .transition(.opacity)
            }
        }
        .frame(minWidth: 340, maxWidth: .infinity, minHeight: 480, maxHeight: .infinity, alignment: .leading)
        .background(
            GlassBackground(artwork: model.current?.artwork,
                            tintA: model.tintA, tintB: model.tintB,
                            token: model.current?.id)
                .equatable()
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(LinearGradient(colors: [.white.opacity(0.45), .white.opacity(0.08)],
                                             startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
        )
        .animation(.spring(response: 0.5, dampingFraction: 0.85), value: model.lyricsOpen)
        .background(WindowConfigurator(lyricsOpen: model.lyricsOpen))
        .ignoresSafeArea()
        .preferredColorScheme(.dark)
    }
}

// MARK: - Glass + album-art background (cached: only redraws when the song changes)
struct VisualEffect: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .hudWindow
    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.material = material
        v.blendingMode = .behindWindow
        v.state = .active
        return v
    }
    func updateNSView(_ v: NSVisualEffectView, context: Context) { v.material = material }
}

struct GlassBackground: View, Equatable {
    let artwork: NSImage?
    let tintA: Color
    let tintB: Color
    let token: UUID?

    static func == (l: GlassBackground, r: GlassBackground) -> Bool {
        l.artwork === r.artwork && l.tintA == r.tintA && l.tintB == r.tintB && l.token == r.token
    }

    var body: some View {
        ZStack {
            VisualEffect()
            if let art = artwork {
                // Fixed size (full lyrics width) so resizing the window never re-renders the blur
                Image(nsImage: art).resizable().scaledToFill()
                    .frame(width: 680, height: 480)
                    .clipped()
                    .blur(radius: 40)
                    .saturation(1.8)
                    .scaleEffect(1.15)
                    .opacity(0.75)
                    .drawingGroup()
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                    .clipped()
            }
            LinearGradient(colors: [tintA.opacity(0.55), tintB.opacity(0.75)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            LinearGradient(colors: [.white.opacity(0.18), .clear], startPoint: .topLeading, endPoint: .center)
        }
        .animation(.easeInOut(duration: 0.9), value: token)
    }
}

// MARK: - Player pane
struct PlayerPane: View {
    @EnvironmentObject var model: PlayerModel

    var body: some View {
        VStack(spacing: 0) {
            Turntable()
                .frame(width: 296, height: 260)
                .padding(.top, 38)

            VStack(spacing: 2) {
                Text(model.current?.title ?? "Vinyl")
                    .font(.system(size: 17, weight: .semibold))
                    .lineLimit(1)
                Text(subtitle)
                    .font(.system(size: 13))
                    .opacity(0.75)
                    .lineLimit(1)
            }
            .padding(.top, 12)
            .padding(.horizontal, 22)

            if model.current == nil, let label = model.actionLabel {
                PillButton(title: label) { model.performAction() }
                    .padding(.top, 8)
            }

            ProgressRow(clock: model.clock)
                .padding(.horizontal, 22)
                .padding(.top, 10)

            HStack(spacing: 16) {
                GlassButton(symbol: "backward.fill") { model.previous() }
                GlassButton(symbol: model.isPlaying ? "pause.fill" : "play.fill", size: 46) { model.toggle() }
                GlassButton(symbol: "forward.fill") { model.next() }
                GlassButton(symbol: "text.quote", active: model.lyricsOpen) { model.lyricsOpen.toggle() }
            }
            .padding(.top, 14)

            Spacer(minLength: 0)
        }
        .foregroundStyle(.white)
    }

    var subtitle: String {
        guard let t = model.current else { return model.message }
        let s = [t.artist, t.album].filter { !$0.isEmpty }.joined(separator: " · ")
        return s.isEmpty ? "Unknown artist" : s
    }
}

/// Only this small view redraws as the song plays.
struct ProgressRow: View {
    @EnvironmentObject var model: PlayerModel
    @ObservedObject var clock: PlaybackClock

    var body: some View {
        HStack(spacing: 8) {
            Text(fmt(clock.time)).font(.system(size: 10).monospacedDigit())
            Slider(value: Binding(get: { model.duration > 0 ? min(clock.time / model.duration, 1) : 0 },
                                  set: { model.seek($0) }))
                .controlSize(.mini)
                .tint(.white)
            Text(fmt(model.duration)).font(.system(size: 10).monospacedDigit())
        }
        .opacity(0.9)
        .foregroundStyle(.white)
    }

    func fmt(_ s: Double) -> String {
        guard s.isFinite else { return "0:00" }
        return String(format: "%d:%02d", Int(s) / 60, Int(s) % 60)
    }
}

struct GlassButton: View {
    let symbol: String
    var size: CGFloat = 38
    var active = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: size * 0.38, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: size, height: size)
                .background(.ultraThinMaterial, in: Circle())
                .background(Circle().fill(.white.opacity(active ? 0.35 : 0.1)))
                .overlay(Circle().strokeBorder(.white.opacity(0.3), lineWidth: 0.8))
                .shadow(color: .black.opacity(0.2), radius: 6, y: 3)
        }
        .buttonStyle(PressStyle())
    }
}

struct PillButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(.ultraThinMaterial, in: Capsule())
                .background(Capsule().fill(.white.opacity(0.12)))
                .overlay(Capsule().strokeBorder(.white.opacity(0.3), lineWidth: 0.8))
        }
        .buttonStyle(PressStyle())
    }
}

struct PressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.9 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

// MARK: - Turntable (record + needle)
struct Turntable: View {
    @EnvironmentObject var model: PlayerModel

    var body: some View {
        ZStack(alignment: .topLeading) {
            SpinningRecord(artwork: model.current?.artwork, playing: model.isPlaying)
                .frame(width: 240, height: 240)
                .offset(x: 6, y: 8)

            Tonearm(down: model.isPlaying) { model.toggle() }
                .frame(width: 60, height: 190)
                .offset(x: 228, y: -2)
        }
    }
}

/// The record face is drawn once and cached; only a rotation is applied each frame.
struct SpinningRecord: View {
    let artwork: NSImage?
    let playing: Bool

    @State private var base = 0.0
    @State private var start: Date?
    private let degreesPerSecond = 72.0   // one turn every 5 seconds

    var body: some View {
        ZStack {
            Circle().fill(.black)
                .shadow(color: .black.opacity(0.5), radius: 16, y: 12)

            TimelineView(.animation(minimumInterval: nil, paused: !playing)) { ctx in
                let extra = start.map { max(0, ctx.date.timeIntervalSince($0)) * degreesPerSecond } ?? 0
                RecordFace(artwork: artwork)
                    .equatable()
                    .drawingGroup()
                    .rotationEffect(.degrees(base + extra))
            }

            // light reflection stays still while the record spins
            Circle().fill(AngularGradient(
                stops: [.init(color: .clear, location: 0.0),
                        .init(color: .white.opacity(0.16), location: 0.1),
                        .init(color: .clear, location: 0.2),
                        .init(color: .clear, location: 0.5),
                        .init(color: .white.opacity(0.12), location: 0.62),
                        .init(color: .clear, location: 0.72)],
                center: .center, angle: .degrees(20)))
                .allowsHitTesting(false)
        }
        .overlay(Circle().strokeBorder(.white.opacity(0.08), lineWidth: 2))
        .onChange(of: playing) { _, isOn in
            if isOn {
                start = Date().addingTimeInterval(0.6)   // begin spinning once the needle lands
            } else if let s = start {
                base = (base + max(0, Date().timeIntervalSince(s)) * degreesPerSecond)
                    .truncatingRemainder(dividingBy: 360)
                start = nil
            }
        }
    }
}

struct RecordFace: View, Equatable {
    let artwork: NSImage?

    static func == (l: RecordFace, r: RecordFace) -> Bool { l.artwork === r.artwork }

    var body: some View {
        ZStack {
            Circle().fill(Color(white: 0.07))
            ForEach(0..<16, id: \.self) { i in
                Circle()
                    .strokeBorder(.white.opacity(i % 3 == 0 ? 0.07 : 0.035), lineWidth: 1)
                    .padding(CGFloat(i) * 5 + 3)
            }
            // album art on the record
            Group {
                if let art = artwork {
                    Image(nsImage: art).resizable().scaledToFill()
                } else {
                    LinearGradient(colors: [Color(white: 0.35), Color(white: 0.18)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                }
            }
            .frame(width: 136, height: 136)
            .clipShape(Circle())
            .overlay(Circle().strokeBorder(.black.opacity(0.6), lineWidth: 3))
            Circle().fill(Color(white: 0.05)).frame(width: 12, height: 12)
                .overlay(Circle().strokeBorder(.white.opacity(0.25), lineWidth: 1.5))
        }
    }
}

struct Tonearm: View {
    let down: Bool
    let action: () -> Void
    @State private var hover = false

    var body: some View {
        ZStack(alignment: .topLeading) {
            Capsule()
                .fill(LinearGradient(colors: [Color(white: 0.8), .white, Color(white: 0.6)],
                                     startPoint: .leading, endPoint: .trailing))
                .frame(width: 6, height: 150).offset(x: 27, y: 22)
            RoundedRectangle(cornerRadius: 4)
                .fill(LinearGradient(colors: [Color(white: 0.92), Color(white: 0.55)],
                                     startPoint: .top, endPoint: .bottom))
                .frame(width: 20, height: 30).offset(x: 20, y: 160)
            Circle()
                .fill(RadialGradient(colors: [.white, Color(white: 0.55)], center: .topLeading, startRadius: 2, endRadius: 30))
                .frame(width: 36, height: 36).offset(x: 12, y: 4)
        }
        .shadow(color: .black.opacity(0.4), radius: 4, y: 3)
        .brightness(hover ? 0.12 : 0)
        .rotationEffect(.degrees(down ? 14 : -24), anchor: UnitPoint(x: 0.5, y: 22.0 / 190.0))
        .animation(.timingCurve(0.4, 0, 0.2, 1, duration: 0.8), value: down)
        .contentShape(Rectangle())
        .onHover { hover = $0 }
        .onTapGesture(perform: action)
        .help("Click the needle to play / pause")
    }
}

// MARK: - Lyrics pane
struct LyricsPane: View {
    @EnvironmentObject var model: PlayerModel

    var body: some View {
        Group {
            switch model.lyricsState {
            case .idle: message("Lyrics will appear here.")
            case .loading: message("Searching for lyrics…")
            case .none: message(model.lyricsMessage)
            case .plain:
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(Array(model.plainLines.enumerated()), id: \.offset) { _, l in
                            Text(l.isEmpty ? " " : l).font(.system(size: 15, weight: .semibold)).opacity(0.85)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 60)
                }
            case .synced:
                ScrollViewReader { proxy in
                    ScrollView(showsIndicators: false) {
                        LazyVStack(alignment: .leading, spacing: 16) {
                            Spacer().frame(height: 140)
                            ForEach(model.syncedLines) { line in
                                LyricRow(text: line.text, active: line.id == model.activeLine)
                                    .id(line.id)
                                    .onTapGesture { model.seek(line.time / max(model.duration, 1)) }
                            }
                            Spacer().frame(height: 140)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .onChange(of: model.activeLine) { _, new in
                        withAnimation(.easeInOut(duration: 0.5)) { proxy.scrollTo(new, anchor: .center) }
                    }
                }
            }
        }
        .foregroundStyle(.white)
        .padding(.leading, 6)
        .padding(.trailing, 24)
        .padding(.top, 40)
        .padding(.bottom, 20)
        .mask(LinearGradient(stops: [.init(color: .clear, location: 0), .init(color: .black, location: 0.14),
                                     .init(color: .black, location: 0.86), .init(color: .clear, location: 1)],
                             startPoint: .top, endPoint: .bottom))
    }

    func message(_ s: String) -> some View {
        VStack { Text(s).font(.system(size: 14)).opacity(0.6).padding(.top, 60); Spacer() }
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct LyricRow: View, Equatable {
    let text: String
    let active: Bool

    var body: some View {
        Text(text)
            .font(.system(size: 20, weight: .bold))
            .opacity(active ? 1 : 0.35)
            .scaleEffect(active ? 1.04 : 1, anchor: .leading)
            .animation(.easeOut(duration: 0.3), value: active)
    }
}
