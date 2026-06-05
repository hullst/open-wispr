import SwiftUI
import AppKit

// MARK: - View Model

@MainActor
final class RewriteViewModel: ObservableObject {
    @Published var sourceText: String = ""
    @Published var selectedProviderId: String
    @Published var selectedStyleId: String
    @Published var resultText: String = ""
    @Published var isRewriting = false
    @Published var errorMessage: String?
    @Published var latencyMs: Int?

    var configuredProviders: [(id: String, name: String)] {
        RewriteService.shared.configuredProviders.map { ($0.id, $0.displayName) }
    }

    init() {
        selectedProviderId = WisprDefaults.shared.defaultProviderId
        selectedStyleId = WisprDefaults.shared.defaultStyleId
    }

    func prefill(text: String) {
        sourceText = text
        resultText = ""
        errorMessage = nil
        latencyMs = nil
    }

    func runRewrite() {
        guard !sourceText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        isRewriting = true
        errorMessage = nil
        resultText = ""

        let text = sourceText
        let providerId = selectedProviderId
        let styleId = selectedStyleId
        let transcriptId = PersistenceContainer.shared.mostRecentTranscript()?.id

        Task {
            do {
                let result = try await RewriteService.shared.rewrite(
                    text: text,
                    providerId: providerId,
                    styleId: styleId,
                    transcriptId: transcriptId
                )
                await MainActor.run {
                    self.resultText = result.text
                    self.latencyMs = result.latencyMs
                    self.isRewriting = false
                    if WisprDefaults.shared.autoPasteRewrites {
                        self.pasteResult()
                    }
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isRewriting = false
                }
            }
        }
    }

    func copyResult() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(resultText, forType: .string)
    }

    func pasteResult() {
        guard !resultText.isEmpty else { return }
        NSApp.hide(nil)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            let inserter = TextInserter()
            inserter.insert(text: self.resultText)
        }
    }
}

// MARK: - SwiftUI View

struct RewriteView: View {
    @ObservedObject var vm: RewriteViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Rewrite")
                    .font(.headline)
                Spacer()
                if let ms = vm.latencyMs {
                    Text("\(ms)ms")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()

            // Source text
            VStack(alignment: .leading, spacing: 6) {
                Label("Original", systemImage: "text.quote")
                    .font(.caption)
                    .foregroundColor(.secondary)
                TextEditor(text: $vm.sourceText)
                    .font(.body)
                    .frame(minHeight: 80, maxHeight: 150)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color(NSColor.separatorColor), lineWidth: 1))
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)

            // Pickers row
            HStack(spacing: 8) {
                Picker("Model", selection: $vm.selectedProviderId) {
                    ForEach(vm.configuredProviders, id: \.id) { p in
                        Text(p.name).tag(p.id)
                    }
                }
                .labelsHidden()
                .frame(maxWidth: 160)

                Picker("Style", selection: $vm.selectedStyleId) {
                    ForEach(StylePresets.all, id: \.id) { s in
                        Text(s.displayName).tag(s.id)
                    }
                }
                .labelsHidden()
                .frame(maxWidth: 140)

                Spacer()

                Button(action: { vm.runRewrite() }) {
                    if vm.isRewriting {
                        ProgressView().controlSize(.small)
                    } else {
                        Text("Rewrite")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(vm.isRewriting || vm.sourceText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .keyboardShortcut(.return, modifiers: .command)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            // Result
            if !vm.resultText.isEmpty || vm.errorMessage != nil {
                Divider()

                VStack(alignment: .leading, spacing: 6) {
                    if let err = vm.errorMessage {
                        Label(err, systemImage: "exclamationmark.triangle")
                            .font(.caption)
                            .foregroundColor(.red)
                    } else {
                        Label("Result", systemImage: "checkmark.circle")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        ScrollView {
                            Text(vm.resultText)
                                .font(.body)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .textSelection(.enabled)
                        }
                        .frame(minHeight: 60, maxHeight: 200)
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color(NSColor.separatorColor), lineWidth: 1))

                        HStack {
                            Button("Copy") { vm.copyResult() }
                                .buttonStyle(.bordered)
                            Button("Paste to App") { vm.pasteResult() }
                                .buttonStyle(.borderedProminent)
                            Spacer()
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }
        }
        .frame(width: 480)
    }
}

// MARK: - Panel controller

@MainActor
final class RewritePanel {
    static let shared = RewritePanel()
    private var panel: NSPanel?
    private let vm = RewriteViewModel()

    private init() {}

    func show(prefill text: String? = nil) {
        if let t = text { vm.prefill(text: t) }

        if panel == nil {
            let view = RewriteView(vm: vm)
            let host = NSHostingController(rootView: view)
            let p = NSPanel(
                contentRect: NSRect(x: 0, y: 0, width: 480, height: 300),
                styleMask: [.titled, .closable, .resizable, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            p.title = "Wispr — Rewrite"
            p.contentViewController = host
            p.isFloatingPanel = true
            p.level = .floating
            p.center()
            p.setFrameAutosaveName("WisprRewritePanel")
            panel = p
        }

        panel?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func hide() { panel?.orderOut(nil) }
}
