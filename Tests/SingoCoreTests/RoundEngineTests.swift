import XCTest
@testable import SingoCore

/// Fixed-seed generator so shuffles are repeatable.
struct SeededGenerator: RandomNumberGenerator {
    var state: UInt64
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

final class RoundEngineTests: XCTestCase {
    func songs(_ count: Int) -> [SongInfo] {
        (1...count).map { SongInfo(id: "\($0)", title: "Song \($0)", artistName: "Artist \($0)", duration: 200) }
    }

    func engine(_ count: Int = 3, settings: RoundSettings = RoundSettings()) -> RoundEngine {
        var generator = SeededGenerator(state: 1)
        return RoundEngine(songs: songs(count), settings: settings, using: &generator)
    }

    /// Ticks in 0.5 s steps for `seconds`, collecting events.
    func run(_ engine: inout RoundEngine, for seconds: TimeInterval) -> [RoundEngine.Event] {
        var events: [RoundEngine.Event] = []
        var t = 0.0
        while t < seconds - 0.0001 {
            events += engine.tick(0.5)
            t += 0.5
        }
        return events
    }

    func testShuffleKeepsEverySongOnceAndDropsDuplicates() {
        var generator = SeededGenerator(state: 7)
        let list = songs(20) + [songs(20)[0]]
        let round = RoundEngine(songs: list, using: &generator)
        XCTAssertEqual(round.songs.count, 20)
        XCTAssertEqual(Set(round.songs.map(\.id)), Set(songs(20).map(\.id)))
    }

    func testStartPlaysFirstSongAtOffset() {
        let round = engine()
        XCTAssertEqual(round.start(), [.play(round.songs[0], startTime: 45)])
    }

    func testDefaultHintScheduleMatchesBrief() {
        var round = engine()
        _ = run(&round, for: 9.5)
        XCTAssertFalse(round.isShowing(.genreAndYear))
        _ = run(&round, for: 0.5) // 10 s
        XCTAssertTrue(round.isShowing(.genreAndYear))
        XCTAssertFalse(round.isShowing(.title))
        _ = run(&round, for: 5) // 15 s
        XCTAssertTrue(round.isShowing(.title))
        XCTAssertFalse(round.isShowing(.art))
        _ = run(&round, for: 5) // 20 s
        XCTAssertTrue(round.isShowing(.art))
        XCTAssertEqual(round.artSharpness, 0, accuracy: 0.001)
        XCTAssertFalse(round.isShowing(.artist))
        _ = run(&round, for: 5) // 25 s
        XCTAssertTrue(round.isShowing(.artist))
        XCTAssertEqual(round.artSharpness, 0.5, accuracy: 0.001)
        XCTAssertEqual(round.phase, .playing)
    }

    func testRevealAtClipEndThenAutoAdvance() {
        var round = engine()
        let first = round.songs[0]
        let events = run(&round, for: 30)
        XCTAssertEqual(events, [.revealed(CalledSong(number: 1, song: first))])
        XCTAssertEqual(round.phase, .revealed)
        XCTAssertEqual(round.called.map(\.song), [first])

        let next = run(&round, for: 5)
        XCTAssertEqual(next, [.play(round.songs[1], startTime: 45)])
        XCTAssertEqual(round.phase, .playing)
        XCTAssertEqual(round.elapsed, 0)
        XCTAssertFalse(round.isShowing(.genreAndYear))
    }

    func testManualAdvanceWaitsOnReveal() {
        var settings = RoundSettings()
        settings.autoAdvance = false
        var round = engine(settings: settings)
        _ = run(&round, for: 120)
        XCTAssertEqual(round.phase, .revealed)
        XCTAssertEqual(round.index, 0)
        let events = round.skip()
        XCTAssertEqual(events, [.play(round.songs[1], startTime: 45)])
    }

    func testPauseStopsTheClock() {
        var round = engine()
        _ = run(&round, for: 5)
        round.togglePause()
        _ = run(&round, for: 60)
        XCTAssertEqual(round.elapsed, 5)
        round.togglePause()
        _ = run(&round, for: 1)
        XCTAssertEqual(round.elapsed, 6)
    }

