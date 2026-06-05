import SwiftUI
import AppKit

struct HistoryView: View {
    @State private var transcripts: [Transcript] = []
    @State private var search = ""
    @State private var expandedIds: Set<Int64> = []
    @State private var rewrites: [Int64: [WisprRewrite]] = [:]

    private var filtered: [Transcript] {
        guard !search.isEmpty else { return transcripts }
        let q = search.lowercased()
        return transcripts.filter { $0.text.lowercased().contains(q) }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack {
                Image(systemName: "magnifyingglass").foregroundColor(.secondary)
                TextField("Search transcripts…", text: $search)
                    .textFieldStyle(.plain)
                Spacer()
                Button(action: reload) {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            if filtered.isEmpty {
                Spacer()
                Text(search.isEmpty ? "No dictations yet." : "No results.")
                    .foregroundColor(.secondary)
                Spacer()
            } else {
                List(filtered, id: \.id, selection: .constant(nil as Int64?)) { t in
                    transcriptRow(t)
                }
                .listStyle(.inset)
            }
        }
        .frame(minWidth: 500, minHeight: 400)
        .onAppear { reload() }
    }

    @ViewBuilder
    private func transcriptRow(_ t: Transcript) -> some View {
        let id = t.id ?? 0
        let isExpanded = expandedIds.contains(id)

        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(t.text)
                        .lineLimit(isExpanded ? nil : 2)
                        .font(.body)
                    Text(formattedDate(t.createdAt))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                HStack(spacing: 4) {
                    Button(action: { copy(t.text) }) {
                        Image(systemName: "doc.on.doc")
                    }
                    .buttonStyle(.plain)
                    .help("Copy original")

                    Button(action: { openRewrite(t) }) {
                        Image(systemName: "pencil.and.sparkles")
                    }
                    .buttonStyle(.plain)
                    .help("Rewrite again")

                    Button(action: { delete(t) }) {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.red)
                    .help("Delete")

                    Button(action: { toggle(id) }) {
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    }
                    .buttonStyle(.plain)
                }
            }

            if isExpanded, let rs = rewrites[id], !rs.isEmpty {
                Divider()
                ForEach(rs, id: \.id) { r in
                    rewriteRow(r)
                }
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func rewriteRow(_ r: WisprRewrite) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text(r.rewrittenText)
                    .font(.body)
                    .foregroundColor(.secondary)
                HStack {
                    Text(r.modelId).font(.caption2).foregroundColor(.secondary)
                    if let s = r.styleId { Text("· \(s)").font(.caption2).foregroundColor(.secondary) }
                    Text("· \(r.latencyMs)ms").font(.caption2).foregroundColor(.secondary)
                }
            }
            Spacer()
            Button(action: { copy(r.rewrittenText) }) {
                Image(systemName: "doc.on.doc")
            }
            .buttonStyle(.plain)
            .help("Copy rewrite")
        }
        .padding(.leading, 12)
    }

    // MARK: - Actions

    private func reload() {
        transcripts = PersistenceContainer.shared.allTranscripts()
    }

    private func toggle(_ id: Int64) {
        if expandedIds.contains(id) {
            expandedIds.remove(id)
        } else {
            expandedIds.insert(id)
            if rewrites[id] == nil {
                rewrites[id] = PersistenceContainer.shared.rewrites(for: id)
            }
        }
    }

    private func copy(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    private func openRewrite(_ t: Transcript) {
        RewritePanel.shared.show(prefill: t.text)
    }

    private func delete(_ t: Transcript) {
        PersistenceContainer.shared.deleteTranscript(t)
        reload()
    }

    private func formattedDate(_ date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date) {
            return "Today " + DateFormatter.localizedString(from: date, dateStyle: .none, timeStyle: .short)
        } else if cal.isDateInYesterday(date) {
            return "Yesterday " + DateFormatter.localizedString(from: date, dateStyle: .none, timeStyle: .short)
        }
        return DateFormatter.localizedString(from: date, dateStyle: .medium, timeStyle: .short)
    }
}

@MainActor
final class HistoryWindowController {
    static let shared = HistoryWindowController()
    private var window: NSWindow?
    private init() {}

    func show() {
        if window == nil {
            let host = NSHostingController(rootView: HistoryView())
            let w = NSWindow(contentViewController: host)
            w.title = "Wispr — History"
            w.styleMask = [.titled, .closable, .resizable, .miniaturizable]
            w.setContentSize(NSSize(width: 560, height: 500))
            w.center()
            w.setFrameAutosaveName("WisprHistory")
            window = w
        }
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
