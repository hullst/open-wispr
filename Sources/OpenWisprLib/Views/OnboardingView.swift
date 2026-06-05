import SwiftUI
import AppKit

struct OnboardingView: View {
    var onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header
            HStack(spacing: 12) {
                Image(systemName: "waveform.and.mic")
                    .font(.system(size: 32))
                    .foregroundColor(.accentColor)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Welcome to Wispr")
                        .font(.title2.weight(.semibold))
                    Text("Dictation + rewriting, always on.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }

            Divider()

            // Step 1
            stepRow(
                icon: "globe",
                title: "Hold Globe key to dictate",
                body: "Hold the Globe / fn key, speak, release. Your words appear at the cursor — nothing else to click."
            )

            // Step 2
            stepRow(
                icon: "pencil.and.sparkles",
                title: "Rewrite from the menu bar",
                body: "Click the waveform icon → Rewrite Last Transcript to clean up what you just said. Pick a style and hit Rewrite."
            )

            // Step 3
            stepRow(
                icon: "keyboard",
                title: "Set a silent rewrite hotkey (optional)",
                body: "Assign a hotkey in Preferences → Hotkeys. Press it after dictating and the rewrite pastes instantly — no panel shown."
            )

            Divider()

            HStack {
                Spacer()
                Button("Open Preferences") {
                    onDismiss()
                    Task { @MainActor in PreferencesWindowController.shared.show() }
                }
                .buttonStyle(.bordered)
                Button("Get Started") { onDismiss() }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.return)
            }
        }
        .padding(24)
        .frame(width: 440)
    }

    private func stepRow(icon: String, title: String, body: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.accentColor)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.headline)
                Text(body).font(.subheadline).foregroundColor(.secondary)
            }
        }
    }
}

@MainActor
final class OnboardingWindowController {
    static let shared = OnboardingWindowController()
    private var window: NSWindow?
    private init() {}

    func showIfNeeded() {
        guard !WisprDefaults.shared.hasCompletedOnboarding else { return }
        show()
    }

    func show() {
        if window == nil {
            let host = NSHostingController(rootView: OnboardingView { [weak self] in
                self?.dismiss()
            })
            let w = NSWindow(contentViewController: host)
            w.title = "Welcome to Wispr"
            w.styleMask = [.titled, .closable]
            w.center()
            w.isReleasedWhenClosed = false
            window = w
        }
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func dismiss() {
        WisprDefaults.shared.hasCompletedOnboarding = true
        window?.orderOut(nil)
    }
}
