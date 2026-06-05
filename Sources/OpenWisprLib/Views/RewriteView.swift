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

    // Tag labels matching the temperature ramp
    var tagLabel: String {
        ["Conservative", "Balanced", "Expressive"][min(index, 2)]
    }
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
    @Published var selectedVariantIndex: Int? = nil

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
        errorMessage = nil
        withAnimation(.easeOut(duration: 0.18)) {
            mode = .idle
            primaryResult = nil
            variants = []
            showDiff = false
            selectedVariantIndex = nil
        }
    }

    func rewrite() {
        let text = sourceText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        activeTasks.forEach { $0.cancel() }
        activeTasks = []
        errorMessage = nil
        withAnimation(.easeOut(duration: 0.15)) {
            mode = .rewriting
            primaryResult = nil
            variants = []
            showDiff = false
            selectedVariantIndex = nil
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
        withAnimation(.easeOut(duration: 0.15)) {
            mode = .variants
            selectedVariantIndex = nil
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
            inputSection
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
                outputSection(v)
            }
            if vm.mode == .variants {
                Divider()
                variantsSection
            }

            if !vm.recentTranscripts.isEmpty {
                Divider()
                recentsList
            }
        }
    }

    // MARK: Input section

    private var inputSection: some View {
        VStack(alignment: .leading, spacing: 9) {
            // "INPUT" label + char count
            HStack {
                Text("Input")
                    .font(Type.label)
                    .textCase(.uppercase)
                    .tracking(0.9)
                    .foregroundColor(Theme.text3)
                Spacer()
                if !vm.sourceText.isEmpty {
                    Text("\(vm.sourceText.count)")
                        .font(Type.mono)
                        .foregroundColor(Theme.text3)
                }
            }

            // Text area
            ZStack(alignment: .topLeading) {
                if vm.sourceText.isEmpty {
                    Text("Paste or dictate text to rewrite…")
                        .font(Type.body)
                        .foregroundColor(Theme.text3)
                        .allowsHitTesting(false)
                        .padding(.top, 1)
                }
                TextEditor(text: $vm.sourceText)
                    .font(Type.body)
                    .foregroundColor(Theme.text)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 60, maxHeight: 140)
            }
            .opacity(vm.mode == .result || vm.mode == .variants ? 0.45 : 1.0)
            .animation(.easeOut(duration: 0.2), value: vm.mode)
        }
        .padding(.horizontal, 22)
        .padding(.top, 16)
        .padding(.bottom, 14)
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
                    .font(Type.control)
            } else {
                Button("Rewrite") { vm.rewrite() }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.accent)
                    .disabled(vm.sourceText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .keyboardShortcut(.return, modifiers: .command)
                    .font(Type.control)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: Loading

    private var loadingRow: some View {
        HStack(spacing: 8) {
            ProgressView().controlSize(.small).tint(Theme.accent)
            Text("Rewriting…")
                .font(Type.body)
                .foregroundColor(Theme.text2)
            Spacer()
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 14)
        .transition(.opacity)
    }

    // MARK: Error

    private func errorRow(_ msg: String) -> some View {
        HStack(spacing: 8) {
            Rectangle()
                .fill(Theme.recording)
                .frame(width: 3)
            Text(msg)
                .font(Type.body)
                .foregroundColor(Theme.text)
            Spacer()
        }
        .background(Theme.panel)
        .padding(.horizontal, 22)
        .padding(.vertical, 10)
    }

    // MARK: Output section — accentSoft background when filled

    private func outputSection(_ v: RewriteVariant) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            // "OUTPUT" label + latency
            HStack {
                Text("Output")
                    .font(Type.label)
                    .textCase(.uppercase)
                    .tracking(0.9)
                    .foregroundColor(Theme.text3)
                Spacer()
                if v.latencyMs > 0 {
                    Text("\(String(format: "%.1f", Double(v.latencyMs) / 1000))s")
                        .font(Type.mono)
                        .foregroundColor(Theme.text3)
                }
            }

            // Result text box with accentSoft background
            VStack(alignment: .leading, spacing: 10) {
                Text(v.text)
                    .font(Type.output)
                    .lineSpacing(6)
                    .foregroundColor(Theme.text)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)

                // AI linter warning
                let lint = vm.linterResult
                if !lint.isClean {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption2)
                            .foregroundColor(Color(hex: 0xFF9500))
                        Text("AI tells: \(lint.summary)")
                            .font(Type.mono)
                            .foregroundColor(Theme.text2)
                    }
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.accentSoft)
            .overlay(
                RoundedRectangle(cornerRadius: Radii.card)
                    .strokeBorder(Theme.accentLine, lineWidth: 0.5)
            )
            .cornerRadius(Radii.card)
            .transition(.opacity.combined(with: .move(edge: .bottom)))

            // Action row
            HStack(spacing: 8) {
                Button("Copy") { vm.copy(v.text) }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .font(Type.control)

                Button("Paste") { vm.paste(v.text) }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.accent)
                    .controlSize(.small)
                    .font(Type.control)
                    .keyboardShortcut(.return, modifiers: [.command, .shift])
                    .help("⌘⇧↩")

                Button("Variants") { vm.getVariants() }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .font(Type.control)

                Spacer()

                // Diff toggle
                if !v.sourceText.isEmpty {
                    Button(vm.showDiff ? "Hide diff" : "What changed?") {
                        withAnimation(.easeOut(duration: 0.18)) { vm.showDiff.toggle() }
                    }
                    .font(Type.mono)
                    .foregroundColor(Theme.accent)
                    .buttonStyle(.plain)
                }
            }

            // Diff view
            if vm.showDiff, !v.sourceText.isEmpty {
                let tokens = WordDiff.diff(original: v.sourceText, rewritten: v.text)
                Text(WordDiff.attributedString(from: tokens))
                    .font(Type.mono)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(Theme.panel)
                    .overlay(RoundedRectangle(cornerRadius: Radii.control)
                        .strokeBorder(Theme.border, lineWidth: 0.5))
                    .cornerRadius(Radii.control)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 16)
        .transition(.opacity.combined(with: .move(edge: .bottom)))
    }

    // MARK: Variants — 3-column grid of styled cards

    private var variantsSection: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Text("Variants")
                    .font(Type.label)
                    .textCase(.uppercase)
                    .tracking(0.9)
                    .foregroundColor(Theme.text3)
                Spacer()
                Button("Close") { vm.cancel() }
                    .font(.system(size: 12.5))
                    .foregroundColor(Theme.text2)
                    .buttonStyle(.plain)
            }

            HStack(spacing: 10) {
                ForEach(vm.variants) { v in
                    variantCard(v)
                }
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 16)
    }

    @ViewBuilder
    private func variantCard(_ v: RewriteVariant) -> some View {
        let isSelected = vm.selectedVariantIndex == v.index
        let filled = !v.isLoading && v.error == nil && !v.text.isEmpty

        Button {
            if filled {
                vm.selectedVariantIndex = v.index
                vm.paste(v.text)
            }
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                // Tag label
                Text(v.tagLabel)
                    .font(Type.badge)
                    .textCase(.uppercase)
                    .tracking(0.6)
                    .foregroundColor(isSelected ? Theme.accent : Theme.text3)

                // Body
                Group {
                    if v.isLoading {
                        HStack(spacing: 6) {
                            ProgressView().controlSize(.mini)
                            Text("Generating…")
                                .font(.system(size: 13))
                                .italic()
                                .foregroundColor(Theme.text3)
                        }
                    } else if let err = v.error {
                        Text(err).font(.system(size: 12)).foregroundColor(Theme.recording)
                    } else {
                        Text(v.text)
                            .font(.system(size: 13, weight: .regular))
                            .lineSpacing(4)
                            .foregroundColor(Theme.text)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

                // Footer
                if filled {
                    Text(isSelected ? "✓ Applied" : "Click to use")
                        .font(.system(size: 11))
                        .foregroundColor(isSelected ? Theme.accent : Theme.text3)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 80, alignment: .topLeading)
            .background(isSelected ? Theme.accentSoft : Theme.panelSoft)
            .overlay(
                RoundedRectangle(cornerRadius: 11)
                    .strokeBorder(isSelected ? Theme.accent : Theme.border,
                                  lineWidth: isSelected ? 1.5 : 0.5)
            )
            .cornerRadius(11)
        }
        .buttonStyle(.plain)
    }

    // MARK: Recent dictations

    private var recentsList: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Recent Dictations")
                    .font(Type.label)
                    .textCase(.uppercase)
                    .tracking(0.9)
                    .foregroundColor(Theme.text3)
                Spacer()
                Button(action: { vm.loadRecents() }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 11))
                        .foregroundColor(Theme.text3)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 8)
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            ForEach(vm.recentTranscripts.prefix(4)) { t in
                Button {
                    withAnimation(.easeOut(duration: 0.12)) { vm.sourceText = t.text }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "mic.fill")
                            .font(.system(size: 9))
                            .foregroundColor(Theme.text3)
                            .frame(width: 12)
                        Text(t.text)
                            .font(Type.body)
                            .lineLimit(1)
                            .foregroundColor(Theme.text)
                        Spacer()
                        Text(relativeTime(t.createdAt))
                            .font(Type.mono)
                            .foregroundColor(Theme.text3)
                    }
                    .padding(.horizontal, 22)
                    .padding(.vertical, 8)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                if t.id != vm.recentTranscripts.prefix(4).last?.id {
                    Divider().padding(.leading, 44)
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
        if vm.mode == .idle || vm.mode == .result {
            if let t = text { vm.prefill(text: t) } else { vm.loadRecents() }
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
            styleMask: [.nonactivatingPanel, .titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        p.title = "Wispr — Rewrite"
        p.isOpaque = true
        p.backgroundColor = NSColor.windowBackgroundColor
        p.isMovableByWindowBackground = false  // drag by title bar, not background
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
            if self.vm.mode == .idle || self.vm.mode == .result { self.hide() }
        }
    }

    private func stopOutsideClickMonitor() {
        if let m = outsideClickMonitor { NSEvent.removeMonitor(m); outsideClickMonitor = nil }
    }
}

