import MusicKit
import SwiftUI

struct PlaylistPickerView: View {
    let library: MusicLibrary

    var body: some View {
        Group {
            if library.playlists.isEmpty {
                if library.isLoading {
                    ProgressView("Loading playlists…")
                } else {
                    ContentUnavailableView {
                        Label("No playlists", systemImage: "music.note.list")
                    } description: {
                        Text(library.errorMessage ?? "Make a playlist in Apple Music, add it to the library, then try again.")
                    } actions: {
                        Button("Try again") { Task { await library.loadPlaylists() } }
                    }
                }
            } else {
                List(library.playlists) { playlist in
                    NavigationLink(value: playlist) {
                        HStack(spacing: 30) {
                            if let artwork = playlist.artwork {
                                ArtworkImage(artwork, width: 90, height: 90)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            } else {
                                Image(systemName: "music.note.list")
                                    .frame(width: 90, height: 90)
                            }
                            Text(playlist.name)
                        }
                    }
                }
            }
        }
        .navigationTitle("Pick a playlist")
        .task {
            if library.playlists.isEmpty { await library.loadPlaylists() }
        }
    }
}
