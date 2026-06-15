import GRDB
import Foundation

// Decided: GRDB instead of SwiftData.
// Reason: SwiftData's @Model macro requires Xcode's build plugin — it doesn't
// compile with `swift build` CLI, which is what REBUILD uses. GRDB is pure Swift,
// no macros, builds from CLI, and directly parallels the VP Rewriter's SQLite usage.
final class PersistenceContainer {
    static let shared = PersistenceContainer()

    private let db: DatabaseQueue

    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("Wispr", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let path = dir.appendingPathComponent("wispr.sqlite").path

        do {
            db = try DatabaseQueue(path: path)
            try migrate()
        } catch {
            fatalError("Failed to open Wispr database: \(error)")
        }
    }

    private func migrate() throws {
        var migrator = DatabaseMigrator()

        migrator.registerMigration("v1") { db in
            try db.create(table: "transcripts") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("text", .text).notNull()
                t.column("source", .text).notNull()
                t.column("transcribedAt", .datetime).notNull()
                t.column("createdAt", .datetime).notNull()
            }
            try db.create(table: "rewrites") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("transcriptId", .integer).references("transcripts", onDelete: .setNull)
                t.column("originalText", .text).notNull()
                t.column("rewrittenText", .text).notNull()
                t.column("modelId", .text).notNull()
                t.column("provider", .text).notNull()
                t.column("styleId", .text)
                t.column("latencyMs", .integer).notNull()
                t.column("createdAt", .datetime).notNull()
            }
        }

        migrator.registerMigration("v2_editedText") { db in
            try db.alter(table: "rewrites") { t in
                t.add(column: "editedText", .text)
            }
        }

        try migrator.migrate(db)
    }

    func insertTranscript(text: String, source: String) {
        var t = Transcript(text: text, source: source)
        try? db.write { db in try t.insert(db) }
    }

    func mostRecentTranscript() -> Transcript? {
        try? db.read { db in
            try Transcript.order(Column("createdAt").desc).fetchOne(db)
        }
    }

    func logRewrite(
        transcriptId: Int64?,
        originalText: String,
        rewrittenText: String,
        modelId: String,
        provider: String,
        styleId: String?,
        latencyMs: Int
    ) -> Int64? {
        var r = WisprRewrite(
            transcriptId: transcriptId,
            originalText: originalText,
            rewrittenText: rewrittenText,
            modelId: modelId,
            provider: provider,
            styleId: styleId,
            latencyMs: latencyMs
        )
        try? db.write { db in try r.insert(db) }
        return r.id
    }

    // Capture the user's edited version of a rewrite (the compounding signal).
    func updateEditedText(id: Int64, editedText: String) {
        try? db.write { db in
            try db.execute(
                sql: "UPDATE rewrites SET editedText = ? WHERE id = ?",
                arguments: [editedText, id]
            )
        }
    }

    func deleteTranscript(_ transcript: Transcript) {
        guard let id = transcript.id else { return }
        try? db.write { db in
            try db.execute(sql: "DELETE FROM rewrites WHERE transcriptId = ?", arguments: [id])
            try db.execute(sql: "DELETE FROM transcripts WHERE id = ?", arguments: [id])
        }
    }

    func allTranscripts(limit: Int = 200) -> [Transcript] {
        (try? db.read { db in
            try Transcript.order(Column("createdAt").desc).limit(limit).fetchAll(db)
        }) ?? []
    }

    // Transcript IDs that have at least one rewrite -- used to badge the recents
    // list (transcription-only vs rewritten).
    func transcriptIdsWithRewrites() -> Set<Int64> {
        let ids = (try? db.read { db in
            try Int64.fetchAll(db, sql:
                "SELECT DISTINCT transcriptId FROM rewrites WHERE transcriptId IS NOT NULL")
        }) ?? []
        return Set(ids)
    }

    // Rows where the user made a real tweak (the compounding signal). Used by the
    // content-free VoiceProfile export.
    func editedRewrites() -> [WisprRewrite] {
        (try? db.read { db in
            try WisprRewrite.fetchAll(db, sql: """
                SELECT * FROM rewrites
                WHERE editedText IS NOT NULL
                  AND TRIM(editedText) <> ''
                  AND editedText <> rewrittenText
                ORDER BY id DESC
            """)
        }) ?? []
    }

    func rewrites(for transcriptId: Int64) -> [WisprRewrite] {
        (try? db.read { db in
            try WisprRewrite
                .filter(Column("transcriptId") == transcriptId)
                .order(Column("createdAt").asc)
                .fetchAll(db)
        }) ?? []
    }
}
