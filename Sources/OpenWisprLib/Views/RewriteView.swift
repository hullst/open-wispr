import SwiftUI
import AppKit

// MARK: - Data types

struct RewriteVariant: Identifiable {
    let id = UUID()
    let index: Int
    var text: String = ""
    var latencyMs: Int = 0
    var error: String? = nil
    var isLoading: Bool = true
}

// MARK: - View Model

@MainActor
final class RewriteViewModel: ObservableObject {
    @Published var sourceText: String = ""
    @Published var selectedProviderId: String
    @Published var selectedStyleId: String
    @Published var selectedLengthId: String = "same"
    @Published var variants: [RewriteVariant] = []
    @Published var isRewriting = false
    @Published var errorMessage: String?

    var configuredProviders: [(id: String, name: String)] {
        RewriteService.shared.configuredProviders.map { ($0.id, $0.displayName) }
    }

    private var activeTasks: [Task<Void, Never>] = []

    init() {
        selectedProviderId = WisprDefaults.shared.defaultProviderId
        selectedStyleId = WisprDefaults.shared.defaultStyleId
    }

    func prefill(text: String) {
        sourceText = text
        cancel()
    }

    func cancel() {
        activeTasks.forEach { $0.cancel() }
        activeTasks = []
        variants = []
        isRewriting = false
        errorMessage = nil
    }

    func runRewrite() {
        let text = sourceText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        cancel()

        isRewriting = true
        errorMessage = nil

        // Seed 3 loading placeholders so cards appear immediately.
        variants = [
            RewriteVariant(index: 0),
            RewriteVariant(index: 1),
            RewriteVariant(index: 2),
        ]

        let providerId = selectedProviderId
        let styleId = selectedStyleId
        let lengthId = selectedLengthId
        let transcriptId = PersistenceContainer.shared.mostRecentTranscript()?.id

        for i in 0..<3 {
            let task = Task { [weak self] in
                do {
                    let result = try await RewriteService.shared.rewrite(
                        text: text,
                        providerId: providerId,
                        styleId: styleId,
                        lengthId: lengthId,
                        variantIndex: i,
                        transcriptId: transcriptId
                    )
                    guard !Task.isCancelled else { return }
                    await MainActor.run {
                        guard let self else { return }
                        self.variants[i].text = result.text
                        self.variants[i].latencyMs = result.latencyMs
                        self.variants[i].isLoading = false
                        self.checkDone()
                    }
                } catch {
                    guard !Task.isCancelled else { return }
                    await MainActor.run {
                        guard let self else { return }
                        self.variants[i].error = error.localizedDescription
                        self.variants[i].isLoading = false
                        self.checkDone()
                    }
                }
            }
            activeTasks.append(task)
        }
    }

    private func checkDone() {
        if variants.allSatisfy({ !$0.isLoading }) {
            isRewriting = false
        }
    }

    func paste(_ text: String) {
        cancel()
        NSApp.hide(nil)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            TextInserter().insert(text: text)
        }
    }

    func copy(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}

// MARK: - Main view

struct RewriteView: View {
    @ObservedObject var vm: RewriteViewModel

    var body: some View {
        VStack(spacing: 0) {
            sourceSection
            Divider()
            controlsRow
            if !vm.variants.isEmpty {
                Divider()
                variantsSection
            }
        }
        .frame(width: 520)
    }

    // MARK: Source

    private var sourceSection: some View {
        ZStack(alignment: .topLeading) {
            if vm.sourceText.isEmpty {
                Text("Paste or dictate text to rewrite…")
                    .foregroundColor(Color(NSColor.placeholderTextColor))
                    .font(.body)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 9)
                    .allowsHitTesting(false)
            }
            TextEditor(text: $vm.sourceText)
                .font(.body)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 70, maxHeight: 110)
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
        }
        .background(Color(NSColor.textBackgroundColor))
    }

    // MARK: Controls

    private var controlsRow: some View {
        HStack(spacing: 8) {
            // Length
            Picker("", selection: $vm.selectedLengthId) {
                Text("Shorter").tag("shorten")
                Text("Same").tag("same")
                Text("Longer").tag("expand")
            }
            .pickerStyle(.segmented)
            .frame(width: 176)
            .labelsHidden()

            // Style
            Picker("", selection: $vm.selectedStyleId) {
                Text("Everyday").tag("everyday")
                Text("Chat").tag("chat")
                Text("Co-wide").tag("companywide")
            }
            .pickerStyle(.segmented)
            .frame(width: 176)
            .labelsHidden()

            Spacer()

            if vm.isRewriting {
                Button("Cancel") { vm.cancel() }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            } else {
                Button(action: vm.runRewrite) {
                    Text("Rewrite")
                }
                .buttonStyle(.borderedProminent)
                .disabled(vm.sourceText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .keyboardShortcut(.return, modifiers: .command)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: Variants

    private var variantsSection: some View {
        VStack(spacing: 0) {
            ForEach(vm.variants) { variant in
                variantCard(variant)
                if variant.index < 2 {
                    Divider()
                }
            }
        }
    }

    @ViewBuilder
    private func variantCard(_ v: RewriteVariant) -> some View {
        HStack(alignment: .top, spacing: 10) {
            // Index badge
            Text("\(v.index + 1)")
                .font(.caption2.weight(.semibold))
                .foregroundColor(.secondary)
                .frame(width: 16, alignment: .center)
                .padding(.top, 3)

            // Content
            if v.isLoading {
                HStack {
                    ProgressView().controlSize(.small)
                    Text("Rewriting…")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 10)
            } else if let err = v.error {
                Text(err)
                    .font(.caption)
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 10)
            } else {
                Text(v.text)
                    .font(.body)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 10)
            }

            // Actions
            if !v.isLoading && v.error == nil {
                VStack(spacing: 4) {
                    Button("Paste") { vm.paste(v.text) }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .keyboardShortcut(KeyEquivalent(Character(String(v.index + 1))), modifiers: .command)
                    Button("Copy") { vm.copy(v.text) }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                }
                .padding(.top, 6)

                if v.latencyMs > 0 {
                    Text("\(v.latencyMs)ms")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .padding(.top, 12)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(v.index % 2 == 0 ? Color.clear : Color(NSColor.controlBackgroundColor).opacity(0.4))
    }
}

// MARK: - Panel controller

@MainActor
final class RewritePanel {
    static let shared = RewritePanel()
    private var panel: NSPanel?
    let vm = RewriteViewModel()

    private init() {}

    func show(prefill text: String? = nil) {
        if let t = text { vm.prefill(text: t) }

        if panel == nil {
            let host = NSHostingController(rootView: RewriteView(vm: vm))
            let p = NSPanel(
                contentRect: NSRect(x: 0, y: 0, width: 520, height: 200),
                styleMask: [.titled, .closable, .resizable, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            p.title = "Wispr"
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
