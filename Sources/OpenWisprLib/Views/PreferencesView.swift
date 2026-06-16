import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct PreferencesView: View {
    @State private var selection: Section = .general
    @State private var anthropicKey: String = ""
    @State private var openAIKey: String = ""
    @State private var geminiKey: String = ""
    @State private var anthropicStatus: KeyStatus = .notSet
    @State private var openAIStatus: KeyStatus = .notSet
    @State private var geminiStatus: KeyStatus = .notSet
    @State private var isTesting = false
    @State private var defaultProvider: String = WisprDefaults.shared.defaultProviderId
    @State private var defaultStyle: String = WisprDefaults.shared.defaultStyleId
    @State private var autoPaste: Bool = WisprDefaults.shared.autoPasteRewrites
    @State private var ollamaModel: String = WisprDefaults.shared.defaultOllamaModel
    @State private var claudeCodeModel: String = WisprDefaults.shared.defaultClaudeCodeModel
    @State private var claudeCodeAuthMode: String = WisprDefaults.shared.claudeCodeAuthMode
    @State private var bedrockRegion: String = WisprDefaults.shared.claudeCodeBedrockRegion
    @State private var bedrockProfile: String = WisprDefaults.shared.claudeCodeBedrockProfile
    @State private var bedrockModel: String = WisprDefaults.shared.claudeCodeBedrockModel
    @State private var profilePreview: String = ""
    @State private var profileEditCount: Int = 0
    @State private var exportMessage: String? = nil
    @State private var hotkeyCombo: RewriteHotkeyManager.HotkeyCombo? = RewriteHotkeyManager.HotkeyCombo.load()
    @State private var isRecordingHotkey = false
    @State private var convertNumbers: Bool = true
    @State private var removeFillers: Bool = false
    @State private var spokenPunctuation: Bool = false
    @State private var dictEntries: [DictEntry] = []

    enum Section: String, CaseIterable {
        case general = "General"
        case dictation = "Dictation"
        case rewriter = "Rewriter"
        case voice = "Voice"
        case apiKeys = "API Keys"
        case hotkeys = "Hotkeys"

        var icon: String {
            switch self {
            case .general: return "gear"
            case .dictation: return "textformat.abc"
            case .rewriter: return "pencil.and.sparkles"
            case .voice: return "person.wave.2"
            case .apiKeys: return "key"
            case .hotkeys: return "keyboard"
            }
        }
    }

    /// One personal-dictionary row, identifiable so SwiftUI can bind text fields.
    struct DictEntry: Identifiable, Equatable {
        let id = UUID()
        var from: String
        var to: String
    }

    enum KeyStatus { case notSet, configured, invalid, error(String) }

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
                    case .dictation: dictationSection
                    case .rewriter:  rewriterSection
                    case .voice:     voiceSection
                    case .apiKeys:   apiKeysSection
                    case .hotkeys:   hotkeysSection
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .frame(width: 560, height: 360)
        .onAppear { loadKeyStatuses(); loadDictationConfig() }
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

    // MARK: Dictation

    private var dictationSection: some View {
        Form {
            SwiftUI.Section {
                Toggle("Convert spoken numbers to digits", isOn: $convertNumbers)
                    .onChange(of: convertNumbers) { _ in persistDictation() }
                Toggle("Remove filler words", isOn: $removeFillers)
                    .onChange(of: removeFillers) { _ in persistDictation() }
                Toggle("Spoken punctuation", isOn: $spokenPunctuation)
                    .onChange(of: spokenPunctuation) { _ in persistDictation() }
            } footer: {
                Text("Numbers: \u{201C}twenty three\u{201D} \u{2192} 23, idiom-guarded. Fillers: strips \u{201C}like / actually\u{201D}; \u{201C}um / uh\u{201D} are always removed. Punctuation: say \u{201C}comma\u{201D}, \u{201C}period\u{201D}.")
                    .font(.caption).foregroundColor(.secondary)
            }

            SwiftUI.Section {
                if dictEntries.isEmpty {
                    Text("No entries yet.").foregroundColor(.secondary)
                }
                ForEach($dictEntries) { $entry in
                    HStack(spacing: 8) {
                        TextField("heard as\u{2026}", text: $entry.from)
                            .textFieldStyle(.roundedBorder)
                            .onSubmit { persistDictation() }
                        Image(systemName: "arrow.right").font(.caption).foregroundColor(.secondary)
                        TextField("replace with\u{2026}", text: $entry.to)
                            .textFieldStyle(.roundedBorder)
                            .onSubmit { persistDictation() }
                        Button(role: .destructive) {
                            dictEntries.removeAll { $0.id == entry.id }
                            persistDictation()
                        } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.borderless)
                        .help("Remove this entry")
                    }
                }
                Button {
                    dictEntries.append(DictEntry(from: "", to: ""))
                } label: {
                    Label("Add entry", systemImage: "plus")
                }
                .buttonStyle(.borderless)
            } header: {
                Text("Personal dictionary")
            } footer: {
                Text("Whole-word, case-insensitive replacement applied to every dictation. It\u{2019}s literal \u{2014} it can\u{2019}t tell meaning apart, so map distinctive mishearings (\u{201C}carrie\u{201D} \u{2192} \u{201C}Keri\u{201D}), not everyday words like \u{201C}carry\u{201D}.")
                    .font(.caption).foregroundColor(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding(.top, 4)
        .onDisappear { persistDictation() }
    }

    private func loadDictationConfig() {
        let cfg = Config.load()
        convertNumbers = cfg.convertNumbers?.value ?? true
        removeFillers = cfg.removeFillers?.value ?? false
        spokenPunctuation = cfg.spokenPunctuation?.value ?? false
        dictEntries = (cfg.dictionary ?? [:])
            .sorted { $0.key < $1.key }
            .map { DictEntry(from: $0.key, to: $0.value) }
    }

    /// Persist the dictation settings back into config.json, preserving every
    /// other field, then ask the running app to reload so changes apply live.
    private func persistDictation() {
        var cfg = Config.load()
        cfg.convertNumbers = FlexBool(convertNumbers)
        cfg.removeFillers = FlexBool(removeFillers)
        cfg.spokenPunctuation = FlexBool(spokenPunctuation)
        var map: [String: String] = [:]
        for entry in dictEntries {
            let key = entry.from.trimmingCharacters(in: .whitespacesAndNewlines)
            let value = entry.to.trimmingCharacters(in: .whitespacesAndNewlines)
            if !key.isEmpty, !value.isEmpty { map[key] = value }
        }
        cfg.dictionary = map.isEmpty ? nil : map
        try? cfg.save()
        (NSApplication.shared.delegate as? AppDelegate)?.reloadConfig()
    }

    // MARK: Rewriter

    private var rewriterSection: some View {
        Form {
            Picker("Default model", selection: $defaultProvider) {
                if RewriteService.shared.claudeCode.isConfigured {
                    Text("Claude Code (subscription)").tag("claude-code")
                }
                Text("Local (Ollama)").tag("local")
                if KeychainService.shared.getKey(provider: "anthropic") != nil {
                    Text("Claude (Anthropic API)").tag("anthropic")
                }
                if KeychainService.shared.getKey(provider: "openai") != nil {
                    Text("GPT (OpenAI)").tag("openai")
                }
                if KeychainService.shared.getKey(provider: "gemini") != nil {
                    Text("Gemini (Google)").tag("gemini")
                }
            }
            .onChange(of: defaultProvider) { WisprDefaults.shared.defaultProviderId = $0 }

            if defaultProvider == "claude-code" {
                Picker("Auth", selection: $claudeCodeAuthMode) {
                    Text("Subscription (personal Mac)").tag("subscription")
                    Text("Bedrock (work Mac)").tag("bedrock")
                }
                .onChange(of: claudeCodeAuthMode) { WisprDefaults.shared.claudeCodeAuthMode = $0 }

                if claudeCodeAuthMode == "subscription" {
                    Picker("Claude Code model", selection: $claudeCodeModel) {
                        ForEach(ClaudeCodeModel.allCases, id: \.rawValue) { m in
                            Text(m.displayName).tag(m.rawValue)
                        }
                    }
                    .onChange(of: claudeCodeModel) { WisprDefaults.shared.defaultClaudeCodeModel = $0 }
                } else {
                    LabeledContent("AWS region") {
                        TextField("us-east-1", text: $bedrockRegion)
                            .frame(width: 150)
                            .onSubmit { WisprDefaults.shared.claudeCodeBedrockRegion = bedrockRegion }
                    }
                    LabeledContent("AWS profile") {
                        TextField("(default chain)", text: $bedrockProfile)
                            .frame(width: 150)
                            .onSubmit { WisprDefaults.shared.claudeCodeBedrockProfile = bedrockProfile }
                    }
                    LabeledContent("Bedrock model ID") {
                        TextField("us.anthropic.claude-sonnet-4-…", text: $bedrockModel)
                            .frame(width: 220)
                            .onSubmit { WisprDefaults.shared.claudeCodeBedrockModel = bedrockModel }
                    }
                }
            }

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

    // MARK: Voice

    private var voiceSection: some View {
        Form {
            SwiftUI.Section {
                Text("Export a content-free summary of how you edit rewrites — counts and patterns only. No transcripts, names, or content. Safe to email to yourself and merge your voice across machines.")
                    .font(.callout)
                    .foregroundColor(.secondary)
                LabeledContent("Edits captured") {
                    Text("\(profileEditCount)").foregroundColor(.secondary)
                }
            }

            SwiftUI.Section("Preview — exactly what leaves the machine") {
                Text(profileEditCount == 0
                     ? "No edits captured yet. Edit a few rewrites first."
                     : profilePreview)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            SwiftUI.Section {
                HStack(spacing: 10) {
                    Button("Export…") { exportVoiceProfile() }
                        .disabled(profileEditCount == 0)
                    if let msg = exportMessage {
                        Text(msg).font(.caption).foregroundColor(.secondary)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding(.top, 4)
        .onAppear { refreshVoiceProfile() }
    }

    private var profileLabel: String {
        WisprDefaults.shared.claudeCodeAuthMode == "bedrock" ? "work" : "personal"
    }

    private func refreshVoiceProfile() {
        let label = profileLabel
        // Run synthesis off the main thread so mounting the pane never blocks the
        // UI; populate the preview when it's ready.
        Task { @MainActor in
            let result: (Int, String) = await Task.detached(priority: .userInitiated) {
                print("VoiceProfile: synthesizing…")
                let p = VoiceProfileSynthesizer.synthesize(label: label)
                let json = VoiceProfileSynthesizer.jsonString(p)
                print("VoiceProfile: done (\(p.editsAnalyzed) edits)")
                return (p.editsAnalyzed, json)
            }.value
            profileEditCount = result.0
            profilePreview = result.1
        }
    }

    private func exportVoiceProfile() {
        let json = VoiceProfileSynthesizer.jsonString(
            VoiceProfileSynthesizer.synthesize(label: profileLabel))
        let panel = NSSavePanel()
        panel.title = "Export Voice Profile"
        panel.nameFieldStringValue = "wispr-voice-profile-\(profileLabel).json"
        panel.allowedContentTypes = [.json]
        panel.canCreateDirectories = true
        if panel.runModal() == .OK, let url = panel.url {
            do {
                try json.data(using: .utf8)?.write(to: url)
                exportMessage = "Saved — email it to yourself."
            } catch {
                exportMessage = "Save failed: \(error.localizedDescription)"
            }
        }
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
            Divider().padding(.leading, 16)
            keyRow(
                provider: "gemini",
                label: "Google (Gemini)",
                icon: "globe",
                key: $geminiKey,
                status: $geminiStatus
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
                TextField("API key…", text: key)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { saveKey(provider, key.wrappedValue) }
                Button("Paste") {
                    if let str = NSPasteboard.general.string(forType: .string) {
                        let trimmed = str.trimmingCharacters(in: .whitespacesAndNewlines)
                        key.wrappedValue = trimmed
                        saveKey(provider, trimmed)
                    }
                }
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
            Label("Invalid key", systemImage: "xmark.circle.fill")
                .font(.caption).foregroundColor(.red)
        case .error(let msg):
            Label(msg, systemImage: "exclamationmark.triangle.fill")
                .font(.caption).foregroundColor(.orange)
                .help(msg)
        case .notSet:
            if KeychainService.shared.getKey(provider: provider) != nil {
                Label("Set", systemImage: "checkmark.circle.fill")
                    .font(.caption).foregroundColor(.green)
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
        if KeychainService.shared.getKey(provider: "gemini") != nil { geminiStatus = .notSet }
    }

    private func saveKey(_ provider: String, _ key: String) {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        KeychainService.shared.setKey(trimmed, provider: provider)
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
            } catch let err as RewriteError {
                await MainActor.run {
                    switch err {
                    case .apiError(let code, let msg):
                        if code == 401 || code == 403 {
                            statusBinding.wrappedValue = .invalid
                        } else {
                            let short = String(msg.prefix(60))
                            statusBinding.wrappedValue = .error("\(code): \(short)")
                        }
                    default:
                        statusBinding.wrappedValue = .error(err.localizedDescription)
                    }
                    isTesting = false
                }
            } catch {
                await MainActor.run {
                    statusBinding.wrappedValue = .error(String(error.localizedDescription.prefix(60)))
                    isTesting = false
                }
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
final class PreferencesWindowController: NSObject, NSWindowDelegate {
    static let shared = PreferencesWindowController()
    private var window: NSWindow?
    private override init() {}

    func show() {
        if window == nil {
            let host = NSHostingController(rootView: PreferencesView())
            let w = NSWindow(contentViewController: host)
            w.title = "Wispr — Preferences"
            w.styleMask = [.titled, .closable, .resizable]
            w.setContentSize(NSSize(width: 560, height: 360))
            w.center()
            w.setFrameAutosaveName("WisprPreferences")
            w.delegate = self
            window = w
        }
        // Promote to regular so the window receives keyboard focus (required for
        // paste to work in an .accessory-policy menu bar app).
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        // Return to accessory so the app stays out of the Dock and Cmd+Tab.
        NSApp.setActivationPolicy(.accessory)
    }
}
