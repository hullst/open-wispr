import Foundation

/// Detects when a user's edit to a rewrite is a single proper-noun correction
/// — the signature of "Whisper misheard a name." Used to offer a one-tap
/// "remember this" so the fix lands in the personal dictionary instead of
/// silently polluting the voice-learning signal.
///
/// Deliberately conservative: only fires on a single one-word swap where both
/// sides look like names. Anything ambiguous returns nil — a missed offer costs
/// nothing, a wrong one is noise.
enum DictionaryCapture {

    /// Common capitalized words that are not names — skip these to avoid
    /// offering on ordinary sentence-start or pronoun swaps.
    private static let stopWords: Set<String> = [
        "the", "a", "an", "and", "but", "or", "if", "so", "then", "this",
        "that", "these", "those", "it", "he", "she", "they", "we", "you",
        "i", "is", "are", "was", "were", "to", "of", "in", "on", "for",
    ]

    static func candidate(
        aiOriginal: String,
        edited: String,
        existing: [String: String]
    ) -> (from: String, to: String)? {
        let a = aiOriginal.split(separator: " ").map(String.init)
        let b = edited.split(separator: " ").map(String.init)
        guard a.count == b.count, !a.isEmpty else { return nil }

        var diffIndex = -1
        for i in 0..<a.count where a[i] != b[i] {
            if diffIndex != -1 { return nil }  // more than one word changed
            diffIndex = i
        }
        guard diffIndex != -1 else { return nil }

        let from = trimWord(a[diffIndex])
        let to = trimWord(b[diffIndex])
        guard isNameLike(from), isNameLike(to), from.caseInsensitiveCompare(to) != .orderedSame
        else { return nil }

        // Already mapped (case-insensitive) — nothing to offer.
        if existing.keys.contains(where: { $0.caseInsensitiveCompare(from) == .orderedSame }) {
            return nil
        }
        return (from, to)
    }

    /// Strip surrounding punctuation so "Carrie," matches "Carrie".
    private static func trimWord(_ w: String) -> String {
        w.trimmingCharacters(in: CharacterSet(charactersIn: ".,!?;:\"'()[]"))
    }

    private static func isNameLike(_ w: String) -> Bool {
        guard w.count >= 2, let first = w.first, first.isUppercase else { return false }
        guard w.allSatisfy({ $0.isLetter || $0 == "-" || $0 == "'" }) else { return false }
        return !stopWords.contains(w.lowercased())
    }
}
