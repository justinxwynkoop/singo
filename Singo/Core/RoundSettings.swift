import Foundation

/// The four hints, in the order they normally appear.
public enum Hint: String, CaseIterable, Codable, Sendable {
    case genreAndYear
    case title
    case art
    case artist
}

public enum TitleHintStyle: String, CaseIterable, Codable, Sendable {
    /// "_ _ _   _ _ _ _": word count and word lengths only.
    case blanks
    /// "H _ _   _ _ _ _": plus the first letter of the title.
    case firstLetter
    /// "H _ _   J _ _ _": plus the first letter of every word.
    case firstLetterOfEachWord

    public var label: String {
        switch self {
        case .blanks: return "Blanks only"
        case .firstLetter: return "Blanks + first letter"
        case .firstLetterOfEachWord: return "Blanks + first letter of each word"
        }
    }
}

/// Every timing in a round. Defaults match the project brief:
/// 30 s clip starting 45 s into the song, hints at 10/15/20/25 s,
/// reveal at 30 s, next song at 35 s.
public struct RoundSettings: Codable, Equatable, Sendable {
    /// Seconds of music before the reveal.
    public var clipLength: TimeInterval = 30
    /// Where in the song the clip starts, to skip long intros.
    public var startOffset: TimeInterval = 45
    /// Seconds the reveal stays up before the next song starts.
    public var revealHold: TimeInterval = 5
    /// How much the "add time" button adds.
    public var addTimeStep: TimeInterval = 15
    public var titleHintStyle: TitleHintStyle = .firstLetter
    /// When false, the round waits on the reveal screen until the host moves on.
    public var autoAdvance: Bool = true

    /// When each hint appears, as a fraction of the clip length, so the
    /// schedule stretches or shrinks with the clip. With a 30 s clip these are
    /// 10, 15, 20 and 25 seconds.
    public var hintFractions: [Hint: Double] = [
        .genreAndYear: 1.0 / 3.0,
        .title: 1.0 / 2.0,
        .art: 2.0 / 3.0,
        .artist: 5.0 / 6.0,
    ]

    public init() {}

    /// Seconds into the clip when `hint` appears.
    public func time(of hint: Hint) -> TimeInterval {
        let fraction = min(max(hintFractions[hint] ?? 1, 0), 1)
        return fraction * clipLength
    }

    /// Where playback should start for a song of the given length. Moves the
    /// start earlier for short songs so the clip and reveal still fit.
    public func startTime(forSongDuration duration: TimeInterval?) -> TimeInterval {
        let offset = max(0, startOffset)
        guard let duration, duration > 0 else { return offset }
        let latest = max(0, duration - clipLength - revealHold)
        return min(offset, latest)
    }
}