    func testSkipBeforeRevealDoesNotCallSong() {
        var round = engine()
        _ = run(&round, for: 12)
        _ = round.skip()
        XCTAssertTrue(round.called.isEmpty)
        XCTAssertEqual(round.index, 1)
    }

    func testAddTimeDelaysRevealAndKeepsHintTimes() {
        var round = engine()
        _ = run(&round, for: 22)
        round.addTime()
        XCTAssertEqual(round.revealTime, 45)
        _ = run(&round, for: 10) // 32 s
        XCTAssertEqual(round.phase, .playing)
        XCTAssertTrue(round.isShowing(.artist))
        _ = run(&round, for: 13) // 45 s
        XCTAssertEqual(round.phase, .revealed)
    }

    func testAddTimeAfterRevealHoldsAnswerLonger() {
        var round = engine()
        _ = run(&round, for: 30)
        round.addTime()
        _ = run(&round, for: 5)
        XCTAssertEqual(round.phase, .revealed)
        XCTAssertEqual(round.index, 0)
        _ = run(&round, for: 15)
        XCTAssertEqual(round.index, 1)
    }

    func testReplayRestartsClipButKeepsHints() {
        var round = engine()
        _ = run(&round, for: 16)
        let events = round.replay()
        XCTAssertEqual(events, [.play(round.songs[0], startTime: 45)])
        XCTAssertEqual(round.elapsed, 0)
        XCTAssertTrue(round.isShowing(.title))
        XCTAssertEqual(round.remaining, 30)
    }

    func testRoundFinishesAfterLastSong() {
        var round = engine(2)
        let events = run(&round, for: 70)
        XCTAssertEqual(events.last, .finished)
        XCTAssertEqual(round.phase, .finished)
        XCTAssertNil(round.currentSong)
        XCTAssertEqual(round.called.count, 2)
        XCTAssertEqual(round.called.map(\.number), [1, 2])
    }

    func testEmptyPlaylistIsFinished() {
        let round = RoundEngine(songs: [])
        XCTAssertEqual(round.phase, .finished)
        XCTAssertEqual(round.start(), [.finished])
    }

    func testHintScheduleScalesWithClipLength() {
        var settings = RoundSettings()
        settings.clipLength = 60
        XCTAssertEqual(settings.time(of: .genreAndYear), 20, accuracy: 0.001)
        XCTAssertEqual(settings.time(of: .artist), 50, accuracy: 0.001)
    }

    func testShortSongsStartEarlier() {
        let settings = RoundSettings()
        XCTAssertEqual(settings.startTime(forSongDuration: 300), 45)
        XCTAssertEqual(settings.startTime(forSongDuration: 60), 25)
        XCTAssertEqual(settings.startTime(forSongDuration: 20), 0)
        XCTAssertEqual(settings.startTime(forSongDuration: nil), 45)
    }
}

final class TitleHintTests: XCTestCase {
    func testCleansExtras() {
        XCTAssertEqual(TitleHint.cleaned("Hey Jude - Remastered 2015"), "Hey Jude")
        XCTAssertEqual(TitleHint.cleaned("Old Town Road (feat. Billy Ray Cyrus) [Remix]"), "Old Town Road")
        XCTAssertEqual(TitleHint.cleaned("(Live)"), "(Live)")
    }

    func testWordCountIgnoresSymbols() {
        XCTAssertEqual(TitleHint.words(in: "Rock & Roll").count, 2)
        XCTAssertEqual(TitleHint.words(in: "Don't Stop Believin'").count, 3)
    }

    func testHintText() {
        XCTAssertEqual(TitleHint.text(for: "Hey Jude", style: .both), "2 words · starts with H")
        XCTAssertEqual(TitleHint.text(for: "Yesterday", style: .wordCount), "1 word")
        XCTAssertEqual(TitleHint.text(for: "99 Luftballons", style: .firstLetter), "starts with 9")
    }

    func testGenreAndYear() {
        let song = SongInfo(id: "1", title: "x", artistName: "y", genreNames: ["Music", "Pop"], releaseYear: 1984)
        XCTAssertEqual(song.genreAndYear, "Pop · 1984")
        XCTAssertNil(SongInfo(id: "2", title: "x", artistName: "y", genreNames: ["Music"]).genreAndYear)
    }
}
