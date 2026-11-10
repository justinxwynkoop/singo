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
        Form {
            Section {
                if isLoading {
                    ProgressView("Loading songs…")
                } else if let errorMessage {
                    Text(errorMessage)
                } else {
                    Button {
                        round = GameController(songs: songs, settings: store.settings)
                    } label: {
                        Label("Start round · \(songs.count) songs", systemImage: "play.fill")
                    }
                    .disabled(songs.isEmpty)
                }
            }

            Section("Timing") {
                Picker("Clip length", selection: $store.settings.clipLength) {
                    ForEach(clipLengths, id: \.self) { Text(seconds($0)).tag($0) }
                }
                Picker("Start the song at", selection: $store.settings.startOffset) {
                    ForEach(startOffsets, id: \.self) { Text(seconds($0)).tag($0) }
                }
                Picker("Add-time button", selection: $store.settings.addTimeStep) {
                    ForEach(addTimeSteps, id: \.self) { Text("+" + seconds($0)).tag($0) }
                }
            }

            Section {
                Picker("Title hint", selection: $store.settings.titleHintStyle) {
                    ForEach(TitleHintStyle.allCases, id: \.self) { Text($0.label).tag($0) }
                }
                Toggle("Go to the next song automatically", isOn: $store.settings.autoAdvance)
            } header: {
                Text("Hints and advance")
            } footer: {
                Text(scheduleSummary)
            }
        }
        .navigationTitle(playlist.name)
        .task { await loadSongs() }
        .fullScreenCover(item: $round) { round in
            RoundView(controller: round)
        }
    }

    private var scheduleSummary: String {
        let s = store.settings
        return "Genre and year at \(Int(s.time(of: .genreAndYear)))s, "
            + "title hint at \(Int(s.time(of: .title)))s, "
            + "blurred art at \(Int(s.time(of: .art)))s, "
            + "artist at \(Int(s.time(of: .artist)))s, "
            + "reveal at \(Int(s.clipLength))s."
    }

    private func seconds(_ value: TimeInterval) -> String { "\(Int(value)) seconds" }

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
