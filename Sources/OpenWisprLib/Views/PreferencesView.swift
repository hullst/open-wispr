import SwiftUI
import AppKit

struct PreferencesView: View {
    @State private var selection: Section = .general
    @State private var anthropicKey: String = ""
    @State private var openAIKey: String = ""
    @State private var anthropicStatus: KeyStatus = .notSet
    @State private var openAIStatus: KeyStatus = .notSet
    @State private var isTesting = false
    @State private var defaultProvider: String = WisprDefaults.shared.defaultProviderId
    @State private var defaultStyle: String = WisprDefaults.shared.defaultStyleId
    @State private var autoPaste: Bool = WisprDefaults.shared.autoPasteRewrites
    @State private var ollamaModel: String = WisprDefaults.shared.defaultOllamaModel
    @State private var hotkeyCombo: RewriteHotkeyManager.HotkeyCombo? = RewriteHotkeyManager.HotkeyCombo.load()
    @State private var isRecordingHotkey = false

    enum Section: String, CaseIterable {
        case general = "General"
        case rewriter = "Rewriter"
        case apiKeys = "API Keys"
        case hotkeys = "Hotkeys"

        var icon: String {
            switch self {
            case .general: return "gear"
            case .rewriter: return "pencil.and.sparkles"
            case .apiKeys: return "key"
            case .hotkeys: return "keyboard"
            }
        }
    }

    enum KeyStatus { case notSet, configured, invalid }

    var body: some View {
        NavigationSplitView {
            // Sidebar — same list style as History
            List(Section.allCases, id: \.self, selection: $selection) { s in
                Label(s.rawValue, systemImage: s.icon)
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(160)
        } detail: {
            VStack(spacing: 0) {
                // Section header toolbar — matches History/Rewrite toolbar style
                HStack {
                    Image(systemName: selection.icon).foregroundColor(.secondary)
                    Text(selection.rawValue).font(.headline)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color(NSColor.controlBackgroundColor))

                Divider()

                // Section content
                Group {
                    switch selection {
                    case .general:   generalSection
                    case .rewriter:  rewriterSection
                    case .apiKeys:   apiKeysSection
                    case .hotkeys:   hotkeysSection
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .frame(width: 560, height: 360)
        .onAppear { loadKeyStatuses() }
    }

    // MARK: General

    private var generalSection: some View {
        Form {
            Toggle("Enable Globe-key dictation", isOn: Binding(
                get: { WisprDefaults.shared.dictationEnabled },
                set: { WisprDefaults.shared.dictationEnabled = $0 }
            ))
            Toggle("Auto-paste rewrites", isOn: $autoPaste)
                .onChange(of: autoPaste) { WisprDefaults.shared.autoPasteRewrites = $0 }
            LabeledContent("Version") { Text(Wispr.version).foregroundColor(.secondary) }
        }
        .formStyle(.grouped)
        .scrollDisabled(true)
        .padding(.top, 4)
    }

    // MARK: Rewriter

    private var rewriterSection: some View {
        Form {
            Picker("Default model", selection: $defaultProvider) {
                Text("Local (Ollama)").tag("local")
                if KeychainService.shared.getKey(provider: "anthropic") != nil {
                    Text("Claude (Anthropic)").tag("anthropic")
                }
                if KeychainService.shared.getKey(provider: "openai") != nil {
                    Text("GPT (OpenAI)").tag("openai")
                }
            }
            .onChange(of: defaultProvider) { WisprDefaults.shared.defaultProviderId = $0 }

            Picker("Default style", selection: $defaultStyle) {
                ForEach(StylePresets.all, id: \.id) { s in
                    Text(s.displayName).tag(s.id)
                }
            }
            .onChange(of: defaultStyle) { WisprDefaults.shared.defaultStyleId = $0 }

            LabeledContent("Ollama model") {
                TextField("e.g. gemma2:9b", text: $ollamaModel)
                    .frame(width: 150)
                    .onSubmit { WisprDefaults.shared.defaultOllamaModel = ollamaModel }
            }
        }
        .formStyle(.grouped)
        .scrollDisabled(true)
        .padding(.top, 4)
    }

    // MARK: API Keys

    private var apiKeysSection: some View {
        VStack(spacing: 0) {
            keyRow(
                provider: "anthropic",
                label: "Anthropic (Claude)",
                icon: "brain",
                key: $anthropicKey,
                status: $anthropicStatus
            )
            Divider().padding(.leading, 16)
            keyRow(
                provider: "openai",
                label: "OpenAI (GPT)",
                icon: "sparkles",
                key: $openAIKey,
                status: $openAIStatus
            )
            Spacer()
        }
        .padding(.top, 4)
    }

    private func keyRow(provider: String, label: String, icon: String,
                        key: Binding<String>, status: Binding<KeyStatus>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon).foregroundColor(.secondary).font(.caption)
                Text(label).font(.subheadline.weight(.medium))
                Spacer()
                statusBadge(provider: provider, status: status.wrappedValue)
            }
            HStack(spacing: 6) {
                SecureField("Paste API key…", text: key)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { saveKey(provider, key.wrappedValue) }
                Button("Save") { saveKey(provider, key.wrappedValue) }
                    .disabled(key.wrappedValue.isEmpty)
                Button {
                    testKey(provider, statusBinding: status)
                } label: {
                    if isTesting { ProgressView().controlSize(.small) }
                    else { Text("Test") }
                }
                .disabled(isTesting)
                Button { clearKey(provider, key: key, status: status) } label: {
                    Image(systemName: "trash").foregroundColor(.red)
                }
                .buttonStyle(.plain)
                .help("Clear key")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    @ViewBuilder
    private func statusBadge(provider: String, status: KeyStatus) -> some View {
        switch status {
        case .configured:
            Label("Configured", systemImage: "checkmark.circle.fill")
                .font(.caption).foregroundColor(.green)
        case .invalid:
            Label("Invalid", systemImage: "xmark.circle.fill")
                .font(.caption).foregroundColor(.red)
        case .notSet:
            if KeychainService.shared.getKey(provider: provider) != nil {
                Label("Set", systemImage: "checkmark.circle")
                    .font(.caption).foregroundColor(.secondary)
            } else {
                Label("Not set", systemImage: "minus.circle")
                    .font(.caption).foregroundColor(Color(NSColor.tertiaryLabelColor))
            }
        }
    }

    // MARK: Hotkeys

    private var hotkeysSection: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Silent rewrite").font(.subheadline.weight(.medium))
                    Text("Press hotkey after dictating — rewrites and pastes with no panel shown.")
                        .font(.caption).foregroundColor(.secondary)
                }
                Spacer()
                hotkeyControl
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)

            Divider()

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Dictation").font(.subheadline.weight(.medium))
                    Text("Globe / fn key — hold to record, release to transcribe.")
                        .font(.caption).foregroundColor(.secondary)
                }
                Spacer()
                Text("Globe key").foregroundColor(.secondary).font(.caption)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)

            Spacer()
        }
        .padding(.top, 4)
        .background(HotkeyRecorderView(isRecording: $isRecordingHotkey, combo: $hotkeyCombo))
    }

    private var hotkeyControl: some View {
        HStack(spacing: 6) {
            if let combo = hotkeyCombo {
                Text(combo.displayString)
                    .font(.system(.caption, design: .monospaced))
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(4)
                    .overlay(RoundedRectangle(cornerRadius: 4)
                        .strokeBorder(Color(NSColor.separatorColor), lineWidth: 0.5))
                Button { clearHotkey() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(Color(NSColor.tertiaryLabelColor))
                }
                .buttonStyle(.plain)
            } else {
                Text("Not set").foregroundColor(.secondary).font(.caption)
            }
            Button(isRecordingHotkey ? "Press a key…" : "Set") {
                isRecordingHotkey = true
            }
            .foregroundColor(isRecordingHotkey ? .accentColor : nil)
        }
    }

    // MARK: Helpers

    private func loadKeyStatuses() {
        if KeychainService.shared.getKey(provider: "anthropic") != nil { anthropicStatus = .notSet }
        if KeychainService.shared.getKey(provider: "openai") != nil { openAIStatus = .notSet }
    }

    private func saveKey(_ provider: String, _ key: String) {
        guard !key.isEmpty else { return }
        KeychainService.shared.setKey(key, provider: provider)
    }

    private func clearKey(_ provider: String, key: Binding<String>, status: Binding<KeyStatus>) {
        KeychainService.shared.deleteKey(provider: provider)
        key.wrappedValue = ""
        status.wrappedValue = .notSet
    }

    private func testKey(_ provider: String, statusBinding: Binding<KeyStatus>) {
        isTesting = true
        Task {
            do {
                let result = try await RewriteService.shared.rewrite(text: "Hello.", providerId: provider, styleId: "everyday")
                await MainActor.run {
                    statusBinding.wrappedValue = result.text.isEmpty ? .invalid : .configured
                    isTesting = false
                }
            } catch {
                await MainActor.run { statusBinding.wrappedValue = .invalid; isTesting = false }
            }
        }
    }

    private func clearHotkey() {
        RewriteHotkeyManager.HotkeyCombo.clear()
        hotkeyCombo = nil
        RewriteHotkeyManager.shared.reload()
    }
}

