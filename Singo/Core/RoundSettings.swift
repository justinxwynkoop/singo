import Foundation

/// The four hints, in the order they normally appear.
public enum Hint: String, CaseIterable, Codable, Sendable {
    case genre
    case year
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
    /// Starts as blanks and fills in letters as the song plays.
    case fillIn
    /// Like fillIn, but with no blank lines: letters just appear in place.
    case fillInLettersOnly

    /// Fill-in styles reveal more letters as the song plays.
    public var fillsIn: Bool { self == .fillIn || self == .fillInLettersOnly }

    /// Whether hidden letters are drawn as blank lines.
    public var showsBlanks: Bool { self != .fillInLettersOnly }

    public var label: String {
        switch self {
        case .blanks: return "Blanks"
        case .firstLetter: return "First letter"
        case .firstLetterOfEachWord: return "First letter of each word"
        case .fillIn: return "Fills in as it plays"
        case .fillInLettersOnly: return "Fills in, no blanks"
        }
    }
}

/// Every timing in a round. Defaults: 30 s clip starting 45 s into the song,
/// hints at 10/15/20/25 s, reveal at 30 s, next song at 35 s.
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
    /// Hints that appear during the clip. Turned-off hints stay hidden until
    /// the reveal. The title hint is off unless the host turns it on.
    public var enabledHints: Set<Hint> = [.genre, .year, .art, .artist]

    /// When each hint appears, as a fraction of the clip length, so the
    /// schedule stretches or shrinks with the clip. With a 30 s clip: title
    /// at 10 s (first, so a fill-in title has time to fill), genre and year at
    /// 15 s, art at 20 s, artist at 25 s. Not saved, so changes to these
    /// defaults always take effect.
    public var hintFractions: [Hint: Double] = [
        .title: 1.0 / 3.0,
        .genre: 1.0 / 2.0,
        .year: 1.0 / 2.0,
        .art: 2.0 / 3.0,
        .artist: 5.0 / 6.0,
    ]

    public init() {}

    public func isEnabled(_ hint: Hint) -> Bool { enabledHints.contains(hint) }

    public mutating func setEnabled(_ hint: Hint, _ enabled: Bool) {
        if enabled { enabledHints.insert(hint) } else { enabledHints.remove(hint) }
    }

    // Decode field by field so settings saved by an older version still load,
    // with defaults for anything new.
    private enum CodingKeys: String, CodingKey {
        case clipLength, startOffset, revealHold, addTimeStep, titleHintStyle,
             autoAdvance, enabledHints
    }

    public init(from decoder: Decoder) throws {
        self.init()
        let c = try decoder.container(keyedBy: CodingKeys.self)
        clipLength = (try? c.decodeIfPresent(TimeInterval.self, forKey: .clipLength)) ?? clipLength
        startOffset = (try? c.decodeIfPresent(TimeInterval.self, forKey: .startOffset)) ?? startOffset
        revealHold = (try? c.decodeIfPresent(TimeInterval.self, forKey: .revealHold)) ?? revealHold
        addTimeStep = (try? c.decodeIfPresent(TimeInterval.self, forKey: .addTimeStep)) ?? addTimeStep
        titleHintStyle = (try? c.decodeIfPresent(TitleHintStyle.self, forKey: .titleHintStyle)) ?? titleHintStyle
        autoAdvance = (try? c.decodeIfPresent(Bool.self, forKey: .autoAdvance)) ?? autoAdvance
        enabledHints = (try? c.decodeIfPresent(Set<Hint>.self, forKey: .enabledHints)) ?? enabledHints
    }

    /// Seconds into the clip when `hint` appears. A fill-in title starts with
    /// the song so it has the whole clip to fill in.
    public func time(of hint: Hint) -> TimeInterval {
        if hint == .title, titleHintStyle.fillsIn { return 0 }
        let fraction = min(max(hintFractions[hint] ?? 1, 0), 1)
        return fraction * clipLength
    }

    /// How far the fill-in title hint has filled, from 0 when the title hint
    /// appears to 1 at the end of the clip.
    public func titleFill(at seconds: TimeInterval) -> Double {
        let start = time(of: .title)
        guard clipLength > start else { return 1 }
        return min(max((seconds - start) / (clipLength - start), 0), 1)
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
