import Foundation
import MusicKit
import UIKit

/// Runs one round: owns the round engine, the clock and the music player,
/// and turns remote presses into engine commands.
@MainActor
@Observable
final class GameController: Identifiable {
    private(set) var engine: RoundEngine
    /// True while a song is loading. The clock waits so every clip gets its full time.
    private(set) var isBuffering = false
    /// A short message for the host, e.g. a song that couldn't play.
    private(set) var notice: String?
    var showingCalledList = false

    private let songsByID: [String: Song]
    /// Genre, year or artwork filled in from the Apple Music catalog when the
    /// library copy of a song is missing them.
    private var catalogDetails: [String: SongInfo] = [:]
    private var catalogArtwork: [String: Artwork] = [:]
    private var lookedUp: Set<String> = []

    private let player = ClipPlayer()
    private var clockTask: Task<Void, Never>?
    private var playGeneration = 0
    private var failuresInARow = 0
    private var needsRestart = false
    private var pauseHolds = 0
    private var wasPausedBeforeHold = false

    init(songs: [Song], settings: RoundSettings) {
        var byID: [String: Song] = [:]
        for song in songs { byID[song.id.rawValue] = song }
        songsByID = byID
        engine = RoundEngine(songs: songs.map(SongInfo.init(song:)), settings: settings)
    }

    // MARK: - Reading

    var currentSong: SongInfo? { engine.currentSong.map(info(for:)) }

    func info(for song: SongInfo) -> SongInfo { catalogDetails[song.id] ?? song }

    func artwork(for songID: String) -> Artwork? {
        songsByID[songID]?.artwork ?? catalogArtwork[songID]
    }

    // MARK: - Lifecycle

    func begin() {
        guard clockTask == nil else { return }
        UIApplication.shared.isIdleTimerDisabled = true
        handle(engine.start())
        startClock()
        Task { await checkSubscription() }
    }

    /// Catalog songs only play with an active Apple Music subscription.
    private func checkSubscription() async {
        guard let subscription = try? await MusicSubscription.current else { return }
        if !subscription.canPlayCatalogContent {
            show("This Apple TV's Apple Music account can't play Apple Music songs. Check that it has an active subscription.", for: nil)
        }
    }

    func end() {
        clockTask?.cancel()
        clockTask = nil
        playGeneration += 1
        player.stop()
        UIApplication.shared.isIdleTimerDisabled = false
    }

    // MARK: - Host controls

    func togglePause() {
        setPaused(!engine.isPaused)
    }

    func setPaused(_ paused: Bool) {
        guard engine.phase != .finished, paused != engine.isPaused else { return }
        engine.setPaused(paused)
        if paused {
            player.pause()
        } else if needsRestart {
            needsRestart = false
            failuresInARow = 0
            handle(engine.replay())
        } else {
            Task { await player.resume() }
        }
    }

    func skip() { handle(engine.skip()) }

    func replay() { handle(engine.replay()) }

    func addTime() { engine.addTime() }

    func openCalledList() {
        holdPause()
        showingCalledList = true
    }

    func calledListClosed() { releasePause() }

    /// Pause for a dialog or sheet, remembering whether we were already paused.
    func holdPause() {
        if pauseHolds == 0 { wasPausedBeforeHold = engine.isPaused }
        pauseHolds += 1
        setPaused(true)
    }

    func releasePause() {
        guard pauseHolds > 0 else { return }
        pauseHolds -= 1
        if pauseHolds == 0, !wasPausedBeforeHold { setPaused(false) }
    }

    // MARK: - Clock

    private func startClock() {
        clockTask = Task { [weak self] in
            let clock = ContinuousClock()
            var last = clock.now
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(100))
                let now = clock.now
                let step = now - last
                last = now
                guard let self else { return }
                let seconds = Double(step.components.seconds)
                    + Double(step.components.attoseconds) / 1e18
                self.tick(seconds)
            }
        }
    }

    private func tick(_ seconds: TimeInterval) {
        guard !isBuffering else { return }
        handle(engine.tick(seconds))
    }

    // MARK: - Events

    private func handle(_ events: [RoundEngine.Event]) {
        for event in events {
            switch event {
            case .play(let song, let startTime):
                startPlayback(of: song, at: startTime)
            case .revealed:
                break
            case .finished:
                playGeneration += 1
                isBuffering = false
                player.stop()
                clockTask?.cancel()
                clockTask = nil
                UIApplication.shared.isIdleTimerDisabled = false
            }
        }
    }

    private func startPlayback(of info: SongInfo, at startTime: TimeInterval) {
        playGeneration += 1
        let generation = playGeneration
        guard let song = songsByID[info.id] else { return }
        isBuffering = true

        Task {
            do {
                try await player.play(song, from: startTime,
                                      label: "Song \(engine.songNumber) of \(engine.songs.count)")
                guard generation == playGeneration else { return }
                isBuffering = false
                failuresInARow = 0
                if engine.isPaused { player.pause() }
            } catch {
                guard generation == playGeneration else { return }
                isBuffering = false
                failuresInARow += 1
                if failuresInARow >= 3 {
                    // Probably no subscription or no network: stop instead of
                    // burning through the whole playlist.
                    needsRestart = true
                    engine.setPaused(true)
                    show("Apple Music isn't playing. Check the subscription and network, then press Play. (\(error.localizedDescription))", for: nil)
                } else {
                    show("Couldn't play “\(info.title)” (\(error.localizedDescription)), skipped it.")
                    handle(engine.skip())
                }
            }
        }

        Task {
            await lookUpCatalogDetails(for: info)
            let next = engine.index + 1
            if engine.songs.indices.contains(next) {
                await lookUpCatalogDetails(for: engine.songs[next])
            }
        }
    }

    private func show(_ message: String, for seconds: Double? = 5) {
        notice = message
        guard let seconds else { return }
        Task {
            try? await Task.sleep(for: .seconds(seconds))
            if notice == message { notice = nil }
        }
    }

    /// Library songs sometimes lack genre, release date or artwork. Fill the
    /// gaps from the Apple Music catalog so every song gets fair hints.
    private func lookUpCatalogDetails(for song: SongInfo) async {
        let missingArt = songsByID[song.id]?.artwork == nil
        guard song.genre == nil || song.releaseYear == nil || missingArt,
              lookedUp.insert(song.id).inserted else { return }

        var request = MusicCatalogSearchRequest(term: "\(song.title) \(song.artistName)", types: [Song.self])
        request.limit = 10
        guard let results = try? await request.response().songs else { return }

        func same(_ a: String, _ b: String) -> Bool { a.caseInsensitiveCompare(b) == .orderedSame }
        guard let match = results.first(where: { same($0.title, song.title) && same($0.artistName, song.artistName) })
            ?? results.first(where: { same($0.artistName, song.artistName) }) else { return }

        catalogDetails[song.id] = SongInfo(
            id: song.id,
            title: song.title,
            artistName: song.artistName,
            albumTitle: song.albumTitle ?? match.albumTitle,
            genreNames: song.genre == nil ? match.genreNames : song.genreNames,
            releaseYear: song.releaseYear ?? match.releaseDate.map { Calendar.current.component(.year, from: $0) },
            duration: song.duration
        )
        if missingArt, let artwork = match.artwork {
            catalogArtwork[song.id] = artwork
        }
    }
}
