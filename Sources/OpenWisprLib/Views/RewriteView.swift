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

enum RewriteMode {
    case idle
    case rewriting      // single in-flight
    case result         // single done
    case variants       // 3 in-flight or done
}

// MARK: - View Model

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
        mode = .idle
        primaryResult = nil
        variants = []
        errorMessage = nil
    }

    // Single rewrite.
    func rewrite() {
        let text = sourceText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        cancel()
        mode = .rewriting
        errorMessage = nil

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
                    v.latencyMs = result.latencyMs
                    v.isLoading = false
                    self.primaryResult = v
                    self.mode = .result
                    if WisprDefaults.shared.autoPasteRewrites { self.paste(result.text) }
                }
            } catch {
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    guard let self else { return }
                    self.errorMessage = error.localizedDescription
                    self.mode = .idle
                }
            }
        }
        activeTasks.append(task)
    }

    // Expand to 3 variants. Runs alongside or replaces the primary result.
    func getVariants() {
        let text = sourceText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        activeTasks.forEach { $0.cancel() }
        activeTasks = []
        mode = .variants
        variants = [RewriteVariant(index: 0), RewriteVariant(index: 1), RewriteVariant(index: 2)]

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
                        self.variants[i].text = result.text
                        self.variants[i].latencyMs = result.latencyMs
                        self.variants[i].isLoading = false
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
        let t = text
        NSApp.hide(nil)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            TextInserter().insert(text: t)
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
            if vm.errorMessage != nil || vm.mode == .result || vm.mode == .rewriting {
                Divider()
                resultSection
            }
            if vm.mode == .variants {
                Divider()
                variantsSection
            }
        }
        .frame(width: 560)
        .background(.clear)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color.primary.opacity(0.10), lineWidth: 0.5)
                .allowsHitTesting(false)
        )
    }

    // MARK: Source

    private var sourceSection: some View {
        ZStack(alignment: .topLeading) {
            if vm.sourceText.isEmpty {
                Text("Dictate or paste text to rewrite…")
                    .foregroundColor(Color(NSColor.placeholderTextColor))
                    .font(.body)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 10)
                    .allowsHitTesting(false)
            }
            TextEditor(text: $vm.sourceText)
                .font(.body)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 72, maxHeight: 120)
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
        }
    }

    // MARK: Controls

    private var controlsRow: some View {
        HStack(spacing: 8) {
            Picker("", selection: $vm.selectedLengthId) {
                Text("Shorter").tag("shorten")
                Text("Same").tag("same")
                Text("Longer").tag("expand")
            }
            .pickerStyle(.segmented)
            .frame(width: 168)
            .labelsHidden()

            Picker("", selection: $vm.selectedStyleId) {
                Text("Everyday").tag("everyday")
                Text("Chat").tag("chat")
                Text("Co-wide").tag("companywide")
            }
            .pickerStyle(.segmented)
            .frame(width: 168)
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
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: Single result

    @ViewBuilder
    private var resultSection: some View {
        if let err = vm.errorMessage {
            HStack {
                Image(systemName: "exclamationmark.triangle").foregroundColor(.red)
                Text(err).font(.caption).foregroundColor(.red)
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        } else if vm.mode == .rewriting {
            HStack {
                ProgressView().controlSize(.small)
                Text("Rewriting…").foregroundColor(.secondary).font(.body)
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
        } else if let v = vm.primaryResult, !v.isLoading {
            VStack(alignment: .leading, spacing: 8) {
                Text(v.text)
                    .font(.body)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: 6) {
                    Button("Paste") { vm.paste(v.text) }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .keyboardShortcut(.return, modifiers: [.command, .shift])
                    Button("Copy") { vm.copy(v.text) }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    Spacer()
                    if v.latencyMs > 0 {
                        Text("\(v.latencyMs)ms")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    Button("Get 3 variants") { vm.getVariants() }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
    }

    // MARK: Variants

    private var variantsSection: some View {
        VStack(spacing: 0) {
            ForEach(vm.variants) { v in
                variantRow(v)
                if v.index < 2 { Divider() }
            }
        }
    }

    @ViewBuilder
    private func variantRow(_ v: RewriteVariant) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text("\(v.index + 1)")
                .font(.caption2.weight(.semibold))
                .foregroundColor(.secondary)
                .frame(width: 14)
                .padding(.top, 2)

            if v.isLoading {
                HStack(spacing: 6) {
                    ProgressView().controlSize(.small)
                    Text("Rewriting…").foregroundColor(.secondary).font(.body)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 10)
            } else if let err = v.error {
                Text(err).font(.caption).foregroundColor(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 10)
            } else {
                Text(v.text)
                    .font(.body)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 10)
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
                .padding(.top, 6)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
    }
}

// MARK: - Panel controller

private extension NSImage {
    static func vibrancyMask(cornerRadius: CGFloat) -> NSImage {
        let size = NSSize(width: cornerRadius * 2, height: cornerRadius * 2)
        let image = NSImage(size: size, flipped: false) { rect in
            NSBezierPath(roundedRect: rect, xRadius: cornerRadius, yRadius: cornerRadius).fill()
            return true
        }
        image.capInsets = NSEdgeInsets(top: cornerRadius, left: cornerRadius,
                                        bottom: cornerRadius, right: cornerRadius)
        image.resizingMode = .stretch
        return image
    }
}

@MainActor
final class RewritePanel {
    static let shared = RewritePanel()
    private var panel: NSPanel?
    let vm = RewriteViewModel()
    private var outsideClickMonitor: Any?

    private init() {}

    func show(prefill text: String? = nil) {
        if let t = text { vm.prefill(text: t) }
        if panel == nil { panel = buildPanel() }
        panel?.makeKeyAndOrderFront(nil)
        startOutsideClickMonitor()
    }

    func hide() {
        panel?.orderOut(nil)
        stopOutsideClickMonitor()
    }

    private func buildPanel() -> NSPanel {
        let p = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 200),
            styleMask: [
                .nonactivatingPanel,
                .titled,
                .fullSizeContentView,
                .resizable,
            ],
            backing: .buffered,
            defer: false
        )

        // Chrome
        p.titleVisibility = .hidden
        p.titlebarAppearsTransparent = true
        p.isOpaque = false
        p.backgroundColor = .clear

        // Behavior
        p.isMovableByWindowBackground = true
        p.isFloatingPanel = true
        p.level = .floating
        p.becomesKeyOnlyIfNeeded = true
        p.hidesOnDeactivate = false
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        p.isReleasedWhenClosed = false
        p.animationBehavior = .utilityWindow
        p.hasShadow = true
        p.contentMinSize = NSSize(width: 400, height: 160)
        p.contentMaxSize = NSSize(width: 800, height: 700)

        // Hide traffic lights
        [p.standardWindowButton(.closeButton),
         p.standardWindowButton(.miniaturizeButton),
         p.standardWindowButton(.zoomButton)].forEach { $0?.isHidden = true }

        // Vibrancy backing
        let vibrancy = NSVisualEffectView()
        vibrancy.blendingMode = .behindWindow
        vibrancy.state = .active
        vibrancy.material = .sidebar
        vibrancy.maskImage = .vibrancyMask(cornerRadius: 16)

        // SwiftUI content on top of vibrancy
        let hosting = NSHostingView(rootView: RewriteView(vm: vm))
        hosting.translatesAutoresizingMaskIntoConstraints = false
        vibrancy.addSubview(hosting)
        NSLayoutConstraint.activate([
            hosting.topAnchor.constraint(equalTo: vibrancy.topAnchor),
            hosting.leadingAnchor.constraint(equalTo: vibrancy.leadingAnchor),
            hosting.trailingAnchor.constraint(equalTo: vibrancy.trailingAnchor),
            hosting.bottomAnchor.constraint(equalTo: vibrancy.bottomAnchor),
        ])

        p.contentView = vibrancy
        p.setFrameAutosaveName("WisprRewritePanel")
        p.center()
        return p
    }

    private func startOutsideClickMonitor() {
        stopOutsideClickMonitor()
        outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] _ in
            // Only dismiss when idle or showing a result — not while actively rewriting.
            guard let self, let p = self.panel, p.isVisible else { return }
            let vm = self.vm
            if vm.mode == .idle { self.hide() }
        }
    }

    private func stopOutsideClickMonitor() {
        if let m = outsideClickMonitor { NSEvent.removeMonitor(m); outsideClickMonitor = nil }
    }
}
