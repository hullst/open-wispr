import SwiftUI
import AppKit

// MARK: - Data types

struct RewriteVariant: Identifiable {
    let id = UUID()
    let index: Int
    var text: String = ""
    var sourceText: String = ""
    var latencyMs: Int = 0
    var error: String? = nil
    var isLoading: Bool = true
}

enum RewriteMode { case idle, rewriting, result, variants }

// MARK: - ViewModel

@MainActor
final class RewriteViewModel: ObservableObject {
    @Published var sourceText: String = ""
    @Published var selectedProviderId: String
    @Published var selectedStyleId: String
    @Published var selectedLengthId: String = "same"
    @Published var mode: RewriteMode = .idle
    @Published var primaryResult: RewriteVariant? = nil
    @Published var variants: [RewriteVariant] = []
    @Published var errorMessage: String? = nil
    @Published var showDiff: Bool = false
    @Published var recentTranscripts: [Transcript] = []

    var linterResult: LinterResult {
        guard let v = primaryResult, !v.text.isEmpty else { return LinterResult(violations: []) }
        return WisprLinter.check(v.text)
    }

    var configuredProviders: [(id: String, name: String)] {
        RewriteService.shared.configuredProviders.map { ($0.id, $0.displayName) }
    }

    private var activeTasks: [Task<Void, Never>] = []

    init() {
        selectedProviderId = WisprDefaults.shared.defaultProviderId
        selectedStyleId = WisprDefaults.shared.defaultStyleId
        loadRecents()
    }

    func loadRecents() {
        recentTranscripts = PersistenceContainer.shared.allTranscripts(limit: 5)
    }

    func prefill(text: String) {
        sourceText = text
        cancel()
        loadRecents()
    }

    func cancel() {
        activeTasks.forEach { $0.cancel() }
        activeTasks = []
        withAnimation(.easeOut(duration: 0.18)) {
            mode = .idle
            primaryResult = nil
            variants = []
            showDiff = false
        }
        errorMessage = nil
    }

