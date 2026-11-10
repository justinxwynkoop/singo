import MusicKit
import SwiftUI

/// The game screen: black background, album-art disc in the middle with the
/// countdown below it, hints around it, then the reveal.
///
/// Remote:
/// - Play/Pause button: pause or resume
/// - Menu/Back button: asks whether to end the round
/// - Buttons along the bottom: Replay, add time, Called songs, Skip/Next
struct RoundView: View {
    @Bindable var controller: GameController
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @FocusState private var focus: Control?
    @State private var confirmingEnd = false

    enum Control: Hashable { case replay, addTime, called, skip }

    private var engine: RoundEngine { controller.engine }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if engine.phase == .finished {
                finished
            } else {
                stage
            }
        }
        .defaultFocus($focus, .called)
        .onAppear {
            controller.begin()
            focus = .called
        }
        .onDisappear { controller.end() }
        .onPlayPauseCommand { controller.togglePause() }
        .onExitCommand {
            if engine.phase == .finished {
                dismiss()
            } else {
                controller.holdPause()
                confirmingEnd = true
            }
        }
        .alert("End this round?", isPresented: $confirmingEnd) {
            Button("End round", role: .destructive) { dismiss() }
            Button("Keep playing", role: .cancel) { controller.releasePause() }
        }
        .fullScreenCover(isPresented: $controller.showingCalledList, onDismiss: controller.calledListClosed) {
            CalledSongsView(controller: controller)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { controller.setPaused(true) }
        }
    }

    // MARK: - Playing and reveal
    //
    // Layout: title across the top, the album-art disc in the middle with the
    // countdown below it, genre and year to its left, artist to its right.

    private var stage: some View {
        let song = controller.currentSong
        let revealed = engine.phase == .revealed
        return VStack(spacing: 0) {
            HStack {
                Text("Song \(engine.songNumber) of \(engine.songs.count)")
                Spacer()
                if engine.isPaused {
                    Label("Paused", systemImage: "pause.fill")
                }
            }
            .font(.system(size: 28, weight: .medium))
            .foregroundStyle(.white.opacity(0.4))

            titleArea
                .frame(maxWidth: .infinity)
                .frame(height: 200)

            HStack(alignment: .center, spacing: 70) {
                VStack(alignment: .trailing, spacing: 70) {
                    HintLine(label: "Genre", alignment: .trailing, visible: engine.isShowing(.genre)) {
                        HintText(song?.genre ?? "Not listed", alignment: .trailing)
                    }
                    HintLine(label: "Year", alignment: .trailing, visible: engine.isShowing(.year)) {
                        HintText(song?.releaseYear.map(String.init) ?? "Not listed", alignment: .trailing)
                    }
                }
                .frame(width: 480, alignment: .trailing)

                DiscView(
                    progress: engine.progress,
                    artwork: song.flatMap { controller.artwork(for: $0.id) },
                    showArt: engine.isShowing(.art),
                    sharpness: engine.artSharpness,
                    dimmed: engine.isPaused,
                    revealed: revealed
                )

                HintLine(label: "Artist", alignment: .leading, visible: engine.isShowing(.artist)) {
                    HintText(song?.artistName ?? "", alignment: .leading)
                }
                .frame(width: 480, alignment: .leading)
            }

            Text(statusLine)
                .font(.system(size: 34, weight: .medium).monospacedDigit())
                .foregroundStyle(.white.opacity(0.55))
                .frame(height: 48)
                .padding(.top, 24)

            Spacer(minLength: 10)

            if let notice = controller.notice {
                Text(notice)
                    .font(.system(size: 26))
                    .foregroundStyle(.yellow.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 20)
            }

            controls
        }
        .padding(.horizontal, 40)
        .animation(.easeInOut(duration: 0.6), value: engine.phase)
    }

    /// The title hint while playing; the real title (big) after the reveal.
    @ViewBuilder
    private var titleArea: some View {
        if engine.phase == .revealed {
            VStack(spacing: 10) {
                if let number = engine.called.last?.number {
                    Text("CALLED #\(number)")
                        .font(.system(size: 24, weight: .semibold))
                        .tracking(3)
                        .foregroundStyle(.white.opacity(0.45))
                }
                Text(controller.currentSong?.title ?? "")
                    .font(.system(size: 72, weight: .bold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.5)
            }
            .transition(.opacity)
        } else {
            HintLine(label: "Title", alignment: .center, visible: engine.isShowing(.title)) {
                TitleBlanks(words: engine.titleHint,
                            showBlanks: engine.settings.titleHintStyle.showsBlanks)
            }
        }
    }

    private var statusLine: String {
        if controller.isBuffering { return "Loading…" }
        switch engine.phase {
        case .playing:
            let left = Int(engine.remaining.rounded(.up))
            return String(format: "%d:%02d", left / 60, left % 60)
        case .finished:
            return ""
        case .revealed:
            guard engine.settings.autoAdvance else { return "Press Next when ready" }
            let left = Int(max(0, engine.advanceTime - engine.elapsed).rounded(.up))
            return "Next song in \(left)"
        }
    }

    private var controls: some View {
        HStack(spacing: 30) {
            Button { controller.replay() } label: {
                Label("Replay", systemImage: "arrow.counterclockwise")
            }
            .focused($focus, equals: .replay)

            Button { controller.addTime() } label: {
                Label("+\(Int(engine.settings.addTimeStep)) sec", systemImage: "plus")
            }
            .focused($focus, equals: .addTime)

            Button { controller.openCalledList() } label: {
                CalledSongsLabel(count: engine.called.count)
            }
            .focused($focus, equals: .called)

            Button { controller.skip() } label: {
                Label(engine.phase == .revealed ? "Next" : "Skip", systemImage: "forward.end.fill")
            }
            .focused($focus, equals: .skip)
        }
        .buttonStyle(HostButtonStyle())
    }

    // MARK: - End of round

    private var finished: some View {
        VStack(spacing: 40) {
            Text("That's the round")
                .font(.system(size: 80, weight: .bold))
            Text("\(engine.called.count) songs called")
                .font(.title2)
                .foregroundStyle(.white.opacity(0.6))
            HStack(spacing: 30) {
                Button { controller.openCalledList() } label: {
                    CalledSongsLabel(count: engine.called.count)
                }
                .focused($focus, equals: .called)
                Button { dismiss() } label: {
                    Label("Done", systemImage: "checkmark")
                }
            }
            .buttonStyle(HostButtonStyle())
        }
        .foregroundStyle(.white)
    }
}