// NSViewRepresentable hotkey capture
private struct HotkeyRecorderView: NSViewRepresentable {
    @Binding var isRecording: Bool
    @Binding var combo: RewriteHotkeyManager.HotkeyCombo?

    func makeNSView(context: Context) -> RecorderNSView {
        RecorderNSView(isRecording: $isRecording, combo: $combo)
    }
    func updateNSView(_ view: RecorderNSView, context: Context) { view.isRecording = isRecording }

    class RecorderNSView: NSView {
        var isRecording: Bool = false
        @Binding var isRecordingBinding: Bool
        @Binding var combo: RewriteHotkeyManager.HotkeyCombo?

        init(isRecording: Binding<Bool>, combo: Binding<RewriteHotkeyManager.HotkeyCombo?>) {
            _isRecordingBinding = isRecording
            _combo = combo
            super.init(frame: .zero)
        }
        required init?(coder: NSCoder) { fatalError() }
        override var acceptsFirstResponder: Bool { true }

        override func keyDown(with event: NSEvent) {
            guard isRecording else { super.keyDown(with: event); return }
            let newCombo = RewriteHotkeyManager.HotkeyCombo(
                keyCode: event.keyCode,
                modifiers: event.modifierFlags.intersection([.command, .option, .shift, .control])
            )
            newCombo.save()
            combo = newCombo
            isRecordingBinding = false
            RewriteHotkeyManager.shared.reload()
        }
    }
}

// MARK: - Window controller

@MainActor
final class PreferencesWindowController {
    static let shared = PreferencesWindowController()
    private var window: NSWindow?
    private init() {}

    func show() {
        if window == nil {
            let host = NSHostingController(rootView: PreferencesView())
            let w = NSWindow(contentViewController: host)
            w.title = "Wispr — Preferences"
            w.styleMask = [.titled, .closable, .resizable]
            w.setContentSize(NSSize(width: 560, height: 360))
            w.center()
            w.setFrameAutosaveName("WisprPreferences")
            window = w
        }
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
