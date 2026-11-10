import Foundation
import MusicKit
import os

private let log = Logger(subsystem: "family.singonight.app", category: "playlist")

/// Apple Music permission and the playlists in the library signed into this Apple TV.
@MainActor
@Observable
final class MusicLibrary {
    private(set) var status: MusicAuthorization.Status = MusicAuthorization.currentStatus
    private(set) var playlists: [Playlist] = []
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    func requestAccess() async {
        status = await MusicAuthorization.request()
    }

    func loadPlaylists() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let response = try await MusicLibraryRequest<Playlist>().response()
            var all = Array(response.items)
            var batch = response.items
            while batch.hasNextBatch, let next = try await batch.nextBatch() {
                all += next
                batch = next
            }
            playlists = all.sorted {
                $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
        } catch {
            errorMessage = "Couldn't load playlists: \(error.localizedDescription)"
        }
    }

    /// A link to open the playlist in Apple Music, for the QR code on the
    /// game screen. Library playlists usually don't carry a link, so this
    /// builds one from the playlist's Apple Music ID, which only exists once
    /// the playlist has been shared or published.
    func shareURL(for playlist: Playlist) async -> URL? {
        if let url = playlist.url { return url }

        guard let parameters = playlist.playParameters,
              let data = try? JSONEncoder().encode(parameters),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            log.info("No play parameters for \(playlist.name, privacy: .public)")
            return nil
        }
        log.info("Play parameters for \(playlist.name, privacy: .public): \(String(describing: json), privacy: .public)")

        let globalID = ["globalId", "globalID", "catalogId", "catalogID"]
            .lazy
            .compactMap { json[$0] as? String }
            .first { $0.hasPrefix("pl.") }
        guard let globalID else { return nil }

        let country = (try? await MusicDataRequest.currentCountryCode) ?? "us"
        return URL(string: "https://music.apple.com/\(country)/playlist/\(globalID)")
    }

    /// Every song in the playlist. Music videos are left out so the screen stays dark.
    func songs(in playlist: Playlist) async throws -> [Song] {
        let detailed = try await playlist.with([.tracks])
        guard var batch = detailed.tracks else { return [] }
        var tracks = Array(batch)
        while batch.hasNextBatch, let next = try await batch.nextBatch() {
            tracks += next
            batch = next
        }
        return tracks.compactMap { track in
            if case .song(let song) = track { return song }
            return nil
        }
    }
}

extension SongInfo {
    init(song: Song) {
        self.init(
            id: song.id.rawValue,
            title: song.title,
            artistName: song.artistName,
            albumTitle: song.albumTitle,
            genreNames: song.genreNames,
            releaseYear: song.releaseDate.map { Calendar.current.component(.year, from: $0) },
            duration: song.duration
        )
    }
}