/// Countdown ring with the album art inside it as a circle.
private struct DiscView: View {
    let progress: Double
    let artwork: Artwork?
    let showArt: Bool
    let sharpness: Double
    let dimmed: Bool
    let revealed: Bool

    private let size: CGFloat = 440
    private var artSize: CGFloat { size - 60 }

    var body: some View {
        ZStack {
            Circle()
                .stroke(.white.opacity(0.12), lineWidth: 12)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(revealed ? Color.green : .white.opacity(dimmed ? 0.35 : 0.9),
                        style: StrokeStyle(lineWidth: 12, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 0.15), value: progress)
            art
                .frame(width: artSize, height: artSize)
                .clipShape(Circle())
                .opacity(showArt ? 1 : 0)
                .animation(.easeIn(duration: 1.5), value: showArt)
        }
        .frame(width: size, height: size)
    }

    @ViewBuilder
    private var art: some View {
        if let artwork {
            ArtworkImage(artwork, width: artSize, height: artSize)
                .blur(radius: (1 - sharpness) * 50)
                .animation(.linear(duration: 0.15), value: sharpness)
        } else {
            ZStack {
                Circle().fill(.white.opacity(0.06))
                Image(systemName: "music.note")
                    .font(.system(size: 120))
                    .foregroundStyle(.white.opacity(0.3))
            }
        }
    }
}

private struct HintLine<Content: View>: View {
    let label: String
    let alignment: HorizontalAlignment
    let visible: Bool
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: alignment, spacing: 14) {
            Text(label.uppercased())
                .font(.system(size: 24, weight: .semibold))
                .tracking(3)
                .foregroundStyle(.white.opacity(0.4))
            content
        }
        .opacity(visible ? 1 : 0)
        .animation(.easeIn(duration: 1.2), value: visible)
    }
}

private struct HintText: View {
    let text: String
    let alignment: TextAlignment

    init(_ text: String, alignment: TextAlignment) {
        self.text = text
        self.alignment = alignment
    }

