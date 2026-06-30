import Foundation

/// Deterministic rule-based text polishing applied to the Whisper transcript
/// before it gets pasted. No AI, no network.
///
/// Pipeline:
///   1. Voice commands  — "new line" → "\n" etc.   (opt-in, gated by caller)
///   2. Disfluencies    — um / uh / erm …          (always; never real words)
///   3. Filler words    — like / actually / you know … (opt-in)
///   4. Spacing         — collapse double spaces, fix space-before-punctuation
///   5. Capitalization  — sentence starts + standalone "i"
///
/// Filler removal is split in two. Pure hesitation sounds (um, uh) carry no
/// meaning and are always stripped. The second group are ordinary English
/// words ("like", "actually") whose removal can change meaning, so it is
/// opt-in — never applied unless the caller asks. Voice commands duplicate
/// `TextPostProcessor` and follow the same `spokenPunctuation` gate.
public enum TextPolisher {

    // MARK: - Defaults

    static let voiceCommands: [(pattern: String, replacement: String)] = [
        ("new paragraph", "\n\n"),
        ("new line", "\n"),
        ("open paren", "("),
        ("close paren", ")"),
        ("open bracket", "["),
        ("close bracket", "]"),
        ("open brace", "{"),
        ("close brace", "}"),
        ("exclamation point", "!"),
        ("question mark", "?"),
        ("period", "."),
        ("comma", ","),
        ("colon", ":"),
        ("semicolon", ";"),
        ("ellipsis", "..."),
        ("dash", "-"),
        ("hyphen", "-"),
    ]

    /// Pure hesitation sounds. Never meaningful words, so always safe to strip.
    static let disfluencies: [String] = [
        "um", "uh", "uhh", "umm", "erm",
    ]

    /// Conversational fillers that are also ordinary English words ("like",
    /// "actually") or carry meaning ("ah", "i mean"). Whole-word removal here
    /// can mangle real prose, so it is opt-in via the `removeFillers` flag.
    static let fillerWords: [String] = [
        "you know", "i mean", "sort of", "kind of", "i guess", "or whatever",
        "you see", "ah", "like", "basically", "literally", "actually",
    ]

    // MARK: - Public entry point

    /// - Parameters:
    ///   - voiceCommands: substitute "comma" → "," etc. Pass the same value as
    ///     the `spokenPunctuation` setting so this can't bypass that gate.
    ///   - removeFillers: also strip the ambiguous filler *words* (like,
    ///     actually, …). Pure disfluencies (um, uh) are always removed.
    ///   - convertNumbers: render spoken cardinals as digits ("two" → "2",
    ///     "twenty-three" → "23"). Idiom-guarded ("one of them" stays a word).
    ///   - dictionary: user-defined whole-word replacements applied last so the
    ///     configured casing wins. Corrects mis-transcribed proper nouns
    ///     ("dyna trace" → "Dynatrace") and expands shorthand ("ai team" →
    ///     "AI Platform team"). Always applied; the user opted in by adding it.
    public static func polish(
        _ text: String,
        voiceCommands: Bool = false,
        removeFillers: Bool = false,
        convertNumbers: Bool = false,
        dictionary: [String: String] = [:]
    ) -> String {
        var s = text
        if voiceCommands { s = applyVoiceCommands(s) }
        s = strip(disfluencies, from: s)
        if removeFillers { s = strip(fillerWords, from: s) }
        s = fixSpacing(s)
        s = fixCapitalization(s)
        if convertNumbers { s = NumberWords.convert(s) }
        s = applyDictionary(s, dictionary)
        return s
    }

    // MARK: - Steps

    private static func applyVoiceCommands(_ text: String) -> String {
        var s = text
        // Longest first so "new paragraph" wins over "new"
        for cmd in voiceCommands.sorted(by: { $0.pattern.count > $1.pattern.count }) {
            s = wholeWordReplace(s, find: cmd.pattern, replace: cmd.replacement)
        }
        return s
    }

