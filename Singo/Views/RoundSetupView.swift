import MusicKit
import SwiftUI

/// Loads the playlist's songs and lets the host adjust timing before starting.
struct RoundSetupView: View {
    let playlist: Playlist
    let library: MusicLibrary
    @Bindable var store: SettingsStore

    @State private var songs: [Song] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var round: GameController?

    private let clipLengths: [TimeInterval] = [15, 20, 30, 45, 60, 90]
    private let startOffsets: [TimeInterval] = [0, 15, 30, 45, 60, 90]
    private let addTimeSteps: [TimeInterval] = [10, 15, 30]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 56) {
                header

                SettingsSection("Timing") {
                    ChoiceRow(title: "Clip length",
                              options: clipLengths.map { Choice($0, seconds($0)) },
                              selection: $store.settings.clipLength)
                    ChoiceRow(title: "Start each song at",
                              options: startOffsets.map { Choice($0, $0 == 0 ? "Beginning" : seconds($0)) },
                              selection: $store.settings.startOffset)
                    ChoiceRow(title: "Add-time button",
                              options: addTimeSteps.map { Choice($0, "+" + seconds($0)) },
                              selection: $store.settings.addTimeStep)
                    ChoiceRow(title: "After the reveal",
                              options: [Choice(true, "Next song automatically"), Choice(false, "Wait for the host")],
                              selection: $store.settings.autoAdvance)
                }

                SettingsSection("Hints") {
                    ChoiceRow(title: "Genre and year · at \(at(.genreAndYear))",
                              options: onOff, selection: hintBinding(.genreAndYear))
                    ChoiceRow(title: "Title · at \(at(.title))",
                              options: titleOptions, selection: titleBinding,
                              footnote: store.settings.isEnabled(.title)
                                  ? "“Hey Jude” shows as  " + TitleHint.text(for: "Hey Jude", style: store.settings.titleHintStyle)
                                  : nil)
                    ChoiceRow(title: "Blurred album art · from \(at(.art))",
                              options: onOff, selection: hintBinding(.art))
                    ChoiceRow(title: "Artist · at \(at(.artist))",
                              options: onOff, selection: hintBinding(.artist))
                    Text("The answer is revealed at \(Int(store.settings.clipLength)) seconds. Hints that are off stay hidden until then.")
                        .font(.system(size: 26))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 80)
            .padding(.vertical, 40)
        }
        .task { await loadSongs() }
        .fullScreenCover(item: $round) { round in
            RoundView(controller: round)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 30) {
            Text(playlist.name)
                .font(.system(size: 64, weight: .bold))
                .lineLimit(1)
            if isLoading {
                ProgressView("Loading songs…")
            } else if let errorMessage {
                Text(errorMessage).font(.title3)
            } else {
                Button {
                    round = GameController(songs: songs, settings: store.settings)
                } label: {
                    Label("Start round · \(songs.count) songs", systemImage: "play.fill")
                        .font(.system(size: 38, weight: .bold))
                        .padding(.horizontal, 30)
                        .padding(.vertical, 10)
                }
                .disabled(songs.isEmpty)
            }
        }
    }

    // MARK: - Hint choices

    private var onOff: [Choice<Bool>] { [Choice(true, "On"), Choice(false, "Off")] }

    private var titleOptions: [Choice<TitleHintStyle?>] {
        [
            Choice(nil, "Off"),
            Choice(.blanks, "Blanks"),
            Choice(.firstLetter, "Blanks + first letter"),
            Choice(.firstLetterOfEachWord, "Blanks + first of each word"),
        ]
    }

    private func hintBinding(_ hint: Hint) -> Binding<Bool> {
        Binding(
            get: { store.settings.isEnabled(hint) },
            set: { store.settings.setEnabled(hint, $0) }
        )
    }

    /// nil means the title hint is off.
    private var titleBinding: Binding<TitleHintStyle?> {
        Binding(
            get: { store.settings.isEnabled(.title) ? store.settings.titleHintStyle : nil },
            set: { style in
                if let style {
                    store.settings.titleHintStyle = style
                    store.settings.setEnabled(.title, true)
                } else {
                    store.settings.setEnabled(.title, false)
                }
            }
        )
    }

    private func at(_ hint: Hint) -> String { "\(Int(store.settings.time(of: hint)))s" }

    private func seconds(_ value: TimeInterval) -> String { "\(Int(value)) sec" }

    private func loadSongs() async {
        guard songs.isEmpty else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            songs = try await library.songs(in: playlist)
            if songs.isEmpty { errorMessage = "This playlist has no songs." }
        } catch {
            errorMessage = "Couldn't load this playlist: \(error.localizedDescription)"
        }
    }
}

// MARK: - Choice rows

struct Choice<Value: Hashable>: Identifiable {
    let value: Value
    let label: String
    var id: Value { value }

    init(_ value: Value, _ label: String) {
        self.value = value
        self.label = label
    }
}

private struct SettingsSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 36) {
            Text(title.uppercased())
                .font(.system(size: 26, weight: .bold))
                .tracking(4)
                .foregroundStyle(.secondary)
            content
        }
    }
}

/// A setting shown as a row of buttons, one per option, with the current one
/// filled in. Swipe across and click to choose.
private struct ChoiceRow<Value: Hashable>: View {
    let title: String
    let options: [Choice<Value>]
    @Binding var selection: Value
    var footnote: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.system(size: 32, weight: .semibold))
            HStack(spacing: 20) {
                ForEach(options) { option in
                    Button { selection = option.value } label: {
                        Text(option.label)
                    }
                    .buttonStyle(ChoiceButtonStyle(isSelected: selection == option.value))
                }
            }
            .focusSection()
            if let footnote {
                Text(footnote)
                    .font(.system(size: 26, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct ChoiceButtonStyle: ButtonStyle {
    let isSelected: Bool

    func makeBody(configuration: Configuration) -> some View {
        ChoiceButtonBody(configuration: configuration, isSelected: isSelected)
    }
}

private struct ChoiceButtonBody: View {
    let configuration: ButtonStyleConfiguration
    let isSelected: Bool
    @Environment(\.isFocused) private var isFocused

    var body: some View {
        HStack(spacing: 10) {
            if isSelected {
                Image(systemName: "checkmark")
            }
            configuration.label
        }
        .font(.system(size: 28, weight: .semibold))
        .padding(.horizontal, 28)
        .padding(.vertical, 16)
        .foregroundStyle(isSelected ? .black : .white)
        .background(
            Capsule().fill(isSelected ? .white : .white.opacity(isFocused ? 0.3 : 0.1))
        )
        .overlay(
            Capsule().stroke(.white, lineWidth: isFocused ? 4 : 0)
        )
        .scaleEffect(isFocused ? 1.08 : 1)
        .shadow(color: .black.opacity(isFocused ? 0.5 : 0), radius: 12, y: 6)
        .animation(.easeOut(duration: 0.15), value: isFocused)
    }
}
