import Foundation

struct LinterResult {
    let violations: [String]
    var isClean: Bool { violations.isEmpty }
    var summary: String { violations.prefix(3).joined(separator: ", ") + (violations.count > 3 ? "…" : "") }
}

// Deterministic AI-tells linter — ported from VP Rewriter's ai-blocklist.js.
// Catches the same hard-word and phrase list used in the model prompt,
// so rejects slip through can be flagged visually in the result card.
enum WisprLinter {

    private static let hardWords: [String] = [
        "delve", "leverage", "utilize", "utilization", "robust", "seamless",
        "comprehensive", "holistic", "foster", "unlock", "elevate", "empower",
        "spearhead", "synergy", "synergize", "paradigm", "tapestry", "testament",
        "beacon", "vibrant", "bustling", "supercharge", "streamline", "underscore",
        "myriad", "plethora", "embark", "harness", "meticulous", "effortless",
        "intricate", "multifaceted", "groundbreaking", "revolutionary", "transformative",
        "unparalleled", "unprecedented", "encompass", "boast", "realm", "whilst",
        "amongst", "furthermore", "moreover", "aforementioned", "facilitate",
        "profound", "pivotal", "nuanced",
    ]

    private static let hardPhrases: [String] = [
        "in today's fast-paced", "it's worth noting", "it is worth noting",
        "needless to say", "at the end of the day", "rest assured",
        "i'm thrilled", "i am thrilled", "excited to announce", "excited to share",
        "delighted to", "i hope this finds you", "circle back", "touch base",
        "deep dive", "move the needle", "low-hanging fruit", "north star",
        "game changer", "game-changing", "paradigm shift",
    ]

    static func check(_ text: String) -> LinterResult {
        let lower = text.lowercased()
        var found: [String] = []

        for word in hardWords {
            let pattern = "\\b\(NSRegularExpression.escapedPattern(for: word))(s|es|ed|d|ing|ly|ation)?\\b"
            if let re = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               re.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) != nil {
                if !found.contains(word) { found.append(word) }
            }
        }

        for phrase in hardPhrases where lower.contains(phrase) {
            if !found.contains(phrase) { found.append(phrase) }
        }

        return LinterResult(violations: found)
    }
}
