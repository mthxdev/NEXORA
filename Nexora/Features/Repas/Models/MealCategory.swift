import Foundation
import SwiftUI

enum MealCategory: String, CaseIterable, Identifiable {
    case express = "Semaine express"
    case gourmand = "Semaine gourmande"
    case weekend = "Week-end"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .express: return "timer"
        case .gourmand: return "flame.fill"
        case .weekend: return "star.fill"
        }
    }

    var color: Color {
        switch self {
        case .express: return NexoraColors.blue
        case .gourmand: return NexoraColors.orange
        case .weekend: return NexoraColors.purple
        }
    }

    var sortOrder: Int {
        switch self {
        case .express: return 0
        case .gourmand: return 1
        case .weekend: return 2
        }
    }
}
