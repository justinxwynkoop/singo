import Foundation

/// One character slot in the title hint.
public enum HintGlyph: Equatable, Sendable {
    /// A letter or digit still hidden: drawn as a blank.
    case hidden
    /// A letter or digit given away by the hint.
    case shown(Character)
    /// Punctuation like ' or & that is always shown.
    case symbol(Character)
}

/// Builds the title hint, a row of blanks like "H _ _   J _ _ _".
public enum TitleHint {
    /// The title without extras like "(feat. X)", "[Live]" or "- Remastered 2011",
    /// which would make the hint unfair.
    public static func cleaned(_ title: String) -> String {
        var result = title
        // Drop bracketed parts: (...) and [...]
        for (open, close) in [("(", ")"), ("[", "]")] {
            while let start = result.range(of: open),
                  let end = result.range(of: close, range: start.upperBound..<result.endIndex) {
                result.removeSubrange(start.lowerBound..<end.upperBound)
            }
        }
        // Drop " - Remastered", " - Live", etc.
        if let dash = result.range(of: " - ") {
            result = String(result[..<dash.lowerBound])
        }
        result = result
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
        return result.isEmpty ? title.trimmingCharacters(in: .whitespacesAndNewlines) : result
    }

    /// Words that contain at least one letter or digit, so a lone "&" or "-" doesn't count.
    public static func words(in title: String) -> [String] {
        cleaned(title)
            .split(whereSeparator: { $0.isWhitespace })
            .map(String.init)
            .filter { word in word.contains { $0.isLetter || $0.isNumber } }
    }

    /// First letter or digit of the title, uppercased.
    public static func firstLetter(of title: String) -> String? {
        guard let character = cleaned(title).first(where: { $0.isLetter || $0.isNumber }) else {
            return nil
        }
        return String(character).uppercased()
    }

    /// The title as words of slots. Letters and digits become blanks, except
    /// the ones `style` gives away; punctuation stays visible.
    public static func glyphs(for title: String, style: TitleHintStyle) -> [[HintGlyph]] {
        let words = cleaned(title).split(whereSeparator: { $0.isWhitespace })
        var revealedFirst = false
        return words.map { word in
            var revealedInWord = false
            return word.map { character -> HintGlyph in
                guard character.isLetter || character.isNumber else { return .symbol(character) }
                let reveal: Bool
                switch style {
                case .blanks: reveal = false
                case .firstLetter: reveal = !revealedFirst
                case .firstLetterOfEachWord: reveal = !revealedInWord
                }
                revealedFirst = true
                revealedInWord = true
                return reveal ? .shown(Character(String(character).uppercased())) : .hidden
            }
        }
    }

    /// The hint as plain text, e.g. "H _ _   J _ _ _".
    public static func text(for title: String, style: TitleHintStyle) -> String {
        glyphs(for: title, style: style)
            .map { word in
                word.map { glyph -> String in
                    switch glyph {
                    case .hidden: return "_"
                    case .shown(let c), .symbol(let c): return String(c)
                    }
                }
                .joined(separator: " ")
            }
            .joined(separator: "   ")
    }
}
