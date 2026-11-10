import AVFoundation
import Foundation
import MusicKit
import os

private let log = Logger(subsystem: "family.singonight.app", category: "playback")

enum ClipPlayerError: LocalizedError {
    case notPlaying(String)

    var errorDescription: String? {
        switch self {
        case .notPlaying(let status): return "the player stayed \(status)"
        }
    }
}

/// Plays one song at a time from a start offset. The round's own clock
/// decides when to stop, so this never advances on its own.
@MainActor
final class ClipPlayer {
    private let player = ApplicationMusicPlayer.shared
    private var audioSessionReady = false

    /// Claim the TV's audio output for music playback.
    private func prepareAudioSession() {
        guard !audioSessionReady else { return }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default)
            try session.setActive(true)
            audioSessionReady = true
            log.info("Audio session ready, route: \(session.currentRoute.outputs.map(\.portName), privacy: .public)")
        } catch {
            log.error("Audio session failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    func play(_ song: Song, from startTime: TimeInterval) async throws {
        prepareAudioSession()
        log.info("Playing \(song.title, privacy: .public) from \(startTime)s")

        player.state.shuffleMode = .off
        player.state.repeatMode = MusicPlayer.RepeatMode.none
        player.queue = ApplicationMusicPlayer.Queue(for: [song])
        try await player.prepareToPlay()
        player.playbackTime = startTime
        try await player.play()

        // play() can return before audio starts, or without starting at all.
        // Wait up to 3 seconds for it to really play, nudging it once.
        for attempt in 0..<30 {
            if player.state.playbackStatus == .playing { break }
            if attempt == 10 {
                log.notice("Still \(String(describing: self.player.state.playbackStatus), privacy: .public), calling play() again")
                try await player.play()
            }
            try await Task.sleep(for: .milliseconds(100))
        }
        guard player.state.playbackStatus == .playing else {
            let status = String(describing: player.state.playbackStatus)
            log.error("Not playing after play(): \(status, privacy: .public)")
            throw ClipPlayerError.notPlaying(status)
        }

        // Some songs ignore the seek until playback has started.
        if abs(player.playbackTime - startTime) > 2 {
            player.playbackTime = startTime
        }
        log.info("Playing at \(self.player.playbackTime)s")
    }

    func pause() {
        player.pause()
    }

    func resume() async {
        do {
            try await player.play()
        } catch {
            log.error("Resume failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    func stop() {
        player.stop()
    }
}
