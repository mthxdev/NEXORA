import SwiftUI

enum AppAppearance: String, CaseIterable {
    case system = "Système"
    case light = "Clair"
    case dark = "Sombre"

    var icon: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .light: return "sun.max.fill"
        case .dark: return "moon.fill"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

enum AppLogo: String, CaseIterable {
    case classic = "Classique"
    case gradient = "Dégradé"
    case minimal = "Minimal"
    case bold = "Bold"
    case mono = "Mono"

    var displayName: String { rawValue }

    var assetName: String {
        switch self {
        case .classic: return "NexoraLogo"
        case .gradient: return "NexoraLogoGradient"
        case .minimal: return "NexoraLogoMinimal"
        case .bold: return "NexoraLogoBold"
        case .mono: return "NexoraLogoMono"
        }
    }

    var previewColor: Color {
        switch self {
        case .classic: return Color(red: 0.15, green: 0.2, blue: 0.45)
        case .gradient: return Color(red: 0.1, green: 0.15, blue: 0.4)
        case .minimal: return Color(red: 0.2, green: 0.25, blue: 0.5)
        case .bold: return Color(red: 0.08, green: 0.12, blue: 0.35)
        case .mono: return Color(red: 0.12, green: 0.18, blue: 0.4)
        }
    }
}