    private static func strip(_ words: [String], from text: String) -> String {
        var s = text
        for filler in words.sorted(by: { $0.count > $1.count }) {
            // whole word/phrase, optionally followed by a comma
            let pat = "(?i)(?<!\\w)\(NSRegularExpression.escapedPattern(for: filler))(?!\\w),?"
            if let re = try? NSRegularExpression(pattern: pat) {
                let range = NSRange(s.startIndex..., in: s)
                s = re.stringByReplacingMatches(in: s, range: range, withTemplate: "")
            }
        }
        return s
    }

    /// Apply user dictionary entries as whole-word, case-insensitive replacements.
    /// Longest key first so multi-word phrases win over their prefixes. The
    /// replacement is inserted verbatim, so its casing is authoritative.
    /// Public so the voice-profile diff can normalise both sides through it,
    /// cancelling out dictionary corrections before learning from edits.
    public static func applyDictionary(_ text: String, _ map: [String: String]) -> String {
        guard !map.isEmpty else { return text }
        var s = text
        for key in map.keys.sorted(by: { $0.count > $1.count }) {
            guard !key.isEmpty, let replacement = map[key] else { continue }
            s = wholeWordReplace(s, find: key, replace: replacement)
        }
        return s
    }

    private static func fixSpacing(_ text: String) -> String {
        var s = text
        // Collapse multiple spaces/tabs
        s = re(s, "[ \\t]+", " ")
        // No space before close punctuation
        s = re(s, "\\s+([,.;:!?\\)\\]])", "$1")
        // No space after open brackets
        s = re(s, "([\\(\\[]) +", "$1")
        // Space after sentence punctuation, but only when preceded by 2+ word chars
        // and followed by a capital/opening quote. Splits run-on sentences ("end.Next")
        // without breaking URLs, emails, decimals, or abbreviations (github.com, e.g., U.S.).
        s = re(s, "(?<=\\w\\w)([.!?])(?=[\"'A-Z])", "$1 ")
        // Space after comma/colon/semicolon glued to a letter (protects http:// and decimals/times).
        s = re(s, "([,;:])(?=[A-Za-z])", "$1 ")
        // Tidy newlines
        s = re(s, " *\\n *", "\n")
        s = re(s, "\\n{3,}", "\n\n")
        return s.trimmingCharacters(in: .whitespaces)
    }

    private static func fixCapitalization(_ text: String) -> String {
        var s = text
        // Capitalize first letter after sentence-end or start of string. The
        // sentence-end form requires 2+ word chars before the punctuation so
        // abbreviations ("U.S. last") don't capitalize the following word.
        if let re = try? NSRegularExpression(pattern: "(?:^|(?<=\\w\\w)[.!?]\\s+|\\n)([a-z])") {
            var result = s
            let matches = re.matches(in: s, range: NSRange(s.startIndex..., in: s)).reversed()
            for match in matches {
                guard let charRange = Range(match.range(at: 1), in: s) else { continue }
                result.replaceSubrange(charRange, with: s[charRange].uppercased())
            }
            s = result
        }
        // Standalone "i" → "I"
        s = re(s, "(?<!\\w)i(?!\\w)", "I")
        s = re(s, "(?<!\\w)i'", "I'")
        return s
    }

    // MARK: - Helpers

    private static func wholeWordReplace(_ text: String, find: String, replace: String) -> String {
        let pat = "(?i)(?<!\\w)\(NSRegularExpression.escapedPattern(for: find))(?!\\w)"
        guard let re = try? NSRegularExpression(pattern: pat) else { return text }
        return re.stringByReplacingMatches(
            in: text, range: NSRange(text.startIndex..., in: text),
            withTemplate: NSRegularExpression.escapedTemplate(for: replace)
        )
    }

    private static func re(_ text: String, _ pattern: String, _ replacement: String) -> String {
        guard let re = try? NSRegularExpression(pattern: pattern) else { return text }
        return re.stringByReplacingMatches(
            in: text, range: NSRange(text.startIndex..., in: text),
            withTemplate: replacement
        )
    }
}
