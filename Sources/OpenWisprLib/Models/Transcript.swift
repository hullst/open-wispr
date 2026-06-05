import GRDB
import Foundation

struct Transcript: Codable, FetchableRecord, MutablePersistableRecord {
    static let databaseTableName = "transcripts"

    var id: Int64?
    var text: String
    var source: String  // "dictation" | "manual"
    var transcribedAt: Date
    var createdAt: Date

    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }

    init(text: String, source: String, transcribedAt: Date = Date()) {
        self.text = text
        self.source = source
        self.transcribedAt = transcribedAt
        self.createdAt = transcribedAt
    }
}
