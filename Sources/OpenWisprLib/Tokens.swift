// Tokens.swift — Rewriter design tokens for SwiftUI.
// Colors are defined in code here for convenience, but the RECOMMENDED path is an
// Asset Catalog color set per token with "Any/Dark" appearances (see README) so the
// OS handles light/dark. The hex values below match those color sets exactly.

import SwiftUI

extension Color {
    init(hex: UInt, alpha: Double = 1) {
        self.init(.sRGB,
                  red:   Double((hex >> 16) & 0xff) / 255,
                  green: Double((hex >>  8) & 0xff) / 255,
                  blue:  Double( hex        & 0xff) / 255,
                  opacity: alpha)
    }
}

/// Semantic palette. Prefer `Color("AppBg")` from the Asset Catalog in real code;
/// these dynamic colors are a drop-in if you're prototyping before the catalog exists.
enum Theme {
    static func dynamic(_ light: Color, _ dark: Color) -> Color {
        Color(nsColor: NSColor(name: nil) { $0.bestMatch(from: [.darkAqua]) == .darkAqua
            ? NSColor(dark) : NSColor(light) })
    }

    // backgrounds
    static let appBg     = dynamic(Color(hex: 0xFFFFFF), Color(hex: 0x1C1C1E))
    static let surface   = dynamic(Color(hex: 0xFFFFFF), Color(hex: 0x242426))
    static let inputBg   = dynamic(Color(hex: 0xFFFFFF), Color(hex: 0x212123))
    static let panel     = dynamic(Color(hex: 0xF5F5F7), Color(hex: 0x2C2C2E))
    static let panelSoft = dynamic(Color(hex: 0xFAFAFA), Color(hex: 0x202022))

    // lines
    static let border    = dynamic(Color(hex: 0x000000, alpha: 0.08), Color(hex: 0xFFFFFF, alpha: 0.10))
    static let borderMid = dynamic(Color(hex: 0x000000, alpha: 0.13), Color(hex: 0xFFFFFF, alpha: 0.16))
    static let hair      = dynamic(Color(hex: 0x000000, alpha: 0.06), Color(hex: 0xFFFFFF, alpha: 0.07))

    // text
    static let text      = dynamic(Color(hex: 0x1D1D1F), Color(hex: 0xF5F5F7))
    static let text2     = dynamic(Color(hex: 0x6E6E73), Color(hex: 0xA1A1A6))
    static let text3     = dynamic(Color(hex: 0x9B9BA1), Color(hex: 0x6E6E73))

    // accent + semantic (same in both appearances)
    static let accent     = Color(hex: 0x0A6CFF)
    static let accentSoft = dynamic(Color(hex: 0x0A6CFF, alpha: 0.10), Color(hex: 0x0A6CFF, alpha: 0.22))
    static let accentLine = dynamic(Color(hex: 0x0A6CFF, alpha: 0.35), Color(hex: 0x0A6CFF, alpha: 0.50))
    static let online     = Color(hex: 0x30D158)
    static let recording  = Color(hex: 0xFF453A)
}

/// Type roles. SF Pro IS the system font, so the system styles already match our scale —
/// reach for explicit sizes only where the design diverges from a stock role.
enum Type {
    static let output   = Font.system(size: 15, weight: .regular)          // line spacing ~ +6
    static let body     = Font.system(size: 14.5, weight: .regular)
    static let control  = Font.system(size: 13.5, weight: .semibold)
    static let label    = Font.system(size: 10.5, weight: .semibold)       // + .textCase(.uppercase) + tracking 0.9
    static let badge    = Font.system(size: 10, weight: .semibold)
    static let mono     = Font.system(size: 12, weight: .regular, design: .monospaced) // char counts, ⌘↵, gemma2:9b, 3.2s
}

/// Radius scale.
enum Radii {
    static let window: CGFloat = 12   // OS-owned; reference only
    static let card: CGFloat = 12
    static let control: CGFloat = 9   // button / picker / dropdown
    static let segment: CGFloat = 7   // active segmented pill
    static let pill: CGFloat = 8
    static let badge: CGFloat = 5
    static let toast: CGFloat = 999
}
