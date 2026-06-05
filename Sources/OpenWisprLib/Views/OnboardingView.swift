import SwiftUI
import AppKit

struct OnboardingView: View {
    var onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header toolbar — matches History/Rewrite/Preferences style
            HStack(spacing: 12) {
                Image(systemName: "waveform.and.mic")
                    .font(.title2)
                    .foregroundColor(.accentColor)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Welcome to Wispr")
                        .font(.headline)
                    Text("Dictation + rewriting, always on.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            // Steps — same row style as History list
            stepRow(
                icon: "globe",
                title: "Hold Globe key to dictate",
                body: "Hold Globe / fn, speak, release. Words appear at your cursor instantly."
            )
            Divider().padding(.leading, 50)

            stepRow(
                icon: "pencil.and.sparkles",
                title: "Rewrite from the menu bar",
                body: "Click the waveform icon → Rewrite Last Transcript. Pick a style and hit Rewrite."
            )
            Divider().padding(.leading, 50)

            stepRow(
                icon: "keyboard",
                title: "Set a silent rewrite hotkey",
                body: "In Preferences → Hotkeys, assign a chord. Press it after dictating — rewrites and pastes with no panel."
            )

            Spacer()

            Divider()

            // Footer toolbar — matches History toolbar style
            HStack {
                Button("Open Preferences") {
                    onDismiss()
                    Task { @MainActor in PreferencesWindowController.shared.show() }
                }
                .buttonStyle(.bordered)
                Spacer()
                Button("Get Started") { onDismiss() }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.return)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color(NSColor.controlBackgroundColor))
        }
        .frame(width: 480)
    }

    private func stepRow(icon: String, title: String, body: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.body)
                .foregroundColor(.accentColor)
                .frame(width: 22)
                .padding(.top, 1)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.subheadline.weight(.medium))
                Text(body).font(.caption).foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
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
            w.title = "Wispr — Welcome"
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
