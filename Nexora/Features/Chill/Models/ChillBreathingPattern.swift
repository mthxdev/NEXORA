import Foundation

enum ChillBreathingMode: String, CaseIterable, Identifiable {
    case coherence
    case fourSix
    case fourFour
    case custom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .coherence: return "Cohérence cardiaque"
        case .fourSix: return "Respiration 4 / 6"
        case .fourFour: return "Respiration 4 / 4"
        case .custom: return "Personnalisée"
        }
    }

    var subtitle: String {
        switch self {
        case .coherence: return "Un rythme équilibré, cinq secondes par souffle."
        case .fourSix: return "Une expiration plus longue pour ralentir le rythme."
        case .fourFour: return "Un rythme régulier et facile à suivre."
        case .custom: return "Choisissez votre propre rythme, sans forcer."
        }
    }

    func pattern(customInhale: Int, customExhale: Int) -> ChillBreathingPattern {
        switch self {
        case .coherence: return .coherence
        case .fourSix: return .fourSix
        case .fourFour: return .fourFour
        case .custom:
            return ChillBreathingPattern(
                inhaleSeconds: customInhale,
                exhaleSeconds: customExhale
            )
        }
    }
}

struct ChillBreathingPattern: Equatable {
    static let customRange = 2...10

    let inhaleSeconds: Int
    let exhaleSeconds: Int

    init(inhaleSeconds: Int, exhaleSeconds: Int) {
        self.inhaleSeconds = min(max(inhaleSeconds, Self.customRange.lowerBound), Self.customRange.upperBound)
        self.exhaleSeconds = min(max(exhaleSeconds, Self.customRange.lowerBound), Self.customRange.upperBound)
    }

    static let coherence = ChillBreathingPattern(inhaleSeconds: 5, exhaleSeconds: 5)
    static let fourSix = ChillBreathingPattern(inhaleSeconds: 4, exhaleSeconds: 6)
    static let fourFour = ChillBreathingPattern(inhaleSeconds: 4, exhaleSeconds: 4)

    var cycleSeconds: Int { inhaleSeconds + exhaleSeconds }
}
