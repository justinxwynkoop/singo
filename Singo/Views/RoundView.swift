import MusicKit
import SwiftUI

/// The game screen: black background, countdown ring, hints, reveal.
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
        .sheet(isPresented: $controller.showingCalledList, onDismiss: controller.calledListClosed) {
            CalledSongsView(controller: controller)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { controller.setPaused(true) }
        }
    }

    // MARK: - Playing and reveal

    private var stage: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Song \(engine.songNumber) of \(engine.songs.count)")
                Spacer()
                if engine.isPaused {
                    Label("Paused", systemImage: "pause.fill")
                }
            }
            .font(.system(size: 28, weight: .medium))
            .foregroundStyle(.white.opacity(0.4))

            Spacer()

            HStack(alignment: .center, spacing: 100) {
                VStack(spacing: 36) {
                    DiscView(
                        progress: engine.progress,
                        artwork: engine.currentSong.flatMap { controller.artwork(for: $0.id) },
                        showArt: engine.isShowing(.art),
                        sharpness: engine.artSharpness,
                        dimmed: engine.isPaused
                    )
                    Text(statusLine)
                        .font(.system(size: 34, weight: .medium).monospacedDigit())
                        .foregroundStyle(.white.opacity(0.55))
                }

                Group {
                    if engine.phase == .revealed {
                        revealText
                    } else {
                        hints
                    }
                }
                .frame(width: 860, alignment: .leading)
            }
            .animation(.easeInOut(duration: 0.6), value: engine.phase)

            Spacer()

            if let notice = controller.notice {
                Text(notice)
                    .font(.system(size: 26))
                    .foregroundStyle(.yellow.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 24)
            }

            controls
        }
        .padding(.horizontal, 40)
    }

    private var statusLine: String {
        if controller.isBuffering { return "Loading…" }
        switch engine.phase {
        case .playing:
            let left = Int(engine.remaining.rounded(.up))
            return String(format: "%d:%02d", left / 60, left % 60)
        case .revealed:
            guard engine.settings.autoAdvance else { return "Press Next when ready" }
            let left = Int(max(0, engine.advanceTime - engine.elapsed).rounded(.up))
            return "Next song in \(left)"
        case .finished:
            return ""
        }
    }

    private var hints: some View {
        let song = controller.currentSong
        return VStack(alignment: .leading, spacing: 56) {
            HintLine(label: "Genre · Year", value: song?.genreAndYear ?? "Not listed",
                     visible: engine.isShowing(.genreAndYear))
            HintLine(label: "Title", value: engine.titleHint ?? "",
                     visible: engine.isShowing(.title))
            HintLine(label: "Artist", value: song?.artistName ?? "",
                     visible: engine.isShowing(.artist))
        }
    }

    private var revealText: some View {
        let song = controller.currentSong
        return VStack(alignment: .leading, spacing: 20) {
            if let number = engine.called.last?.number {
                Text("Called #\(number)")
                    .font(.system(size: 26, weight: .semibold))
                    .tracking(3)
                    .foregroundStyle(.white.opacity(0.4))
            }
            Text(song?.title ?? "")
                .font(.system(size: 76, weight: .bold))
                .lineLimit(3)
                .minimumScaleFactor(0.5)
            Text(song?.artistName ?? "")
                .font(.system(size: 46, weight: .medium))
                .foregroundStyle(.white.opacity(0.75))
            if let detail = song?.genreAndYear {
                Text(detail)
                    .font(.system(size: 32))
                    .foregroundStyle(.white.opacity(0.45))
            }
        }
        .foregroundStyle(.white)
        .transition(.opacity)
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
                Label("Called songs (\(engine.called.count))", systemImage: "list.number")
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
                    Label("Called songs", systemImage: "list.number")
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

    private let size: CGFloat = 500
    private var artSize: CGFloat { size - 70 }

    var body: some View {
        ZStack {
            Circle()
                .stroke(.white.opacity(0.12), lineWidth: 12)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(.white.opacity(dimmed ? 0.35 : 0.9),
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

private struct HintLine: View {
    let label: String
    let value: String
    let visible: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(label.uppercased())
                .font(.system(size: 24, weight: .semibold))
                .tracking(3)
                .foregroundStyle(.white.opacity(0.4))
            Text(value)
                .font(.system(size: 54, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(2)
                .minimumScaleFactor(0.6)
        }
        .opacity(visible ? 1 : 0)
        .animation(.easeIn(duration: 1.2), value: visible)
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
            .font(.system(size: 28, weight: .semibold))
            .padding(.horizontal, 36)
            .padding(.vertical, 18)
            .foregroundStyle(.white.opacity(isFocused ? 1 : 0.4))
            .background(Capsule().fill(.white.opacity(isFocused ? 0.25 : 0.06)))
            .scaleEffect(configuration.isPressed ? 0.95 : (isFocused ? 1.06 : 1))
            .animation(.easeOut(duration: 0.15), value: isFocused)
    }
}
