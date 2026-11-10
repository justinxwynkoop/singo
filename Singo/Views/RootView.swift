import MusicKit
import SwiftUI

/// Asks for Apple Music access, then shows the playlist picker.
struct RootView: View {
    @State private var library = MusicLibrary()
    @State private var store = SettingsStore()

    var body: some View {
        NavigationStack {
            switch library.status {
            case .authorized:
                PlaylistPickerView(library: library)
                    .navigationDestination(for: Playlist.self) { playlist in
                        RoundSetupView(playlist: playlist, library: library, store: store)
                    }
            case .notDetermined:
                AccessView(
                    message: "Singo plays songs from the Apple Music library on this Apple TV.",
                    buttonTitle: "Allow Apple Music"
                ) {
                    Task { await library.requestAccess() }
                }
            default:
                AccessView(
                    message: "Singo needs Apple Music access. Turn it on in Settings › General › Privacy & Security › Media & Apple Music, then reopen Singo.",
                    buttonTitle: nil,
                    action: {}
                )
            }
        }
    }
}

private struct AccessView: View {
    let message: String
    let buttonTitle: String?
    let action: () -> Void

    var body: some View {
        VStack(spacing: 50) {
            Text("Singo Night")
                .font(.system(size: 96, weight: .bold))
            Text(message)
                .font(.title3)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 1100)
            if let buttonTitle {
                Button(buttonTitle, action: action)
            }
        }
    }
}