    func rewrite() {
        let text = sourceText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        // Cancel tasks without touching mode — avoids the brief .idle flash
        // that could trigger the outside-click monitor during the transition.
        activeTasks.forEach { $0.cancel() }
        activeTasks = []
        errorMessage = nil
        withAnimation(.easeOut(duration: 0.15)) {
            mode = .rewriting
            primaryResult = nil
            variants = []
            showDiff = false
        }

        let source = text
        let providerId = selectedProviderId
        let styleId = selectedStyleId
        let lengthId = selectedLengthId
        let transcriptId = PersistenceContainer.shared.mostRecentTranscript()?.id

        let task = Task { [weak self] in
            do {
                let result = try await RewriteService.shared.rewrite(
                    text: text, providerId: providerId, styleId: styleId,
                    lengthId: lengthId, variantIndex: 0, transcriptId: transcriptId
                )
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    guard let self else { return }
                    var v = RewriteVariant(index: 0)
                    v.text = result.text
                    v.sourceText = source
                    v.latencyMs = result.latencyMs
                    v.isLoading = false
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        self.primaryResult = v
                        self.mode = .result
                    }
                    if WisprDefaults.shared.autoPasteRewrites { self.paste(result.text) }
                }
            } catch {
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    guard let self else { return }
                    self.errorMessage = error.localizedDescription
                    withAnimation { self.mode = .idle }
                }
            }
        }
        activeTasks.append(task)
    }

    func getVariants() {
        let text = sourceText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        activeTasks.forEach { $0.cancel() }
        activeTasks = []

        let source = text
        withAnimation {
            mode = .variants
            variants = [RewriteVariant(index: 0), RewriteVariant(index: 1), RewriteVariant(index: 2)]
        }

        let providerId = selectedProviderId
        let styleId = selectedStyleId
        let lengthId = selectedLengthId
        let transcriptId = PersistenceContainer.shared.mostRecentTranscript()?.id

        for i in 0..<3 {
            let task = Task { [weak self] in
                do {
                    let result = try await RewriteService.shared.rewrite(
                        text: text, providerId: providerId, styleId: styleId,
                        lengthId: lengthId, variantIndex: i, transcriptId: transcriptId
                    )
                    guard !Task.isCancelled else { return }
                    await MainActor.run {
                        guard let self else { return }
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            self.variants[i].text = result.text
                            self.variants[i].sourceText = source
                            self.variants[i].latencyMs = result.latencyMs
                            self.variants[i].isLoading = false
                        }
                    }
                } catch {
                    guard !Task.isCancelled else { return }
                    await MainActor.run {
                        guard let self else { return }
                        self.variants[i].error = error.localizedDescription
                        self.variants[i].isLoading = false
                    }
                }
            }
            activeTasks.append(task)
        }
    }

    func paste(_ text: String) {
        // Just insert — panel stays visible so the user can see what was pasted.
        // The outside-click monitor will close it when they click elsewhere.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
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
            // Source input — same toolbar style as History search bar
            sourceToolbar
            Divider()
            controlsRow

            if let err = vm.errorMessage {
                Divider()
                errorRow(err)
            }
            if vm.mode == .rewriting {
                Divider()
                loadingRow
            }
            if vm.mode == .result, let v = vm.primaryResult, !v.isLoading {
                Divider()
                resultRow(v)
            }
            if vm.mode == .variants {
                Divider()
                variantsSection
            }

            // Recent dictations — same list style as History window
            if !vm.recentTranscripts.isEmpty {
                Divider()
                recentsList
            }
        }
    }

    // MARK: Source toolbar (matches History's search toolbar)

    private var sourceToolbar: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "mic.fill")
                .foregroundColor(Color(NSColor.tertiaryLabelColor))
                .font(.caption)
                .padding(.top, 3)
            ZStack(alignment: .topLeading) {
                if vm.sourceText.isEmpty {
                    Text("Dictate or paste text to rewrite…")
                        .foregroundColor(Color(NSColor.placeholderTextColor))
                        .font(.body)
                        .allowsHitTesting(false)
                        .padding(.top, 1)
                }
                TextEditor(text: $vm.sourceText)
                    .font(.body)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 60, maxHeight: 140)
            }
            .opacity(vm.mode == .result || vm.mode == .variants ? 0.45 : 1.0)
            .animation(.easeOut(duration: 0.2), value: vm.mode)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color(NSColor.controlBackgroundColor))
    }

    // MARK: Controls

    private var controlsRow: some View {
        HStack(spacing: 0) {
            Picker("", selection: $vm.selectedLengthId) {
                Text("Short").tag("shorten")
                Text("Same").tag("same")
                Text("Long").tag("expand")
            }
            .pickerStyle(.segmented)
            .frame(width: 148)
            .labelsHidden()

            Spacer().frame(width: 10)
            Color(NSColor.separatorColor).frame(width: 0.5, height: 18)
            Spacer().frame(width: 10)

            Picker("", selection: $vm.selectedStyleId) {
                Text("Everyday").tag("everyday")
                Text("Chat").tag("chat")
                Text("Co-wide").tag("companywide")
            }
            .pickerStyle(.segmented)
            .frame(width: 172)
            .labelsHidden()

            Spacer()

            if vm.mode == .rewriting || vm.mode == .variants {
                Button("Cancel") { vm.cancel() }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            } else {
                Button("Rewrite") { vm.rewrite() }
                    .buttonStyle(.borderedProminent)
                    .disabled(vm.sourceText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .keyboardShortcut(.return, modifiers: .command)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    // MARK: Loading

    private var loadingRow: some View {
        HStack(spacing: 8) {
            ProgressView().controlSize(.small)
            Text("Rewriting…").foregroundColor(.secondary)
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .transition(.opacity)
    }

    // MARK: Error

    private func errorRow(_ msg: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "exclamationmark.triangle").foregroundColor(.red).font(.caption)
            Text(msg).font(.caption).foregroundColor(.red)
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }

    // MARK: Result row — matches History row style

    private func resultRow(_ v: RewriteVariant) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(v.text)
                        .font(.body)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    // Metadata line
                    HStack(spacing: 6) {
                        if v.latencyMs > 0 {
                            Text("\(v.latencyMs)ms")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        // AI linter warning
                        let lint = vm.linterResult
                        if !lint.isClean {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.caption2)
                                .foregroundColor(Color(red: 0.85, green: 0.65, blue: 0.0))
                            Text(lint.summary)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                Spacer()

                // Action buttons
                HStack(spacing: 6) {
                    Button("Copy") { vm.copy(v.text) }
                        .buttonStyle(.bordered)
                        .controlSize(.small)

                    Button("Paste") { vm.paste(v.text) }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .keyboardShortcut(.return, modifiers: [.command, .shift])
                        .help("⌘⇧↩")

                    Button("Variants") { vm.getVariants() }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                }
            }

            // Diff toggle
            if !v.sourceText.isEmpty {
                Button(vm.showDiff ? "Hide diff" : "What changed?") {
                    withAnimation(.easeOut(duration: 0.18)) { vm.showDiff.toggle() }
                }
                .font(.caption)
                .foregroundColor(.accentColor)
                .buttonStyle(.plain)

                if vm.showDiff {
                    let tokens = WordDiff.diff(original: v.sourceText, rewritten: v.text)
                    Text(WordDiff.attributedString(from: tokens))
                        .font(.caption)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(5)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .transition(.opacity.combined(with: .move(edge: .bottom)))
    }

    // MARK: Variants — same row style

    private var variantsSection: some View {
        VStack(spacing: 0) {
            ForEach(vm.variants) { v in
                HStack(alignment: .top) {
                    Text("\(v.index + 1)")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.secondary)
                        .frame(width: 16)
                        .padding(.top, 1)

                    if v.isLoading {
                        HStack(spacing: 6) {
                            ProgressView().controlSize(.small)
                            Text("Rewriting…").foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    } else if let err = v.error {
                        Text(err).font(.caption).foregroundColor(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        Text(v.text)
                            .font(.body)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .transition(.opacity)
                    }

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
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                if v.index < 2 { Divider().padding(.leading, 14) }
            }
        }
    }

    // MARK: Recent dictations — List style matching History

    private var recentsList: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Recent Dictations")
                    .font(.caption.weight(.medium))
                    .foregroundColor(.secondary)
                Spacer()
                Button(action: { vm.loadRecents() }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            ForEach(vm.recentTranscripts.prefix(4)) { t in
                Button {
                    withAnimation(.easeOut(duration: 0.12)) { vm.sourceText = t.text }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "mic.fill")
                            .font(.caption2)
                            .foregroundColor(Color(NSColor.tertiaryLabelColor))
                            .frame(width: 12)
                        Text(t.text)
                            .font(.body)
                            .lineLimit(1)
                            .foregroundColor(.primary)
                        Spacer()
                        Text(relativeTime(t.createdAt))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                if t.id != vm.recentTranscripts.prefix(4).last?.id {
                    Divider().padding(.leading, 36)
                }
            }
        }
    }

    private func relativeTime(_ date: Date) -> String {
        let diff = Date().timeIntervalSince(date)
        if diff < 60 { return "just now" }
        if diff < 3600 { return "\(Int(diff / 60))m ago" }
        if diff < 86400 { return "\(Int(diff / 3600))h ago" }
        return "\(Int(diff / 86400))d ago"
    }
}

// MARK: - Panel controller

@MainActor
final class RewritePanel {
    static let shared = RewritePanel()
    private var panel: NSPanel?
    let vm = RewriteViewModel()
    private var outsideClickMonitor: Any?

    private init() {}

    func show(prefill text: String? = nil) {
        if panel == nil { panel = buildPanel() }

        // Only prefill if the panel is idle — don't nuke an in-progress
        // rewrite or a result the user hasn't read yet.
        if vm.mode == .idle || vm.mode == .result {
            if let t = text {
                vm.prefill(text: t)
            } else {
                vm.loadRecents()
            }
        }

        panel?.makeKeyAndOrderFront(nil)
        startOutsideClickMonitor()
    }

    func hide() {
        panel?.orderOut(nil)
        stopOutsideClickMonitor()
    }

    private func buildPanel() -> NSPanel {
        let p = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 640, height: 460),
            styleMask: [
                .nonactivatingPanel,
                .titled,          // visible title bar — matches History window style
                .closable,
                .resizable,
            ],
            backing: .buffered,
            defer: false
        )
        p.title = "Wispr — Rewrite"
        p.isOpaque = true
        p.backgroundColor = NSColor.windowBackgroundColor
        p.isMovableByWindowBackground = false
        p.isFloatingPanel = true
        p.level = .floating
        p.becomesKeyOnlyIfNeeded = true
        p.hidesOnDeactivate = false
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        p.isReleasedWhenClosed = false
        p.animationBehavior = .utilityWindow
        p.hasShadow = true
        p.contentMinSize = NSSize(width: 500, height: 260)
        p.contentMaxSize = NSSize(width: 900, height: 800)

        let hosting = NSHostingView(rootView: RewriteView(vm: vm))
        p.contentView = hosting
        p.setFrameAutosaveName("WisprRewritePanel")
        p.center()
        return p
    }

    private func startOutsideClickMonitor() {
        stopOutsideClickMonitor()
        outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] _ in
            guard let self, let p = self.panel, p.isVisible else { return }
            // Close when idle or result — not while actively rewriting/running variants.
            if self.vm.mode == .idle || self.vm.mode == .result { self.hide() }
        }
    }

    private func stopOutsideClickMonitor() {
        if let m = outsideClickMonitor { NSEvent.removeMonitor(m); outsideClickMonitor = nil }
    }
}
