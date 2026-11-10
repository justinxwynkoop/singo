import Foundation
import MusicKit

/// Plays one song at a time from a start offset. The round's own clock
/// decides when to stop, so this never advances on its own.
@MainActor
final class ClipPlayer {
    private let player = ApplicationMusicPlayer.shared

    func play(_ song: Song, from startTime: TimeInterval) async throws {
        player.state.shuffleMode = .off
        player.state.repeatMode = MusicPlayer.RepeatMode.none
        player.queue = ApplicationMusicPlayer.Queue(for: [song])
        try await player.prepareToPlay()
        player.playbackTime = startTime
        try await player.play()
        // Some songs ignore the seek until playback has started.
        if abs(player.playbackTime - startTime) > 2 {
            player.playbackTime = startTime
        }
    }

    func pause() {
        player.pause()
    }

    func resume() async {
        try? await player.play()
    }

    func stop() {
        player.stop()
    }
}
