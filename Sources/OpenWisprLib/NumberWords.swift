import Foundation

/// Converts spelled-out cardinal numbers in dictated text to digits:
/// "I need two laptops" → "I need 2 laptops", "two hundred fifty" → "250",
/// "twenty-three" → "23". Deterministic, no AI — runs in the TextPolisher
/// pipeline so it also applies to type-as-you-speak dictation that never
/// reaches the rewrite step.
///
/// Context handling is intentionally conservative. A lone "one" next to a
/// common idiom ("one of them", "no one", "one another") is left as a word,
/// since that almost never means the digit. Everything else converts.
enum NumberWords {

    private static let units: [String: Int] = [
        "zero": 0, "one": 1, "two": 2, "three": 3, "four": 4, "five": 5,
        "six": 6, "seven": 7, "eight": 8, "nine": 9, "ten": 10, "eleven": 11,
        "twelve": 12, "thirteen": 13, "fourteen": 14, "fifteen": 15,
        "sixteen": 16, "seventeen": 17, "eighteen": 18, "nineteen": 19,
    ]

    private static let tens: [String: Int] = [
        "twenty": 20, "thirty": 30, "forty": 40, "fifty": 50,
        "sixty": 60, "seventy": 70, "eighty": 80, "ninety": 90,
    ]

    private static let scales: [String: Int] = [
        "hundred": 100, "thousand": 1_000, "million": 1_000_000,
        "billion": 1_000_000_000,
    ]

    /// Words that, when adjacent to a lone "one", keep it spelled out.
    private static let oneIdiomNeighbors: Set<String> = [
        "of", "another", "by", "no", "for", "each", "at", "the", "this",
        "that", "than", "and", "or",
    ]

    private static func isNumberWord(_ w: String) -> Bool {
        units[w] != nil || tens[w] != nil || scales[w] != nil
    }

    /// A token as it appears in the text, split into a leading number-word (if
    /// any) and any trailing punctuation so we can re-attach it after replacing.
    private struct Token {
        let raw: String
        let word: String      // lowercased, punctuation stripped
        let trailing: String  // punctuation that followed the word
    }

    static func convert(_ text: String) -> String {
        // Split on whitespace, preserving the pieces so we can rejoin with
        // single spaces (TextPolisher.fixSpacing already normalised spacing).
        let pieces = text.split(separator: " ", omittingEmptySubsequences: false).map(String.init)
        let tokens: [Token] = pieces.map { piece in
            // Strip trailing punctuation (.,!?;:) so "three." still parses as 3.
            var word = piece
            var trailing = ""
            while let last = word.last, ".,!?;:\")]".contains(last) {
                trailing = String(last) + trailing
                word.removeLast()
            }
            return Token(raw: piece, word: word.lowercased(), trailing: trailing)
        }

        var out: [String] = []
        var i = 0
        while i < tokens.count {
            guard isNumberWord(tokens[i].word) else {
                out.append(tokens[i].raw)
                i += 1
                continue
            }

            // Collect a maximal run of number words. "and" only joins when the
            // run already has a scale word ("two hundred and fifty" → one
            // number; "two and three" → two separate numbers).
            var run: [Int] = []      // indices into tokens
            var runHasScale = false
            var j = i
            while j < tokens.count {
                let w = tokens[j].word
                if isNumberWord(w) {
                    run.append(j)
                    if scales[w] != nil { runHasScale = true }
                    // a number word with trailing punctuation ends the run
                    if !tokens[j].trailing.isEmpty { j += 1; break }
                    j += 1
                } else if w == "and", runHasScale,
                          j + 1 < tokens.count,
                          isNumberWord(tokens[j + 1].word) {
                    j += 1  // skip the connector, keep scanning
                } else {
                    break
                }
            }

            let runWords = run.map { tokens[$0].word }

            if shouldKeepAsWords(runWords, at: i, in: tokens) {
                out.append(tokens[i].raw)
                i += 1
                continue
            }

            if let value = parse(runWords) {
                let last = run.last!
                out.append("\(value)" + tokens[last].trailing)
                i = last + 1
            } else {
                // Not a single well-formed number — leave the whole run as words
                // rather than partially converting it.
                for idx in run { out.append(tokens[idx].raw) }
                i = run.last! + 1
            }
        }

        return out.joined(separator: " ")
    }

    /// Guard against converting a lone "one" used idiomatically.
    private static func shouldKeepAsWords(_ run: [String], at index: Int, in tokens: [Token]) -> Bool {
        guard run == ["one"] else { return false }
        let prev = index > 0 ? tokens[index - 1].word : ""
        let next = index + 1 < tokens.count ? tokens[index + 1].word : ""
        return oneIdiomNeighbors.contains(prev) || oneIdiomNeighbors.contains(next)
    }

    /// Parse a sequence of number words into a single integer, or nil if the
    /// sequence isn't a well-formed number. Tracks the ones/tens place so valid
    /// combinations join ("twenty three" → 23) while malformed runs are rejected
    /// and left as words ("five five", "twenty thirty").
    private static func parse(_ words: [String]) -> Int? {
        var total = 0       // accumulated thousand/million groups
        var current = 0     // value being built within the current group
        var lastUnit = false  // last token filled the ones place (1-9 or teen)
        var lastTen = false   // last token was a tens word (20-90)
        var consumedAny = false

        for w in words {
            if let u = units[w] {              // 0-19
                if 1...9 ~= u {
                    if lastUnit { return nil }            // "five five"
                    current += u
                    lastUnit = true; lastTen = false
                } else {                                  // 0 or 10-19
                    if lastUnit || lastTen { return nil } // "twenty ten"
                    current += u
                    lastUnit = true; lastTen = false
                }
            } else if let t = tens[w] {        // 20-90
                if lastUnit || lastTen { return nil }     // "five twenty", "twenty thirty"
                current += t
                lastTen = true; lastUnit = false
            } else if w == "hundred" {
                if current == 0 { current = 1 }
                current *= 100
                lastUnit = false; lastTen = false
            } else if let s = scales[w], s >= 1_000 {
                if current == 0 { current = 1 }
                total += current * s
                current = 0
                lastUnit = false; lastTen = false
            } else {
                return nil
            }
            consumedAny = true
        }
        return consumedAny ? total + current : nil
    }
}
