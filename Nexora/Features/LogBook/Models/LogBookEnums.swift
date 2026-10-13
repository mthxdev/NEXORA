import Foundation
import SwiftData

enum LogBookCategory: String, CaseIterable, Codable {
    case movie = "Films"
    case series = "Séries"
    case anime = "Animés"
    case game = "Jeux vidéo"
    case project = "Projets"
    case learning = "Apprentissages"
    
    var icon: String {
        switch self {
        case .movie: return "film.fill"
        case .series: return "tv.fill"
        case .anime: return "sparkles.tv.fill"
        case .game: return "gamecontroller.fill"
        case .project: return "folder.fill.badge.gearshape"
        case .learning: return "book.fill"
        }
    }
    
    var color: String {
        switch self {
        case .movie: return "red"
        case .series: return "blue"
        case .anime: return "pink"
        case .game: return "green"
        case .project: return "orange"
        case .learning: return "purple"
        }
    }
}

enum MediaStatus: String, CaseIterable, Codable {
    case toWatch = "À voir"
    case inProgress = "En cours"
    case completed = "Vu"
    case abandoned = "Abandonné"
    
    var icon: String {
        switch self {
        case .toWatch: return "circle"
        case .inProgress: return "play.circle"
        case .completed: return "checkmark.circle.fill"
        case .abandoned: return "xmark.circle"
        }
    }
}

enum SeriesStatus: String, CaseIterable, Codable {
    case toStart = "À commencer"
    case inProgress = "En cours"
    case completed = "Terminée"
    case abandoned = "Abandonnée"
    
    var icon: String {
        switch self {
        case .toStart: return "circle"
        case .inProgress: return "play.circle"
        case .completed: return "checkmark.circle.fill"
        case .abandoned: return "xmark.circle"
        }
    }
}

enum ProjectStatus: String, CaseIterable, Codable {
    case planning = "Planification"
    case active = "Actif"
    case onHold = "En pause"
    case completed = "Terminé"
    case cancelled = "Annulé"
    
    var icon: String {
        switch self {
        case .planning: return "doc.text"
        case .active: return "play.circle"
        case .onHold: return "pause.circle"
        case .completed: return "checkmark.circle.fill"
        case .cancelled: return "xmark.circle"
        }
    }
}

enum LearningStatus: String, CaseIterable, Codable {
    case notStarted = "Non commencé"
    case inProgress = "En cours"
    case completed = "Terminé"
    case paused = "En pause"
    
    var icon: String {
        switch self {
        case .notStarted: return "circle"
        case .inProgress: return "play.circle"
        case .completed: return "checkmark.circle.fill"
        case .paused: return "pause.circle"
        }
    }
}

enum Priority: String, CaseIterable, Codable {
    case low = "Basse"
    case medium = "Moyenne"
    case high = "Haute"
    case critical = "Critique"
    
    var color: String {
        switch self {
        case .low: return "green"
        case .medium: return "yellow"
        case .high: return "orange"
        case .critical: return "red"
        }
    }
}