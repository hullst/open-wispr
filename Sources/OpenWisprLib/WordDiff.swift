import Foundation

struct DiffToken: Identifiable {
    let id = UUID()
    enum Kind { case same, removed, added }
    let kind: Kind
    let text: String
}

enum WordDiff {
    static func diff(original: String, rewritten: String) -> [DiffToken] {
        let a = tokenize(original)
        let b = tokenize(rewritten)
        guard !a.isEmpty || !b.isEmpty else { return [] }
        if a.isEmpty { return b.map { DiffToken(kind: .added, text: $0) } }
        if b.isEmpty { return a.map { DiffToken(kind: .removed, text: $0) } }
        return lcs(a, b)
    }

    // Build an AttributedString suitable for Text() display.
    static func attributedString(from tokens: [DiffToken]) -> AttributedString {
        var result = AttributedString()
        for token in tokens {
            var chunk = AttributedString(token.text)
            switch token.kind {
            case .same:
                break
            case .removed:
                chunk.strikethroughStyle = .single
                chunk.foregroundColor = .red.opacity(0.65)
            case .added:
                chunk.backgroundColor = .green.opacity(0.18)
            }
            result += chunk
            result += AttributedString(" ")
        }
        return result
    }

    private static func tokenize(_ text: String) -> [String] {
        text.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
    }

    private static func lcs(_ a: [String], _ b: [String]) -> [DiffToken] {
        let m = a.count, n = b.count
        // Build DP table
        var dp = [[Int]](repeating: [Int](repeating: 0, count: n + 1), count: m + 1)
        for i in 1...m {
            for j in 1...n {
                dp[i][j] = a[i-1] == b[j-1] ? dp[i-1][j-1] + 1 : max(dp[i-1][j], dp[i][j-1])
            }
        }
        // Backtrack
        var tokens: [DiffToken] = []
        var i = m, j = n
        while i > 0 || j > 0 {
            if i > 0 && j > 0 && a[i-1] == b[j-1] {
                tokens.insert(DiffToken(kind: .same, text: a[i-1]), at: 0)
                i -= 1; j -= 1
            } else if j > 0 && (i == 0 || dp[i][j-1] >= dp[i-1][j]) {
                tokens.insert(DiffToken(kind: .added, text: b[j-1]), at: 0)
                j -= 1
            } else {
                tokens.insert(DiffToken(kind: .removed, text: a[i-1]), at: 0)
                i -= 1
            }
        }
        return tokens
    }
}
