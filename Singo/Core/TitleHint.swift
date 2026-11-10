import Foundation

/// Builds the title hint ("3 words · starts with H") from a song title.
public enum TitleHint {
    /// The title without extras like "(feat. X)", "[Live]" or "- Remastered 2011",
    /// which would make the word count unfair.
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

    public static func text(for title: String, style: TitleHintStyle) -> String {
        let count = words(in: title).count
        let countText = count == 1 ? "1 word" : "\(count) words"
        let letterText = firstLetter(of: title).map { "starts with \($0)" }

        switch style {
        case .wordCount:
            return countText
        case .firstLetter:
            return letterText ?? countText
        case .both:
            return [countText, letterText].compactMap { $0 }.joined(separator: " · ")
        }
    }
}
