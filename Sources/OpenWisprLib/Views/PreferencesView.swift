import SwiftUI
import AppKit

struct PreferencesView: View {
    @State private var anthropicKey: String = ""
    @State private var openAIKey: String = ""
    @State private var anthropicStatus: KeyStatus = .unknown
    @State private var openAIStatus: KeyStatus = .unknown
    @State private var isTesting = false
    @State private var defaultProvider: String = WisprDefaults.shared.defaultProviderId
    @State private var defaultStyle: String = WisprDefaults.shared.defaultStyleId
    @State private var autoPaste: Bool = WisprDefaults.shared.autoPasteRewrites
    @State private var ollamaModel: String = WisprDefaults.shared.defaultOllamaModel
    @State private var hotkeyCombo: RewriteHotkeyManager.HotkeyCombo? = RewriteHotkeyManager.HotkeyCombo.load()
    @State private var isRecordingHotkey = false

    enum KeyStatus { case unknown, configured, invalid }

    var body: some View {
        TabView {
            generalTab.tabItem { Label("General", systemImage: "gear") }
            rewriterTab.tabItem { Label("Rewriter", systemImage: "pencil.and.sparkles") }
            apiKeysTab.tabItem { Label("API Keys", systemImage: "key") }
            hotkeysTab.tabItem { Label("Hotkeys", systemImage: "keyboard") }
        }
        .padding(16)
        .frame(width: 460, height: 360)
        .onAppear { loadKeys() }
    }

    // MARK: - General

    private var generalTab: some View {
        Form {
            Toggle("Enable Globe-key dictation", isOn: Binding(
                get: { WisprDefaults.shared.dictationEnabled },
                set: { WisprDefaults.shared.dictationEnabled = $0 }
            ))
            Toggle("Auto-paste rewrites", isOn: $autoPaste)
                .onChange(of: autoPaste) { WisprDefaults.shared.autoPasteRewrites = $0 }
            LabeledContent("App version") { Text(Wispr.version) }
        }
    }

    // MARK: - Rewriter

    private var rewriterTab: some View {
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
                    VStack(alignment: .leading) {
                        Text(s.displayName)
                        Text(s.hint).font(.caption).foregroundColor(.secondary)
                    }.tag(s.id)
                }
            }
            .onChange(of: defaultStyle) { WisprDefaults.shared.defaultStyleId = $0 }

            LabeledContent("Local model") {
                TextField("e.g. gemma3:4b", text: $ollamaModel)
                    .frame(width: 140)
                    .onSubmit { WisprDefaults.shared.defaultOllamaModel = ollamaModel }
            }
        }
    }

    // MARK: - API Keys

    private var apiKeysTab: some View {
        Form {
            Section("Anthropic (Claude)") {
                SecureField("Paste API key…", text: $anthropicKey)
                    .onSubmit { saveKey("anthropic", anthropicKey) }
                HStack {
                    statusBadge(anthropicStatus)
                    Button("Save") { saveKey("anthropic", anthropicKey) }.disabled(anthropicKey.isEmpty)
                    Button("Test") { testKey("anthropic") }.disabled(isTesting)
                    Button("Clear") { clearKey("anthropic") }.foregroundColor(.red)
                }
            }

            Section("OpenAI (GPT)") {
                SecureField("Paste API key…", text: $openAIKey)
                    .onSubmit { saveKey("openai", openAIKey) }
                HStack {
                    statusBadge(openAIStatus)
                    Button("Save") { saveKey("openai", openAIKey) }.disabled(openAIKey.isEmpty)
                    Button("Test") { testKey("openai") }.disabled(isTesting)
                    Button("Clear") { clearKey("openai") }.foregroundColor(.red)
                }
            }
        }
    }

    @ViewBuilder
    private func statusBadge(_ status: KeyStatus) -> some View {
        switch status {
        case .configured:
            Label("Configured", systemImage: "checkmark.circle.fill").foregroundColor(.green).font(.caption)
        case .invalid:
            Label("Invalid key", systemImage: "xmark.circle.fill").foregroundColor(.red).font(.caption)
        case .unknown:
            if KeychainService.shared.getKey(provider: "anthropic") != nil {
                Label("Set", systemImage: "checkmark.circle").font(.caption).foregroundColor(.secondary)
            } else {
                Label("Not set", systemImage: "minus.circle").font(.caption).foregroundColor(.secondary)
            }
        }
    }

    // MARK: - Hotkeys

    private var hotkeysTab: some View {
        Form {
            LabeledContent("Silent rewrite") {
                HStack {
                    if let combo = hotkeyCombo {
                        Text(combo.displayString)
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(Color(NSColor.controlBackgroundColor))
                            .cornerRadius(4)
                    } else {
                        Text("Not set").foregroundColor(.secondary)
                    }
                    Button(isRecordingHotkey ? "Recording… (press key)" : "Set") {
                        isRecordingHotkey = true
                    }
                    if hotkeyCombo != nil {
                        Button("Clear") {
                            RewriteHotkeyManager.HotkeyCombo.clear()
                            hotkeyCombo = nil
                            RewriteHotkeyManager.shared.reload()
                        }.foregroundColor(.red)
                    }
                }
            }
            Text("Hold ⌘⌥⇧⌃ + a key while the \"Set\" button is active.")
                .font(.caption).foregroundColor(.secondary)
        }
        .background(HotkeyRecorderView(isRecording: $isRecordingHotkey, combo: $hotkeyCombo))
    }

    // MARK: - Helpers

    private func loadKeys() {
        if KeychainService.shared.getKey(provider: "anthropic") != nil { anthropicStatus = .unknown }
        if KeychainService.shared.getKey(provider: "openai") != nil { openAIStatus = .unknown }
    }

    private func saveKey(_ provider: String, _ key: String) {
        guard !key.isEmpty else { return }
        KeychainService.shared.setKey(key, provider: provider)
        if provider == "anthropic" { anthropicStatus = .unknown }
        else { openAIStatus = .unknown }
    }

    private func clearKey(_ provider: String) {
        KeychainService.shared.deleteKey(provider: provider)
        if provider == "anthropic" { anthropicKey = ""; anthropicStatus = .unknown }
        else { openAIKey = ""; openAIStatus = .unknown }
    }

    private func testKey(_ provider: String) {
        isTesting = true
        Task {
            do {
                let result = try await RewriteService.shared.rewrite(
                    text: "Hello.",
                    providerId: provider,
                    styleId: "everyday"
                )
                await MainActor.run {
                    if provider == "anthropic" { anthropicStatus = result.text.isEmpty ? .invalid : .configured }
                    else { openAIStatus = result.text.isEmpty ? .invalid : .configured }
                    isTesting = false
                }
            } catch {
                await MainActor.run {
                    if provider == "anthropic" { anthropicStatus = .invalid }
                    else { openAIStatus = .invalid }
                    isTesting = false
                }
            }
        }
    }
}

// NSViewRepresentable that captures the next key press when isRecording is true.
private struct HotkeyRecorderView: NSViewRepresentable {
    @Binding var isRecording: Bool
    @Binding var combo: RewriteHotkeyManager.HotkeyCombo?

    func makeNSView(context: Context) -> RecorderNSView {
        RecorderNSView(isRecording: $isRecording, combo: $combo)
    }

    func updateNSView(_ view: RecorderNSView, context: Context) {
        view.isRecording = isRecording
    }

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
            w.title = "Wispr Preferences"
            w.styleMask = [.titled, .closable]
            w.center()
            w.setFrameAutosaveName("WisprPreferences")
            window = w
        }
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
