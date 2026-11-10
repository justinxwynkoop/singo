import MusicKit
import SwiftUI

/// What's behind the game screen: plain black, a glow in the playlist's
/// color, or slowly drifting colored light. Always dark enough for the
/// white text on top to stay readable.
struct GameBackground: View {
    let style: BackgroundStyle
    let playlistArtwork: Artwork?

    var body: some View {
        ZStack {
            Color.black
            switch style {
            case .black:
                EmptyView()
            case .playlistColor:
                PlaylistGlow(color: playlistColor)
            case .animated:
                DriftingLights(colors: animatedColors)
            }
        }
        .ignoresSafeArea()
    }

    /// The playlist art's main color, or a deep purple if it has none.
    private var playlistColor: Color {
        if let cgColor = playlistArtwork?.backgroundColor {
            return Color(cgColor: cgColor)
        }
        return Color(red: 0.35, green: 0.2, blue: 0.6)
    }

    private var animatedColors: [Color] {
        [
            playlistColor,
            Color(red: 0.45, green: 0.15, blue: 0.75),  // purple
            Color(red: 0.1, green: 0.35, blue: 0.85),   // blue
            Color(red: 0.05, green: 0.6, blue: 0.6),    // teal
            Color(red: 0.8, green: 0.2, blue: 0.5),     // pink
        ]
    }
}

/// A still, soft glow in one color coming from the top of the screen.
private struct PlaylistGlow: View {
    let color: Color

    var body: some View {
        ZStack {
            RadialGradient(colors: [color.opacity(0.55), .clear],
                           center: .top, startRadius: 0, endRadius: 1100)
            RadialGradient(colors: [color.opacity(0.25), .clear],
                           center: .bottomTrailing, startRadius: 0, endRadius: 900)
        }
    }
}

/// Big soft circles of colored light that slowly wander around the screen.
private struct DriftingLights: View {
    let colors: [Color]

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height
                ZStack {
                    ForEach(colors.indices, id: \.self) { i in
                        let speed = 0.04 + Double(i) * 0.013
                        let phase = Double(i) * 1.9
                        let x = w / 2 + cos(t * speed + phase) * w * 0.38
                        let y = h / 2 + sin(t * speed * 1.3 + phase * 0.7) * h * 0.38
                        Circle()
                            .fill(RadialGradient(colors: [colors[i].opacity(0.5), .clear],
                                                 center: .center, startRadius: 0, endRadius: 520))
                            .frame(width: 1040, height: 1040)
                            .position(x: x, y: y)
                    }
                }
            }
        }
        .overlay(Color.black.opacity(0.25))
    }
}
