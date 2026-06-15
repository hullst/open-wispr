import GRDB
import Foundation

struct WisprRewrite: Codable, FetchableRecord, MutablePersistableRecord {
    static let databaseTableName = "rewrites"

    var id: Int64?
    var transcriptId: Int64?
    var originalText: String
    var rewrittenText: String
    var modelId: String
    var provider: String
    var styleId: String?
    var latencyMs: Int
    var createdAt: Date
    // the user's edited version of the rewrite, captured when he Copies/Pastes.
    // nil = never opened for edit; == rewrittenText = accepted as-is; different =
    // a real tweak (the compounding signal). See eval/harvest-edits.py.
    var editedText: String?

    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }

    init(
        transcriptId: Int64? = nil,
        originalText: String,
        rewrittenText: String,
        modelId: String,
        provider: String,
        styleId: String? = nil,
        latencyMs: Int
    ) {
        self.transcriptId = transcriptId
        self.originalText = originalText
        self.rewrittenText = rewrittenText
        self.modelId = modelId
        self.provider = provider
        self.styleId = styleId
        self.latencyMs = latencyMs
        self.createdAt = Date()
    }
}
