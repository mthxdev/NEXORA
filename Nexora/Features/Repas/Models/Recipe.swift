import Foundation
import SwiftData

struct RecipeIngredient: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let quantity: Double
    let unit: String

    var displayQuantity: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = quantity.truncatingRemainder(dividingBy: 1) == 0 ? 0 : 1

        if let formatted = formatter.string(from: NSNumber(value: quantity)) {
            return "\(formatted) \(unit)"
        }
        return "\(quantity) \(unit)"
    }

    func scaled(by factor: Double) -> RecipeIngredient {
        RecipeIngredient(name: name, quantity: quantity * factor, unit: unit)
    }
}

struct RecipeStep: Identifiable, Hashable {
    let id = UUID()
    let instruction: String
    let durationMinutes: Int?

    var durationDisplay: String {
        if let duration = durationMinutes {
            return "\(duration) min"
        }
        return ""
    }
}

struct Recipe: Identifiable, Hashable {
    let id: UUID
    let name: String
    let description: String
    let category: MealCategory
    let ingredients: [RecipeIngredient]
    let servings: Int
    let prepTimeMinutes: Int
    let cookTimeMinutes: Int?
    let steps: [RecipeStep]
    let notes: String?
    let systemImage: String

    var totalTime: Int {
        var total = prepTimeMinutes
        if let cook = cookTimeMinutes {
            total += cook
        }
        return total
    }

    var estimatedCaloriesPerServing: Int {
        let db = NutritionDatabase.shared
        let totalCalories = ingredients.reduce(0) { result, ingredient in
            result + db.caloriesAndProtein(for: ingredient.name, quantity: ingredient.quantity, unit: ingredient.unit).calories
        }
        return servings > 0 ? totalCalories / servings : 0
    }

    var estimatedProteinPerServing: Int {
        let db = NutritionDatabase.shared
        let totalProtein = ingredients.reduce(0) { result, ingredient in
            result + db.caloriesAndProtein(for: ingredient.name, quantity: ingredient.quantity, unit: ingredient.unit).protein
        }
        return servings > 0 ? totalProtein / servings : 0
    }

    func scaledIngredients(for servings: Int) -> [RecipeIngredient] {
        guard servings > 0 else { return ingredients }
        let factor = Double(servings) / Double(self.servings)
        return ingredients.map { $0.scaled(by: factor) }
    }

    func estimatedNutrition(for servings: Int) -> (calories: Int, protein: Int) {
        guard self.servings > 0 else { return (0, 0) }
        let db = NutritionDatabase.shared
        let totalCalories = ingredients.reduce(0) { result, ingredient in
            result + db.caloriesAndProtein(for: ingredient.name, quantity: ingredient.quantity, unit: ingredient.unit).calories
        }
        let totalProtein = ingredients.reduce(0) { result, ingredient in
            result + db.caloriesAndProtein(for: ingredient.name, quantity: ingredient.quantity, unit: ingredient.unit).protein
        }
        return (totalCalories / self.servings, totalProtein / self.servings)
    }
}

@Model
final class FavoriteRecipe {
    var id: UUID
    var recipeID: String
    var dateAdded: Date

    init(recipeID: String) {
        self.id = UUID()
        self.recipeID = recipeID
        self.dateAdded = Date()
    }
}