    var body: some View {
        Text(text)
            .font(.system(size: 54, weight: .semibold))
            .foregroundStyle(.white)
            .multilineTextAlignment(alignment)
            .lineLimit(2)
            .minimumScaleFactor(0.6)
    }
}

/// The title as a slot per letter, e.g. "H _ _   J _ _ _". With
/// `showBlanks` off, hidden letters are empty space and letters just appear.
private struct TitleBlanks: View {
    let words: [[HintGlyph]]
    let showBlanks: Bool

    var body: some View {
        FlowLayout(spacing: 40, lineSpacing: 22, centered: true) {
            ForEach(words.indices, id: \.self) { w in
                HStack(spacing: 8) {
                    ForEach(words[w].indices, id: \.self) { g in
                        GlyphCell(glyph: words[w][g], showBlank: showBlanks)
                    }
                }
            }
        }
    }
}

private struct GlyphCell: View {
    let glyph: HintGlyph
    let showBlank: Bool

    var body: some View {
        Group {
            switch glyph {
            case .hidden:
                slot(Text(" "))
            case .shown(let character):
                slot(Text(String(character)))
            case .symbol(let character):
                Text(String(character))
                    .font(.system(size: 46, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(height: 63)
            }
        }
        .animation(.easeIn(duration: 0.5), value: glyph)
    }

    private func slot(_ text: Text) -> some View {
        VStack(spacing: 4) {
            text
                .font(.system(size: 46, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 34, height: 54)
            Capsule()
                .fill(.white.opacity(showBlank ? 0.7 : 0))
                .frame(width: 34, height: 5)
        }
    }
}

/// Lays children out left to right, wrapping to a new line when they don't
/// fit. With `centered`, each line is centered.
private struct FlowLayout: Layout {
    var spacing: CGFloat
    var lineSpacing: CGFloat
    var centered = false

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let frames = arrange(subviews, maxWidth: proposal.width ?? .infinity)
        let width = frames.map(\.maxX).max() ?? 0
        let height = frames.map(\.maxY).max() ?? 0
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let frames = arrange(subviews, maxWidth: bounds.width)
        for (subview, frame) in zip(subviews, frames) {
            subview.place(at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY),
                          proposal: ProposedViewSize(frame.size))
        }
    }

    private func arrange(_ subviews: Subviews, maxWidth: CGFloat) -> [CGRect] {
        var rows: [[CGRect]] = [[]]
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + size.width > maxWidth {
                x = 0
                y += rowHeight + lineSpacing
                rowHeight = 0
                rows.append([])
            }
            rows[rows.count - 1].append(CGRect(origin: CGPoint(x: x, y: y), size: size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        guard centered else { return rows.flatMap { $0 } }

        // Center each line within the widest line (or the available width).
        let widest = rows.map { $0.last?.maxX ?? 0 }.max() ?? 0
        let width = maxWidth.isFinite ? maxWidth : widest
        return rows.flatMap { row -> [CGRect] in
            let shift = (width - (row.last?.maxX ?? 0)) / 2
            return row.map { $0.offsetBy(dx: max(shift, 0), dy: 0) }
        }
    }
}

/// "Called songs" with the count in a badge that's easy to read across the room.
struct CalledSongsLabel: View {
    let count: Int

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: "list.number")
            Text("Called songs")
            Text("\(count)")
                .font(.system(size: 30, weight: .bold).monospacedDigit())
                .padding(.horizontal, 14)
                .frame(minWidth: 48, minHeight: 48)
                .background(Capsule().fill(.white.opacity(0.2)))
        }
    }
}

/// Low-glare buttons so the controls don't light up the dark screen.
struct HostButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        HostButtonBody(configuration: configuration)
    }
}

private struct HostButtonBody: View {
    let configuration: ButtonStyleConfiguration
    @Environment(\.isFocused) private var isFocused

    var body: some View {
        configuration.label
            .font(.system(size: 36, weight: .semibold))
            .padding(.horizontal, 44)
            .padding(.vertical, 24)
            .foregroundStyle(.white.opacity(isFocused ? 1 : 0.6))
            .background(Capsule().fill(.white.opacity(isFocused ? 0.25 : 0.1)))
            .scaleEffect(configuration.isPressed ? 0.95 : (isFocused ? 1.06 : 1))
            .animation(.easeOut(duration: 0.15), value: isFocused)
    }
}
