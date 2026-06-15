import Foundation

// A CONTENT-FREE summary of how the user edits rewrites. The privacy guarantee:
// every string this can emit is hardcoded below (style vocabulary) -- it never
// puts a transcript word, name, or subject into the output. It reads raw edits
// locally and emits only counts, percentages, and allowlisted style categories.
// Safe to export off the work machine and email to himself. See the in-app
// "Voice" preferences pane and docs memory privacy-cross-machine-learning.
struct VoiceProfile: Codable {
    let label: String
    let generatedAt: String
    let editsAnalyzed: Int
    let avgLengthChangePct: Double
    let shortenRatePct: Double
    let bannedWordsHeRemoves: [String: Int]
    let fillerHeRemoves: [String: Int]
    let punctuation: Punctuation
    let structural: Structural

    struct Punctuation: Codable {
        let emDashesRemoved: Int
        let ellipsesAdded: Int
        let doubleDashesAdded: Int
    }
    struct Structural: Codable {
        let cutOpeningSentence: Int
        let cutClosingSentence: Int
        let otherUncategorizedRewords: Int
    }
}

enum VoiceProfileSynthesizer {
    // The ONLY style words this synthesizer will ever emit. These are AI-tells,
    // not the user's content -- naming them is safe.
    static let bannedWords: Set<String> = [
        "delve", "leverage", "utilize", "utilization", "robust", "seamless",
        "comprehensive", "holistic", "foster", "unlock", "elevate", "empower",
        "spearhead", "synergy", "synergize", "paradigm", "tapestry", "testament",
        "beacon", "vibrant", "bustling", "cutting-edge", "world-class",
        "best-in-class", "supercharge", "streamline", "underscore", "myriad",
        "plethora", "embark", "harness", "meticulous", "effortless", "intricate",
        "actually", "furthermore", "moreover",
    ]
    static let fillerPhrases: Set<String> = [
        "it's worth noting", "at the end of the day", "rest assured",
        "circle back", "touch base", "deep dive", "move the needle", "needless to say",
    ]

    static func synthesize(label: String) -> VoiceProfile {
        let rows = PersistenceContainer.shared.editedRewrites()
        let n = rows.count

        var lengthDeltas: [Double] = []
        var shortened = 0
        var bannedRemoved: [String: Int] = [:]
        var fillerRemoved: [String: Int] = [:]
        var emDashRemoved = 0, ellipsisAdded = 0, doubleDashAdded = 0
        var cutOpener = 0, cutCloser = 0, otherRewords = 0

        for r in rows {
            let ai = r.rewrittenText
            let mine = r.editedText ?? ""
            let aiL = ai.lowercased(), mineL = mine.lowercased()

            let wa = ai.split(whereSeparator: { $0 == " " || $0 == "\n" }).count
            let wm = mine.split(whereSeparator: { $0 == " " || $0 == "\n" }).count
            if wa > 0 { lengthDeltas.append(Double(wm - wa) / Double(wa)) }
            if wm < wa { shortened += 1 }

            var hitKnownCategory = false
            for w in bannedWords {
                let a = wholeWordCount(w, in: aiL)
                let m = wholeWordCount(w, in: mineL)
                if a > m { bannedRemoved[w, default: 0] += (a - m); hitKnownCategory = true }
            }
            for ph in fillerPhrases where aiL.contains(ph) && !mineL.contains(ph) {
                fillerRemoved[ph, default: 0] += 1; hitKnownCategory = true
            }

            emDashRemoved += max(0, (count(ai, "—") + count(ai, "–")) - (count(mine, "—") + count(mine, "–")))
            ellipsisAdded += max(0, (count(mine, "...") + count(mine, "…")) - (count(ai, "...") + count(ai, "…")))
            doubleDashAdded += max(0, count(mine, " -- ") - count(ai, " -- "))

            let sa = sentences(ai), sm = sentences(mine)
            if sm.count < sa.count, let first = sa.first, let last = sa.last {
                if !sm.contains(first) { cutOpener += 1 }
                if !sm.contains(last) { cutCloser += 1 }
            }
            if ai != mine && !hitKnownCategory { otherRewords += 1 }
        }

        let avgDelta = lengthDeltas.isEmpty ? 0
            : (lengthDeltas.reduce(0, +) / Double(lengthDeltas.count)) * 100

        return VoiceProfile(
            label: label,
            generatedAt: ISO8601DateFormatter().string(from: Date()),
            editsAnalyzed: n,
            avgLengthChangePct: (avgDelta * 10).rounded() / 10,
            shortenRatePct: n == 0 ? 0 : (Double(shortened) / Double(n) * 1000).rounded() / 10,
            bannedWordsHeRemoves: bannedRemoved,
            fillerHeRemoves: fillerRemoved,
            punctuation: .init(emDashesRemoved: emDashRemoved,
                               ellipsesAdded: ellipsisAdded,
                               doubleDashesAdded: doubleDashAdded),
            structural: .init(cutOpeningSentence: cutOpener,
                              cutClosingSentence: cutCloser,
                              otherUncategorizedRewords: otherRewords)
        )
    }

    static func jsonString(_ profile: VoiceProfile) -> String {
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? enc.encode(profile),
              let s = String(data: data, encoding: .utf8) else { return "{}" }
        return s
    }

    // MARK: helpers

    private static func wholeWordCount(_ word: String, in text: String) -> Int {
        let pattern = "\\b" + NSRegularExpression.escapedPattern(for: word) + "\\b"
        guard let re = try? NSRegularExpression(pattern: pattern) else { return 0 }
        return re.numberOfMatches(in: text, range: NSRange(text.startIndex..., in: text))
    }

    private static func count(_ text: String, _ sub: String) -> Int {
        guard !sub.isEmpty else { return 0 }
        return text.components(separatedBy: sub).count - 1
    }

    private static func sentences(_ s: String) -> [String] {
        let pattern = "[^.!?]+[.!?]*"
        guard let re = try? NSRegularExpression(pattern: pattern) else { return [s] }
        let ns = s as NSString
        return re.matches(in: s, range: NSRange(location: 0, length: ns.length))
            .map { ns.substring(with: $0.range).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}
