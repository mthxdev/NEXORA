import Foundation

// Audio is bundled locally so a session never depends on a network connection.
enum ChillAmbience: String, CaseIterable, Identifiable {
    case none
    case rain
    case fire
    case ocean
    case forest
    case night

    var id: String { rawValue }

    var title: String {
        switch self {
        case .none: return "Sans son"
        case .rain: return "Pluie"
        case .fire: return "Feu de cheminée"
        case .ocean: return "Vagues"
        case .forest: return "Forêt"
        case .night: return "Nuit"
        }
    }

    var symbol: String {
        switch self {
        case .none: return "speaker.slash"
        case .rain: return "cloud.rain.fill"
        case .fire: return "flame.fill"
        case .ocean: return "water.waves"
        case .forest: return "leaf.fill"
        case .night: return "moon.stars.fill"
        }
    }

    var resourceName: String? {
        switch self {
        case .none: return nil
        case .rain: return "chill_rain"
        case .fire: return "chill_fire"
        case .ocean: return "chill_ocean"
        case .forest: return "chill_forest"
        case .night: return "chill_night"
        }
    }
}
