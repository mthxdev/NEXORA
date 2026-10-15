import Foundation
import SwiftUI
import SwiftData

final class MealService: ObservableObject {
    static let shared = MealService()

    @Published private(set) var recipes: [Recipe] = SampleRecipes.all
    @Published private(set) var favorites: [FavoriteRecipe] = []
    private var modelContext: ModelContext?

    private init() {}

    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
        loadFavorites()
    }

    var favoriteRecipeIDs: Set<String> {
        Set(favorites.map { $0.recipeID })
    }

    func isFavorite(recipe: Recipe) -> Bool {
        favoriteRecipeIDs.contains(recipe.id.uuidString)
    }

    func toggleFavorite(recipe: Recipe) {
        guard let context = modelContext else { return }

        if isFavorite(recipe: recipe) {
            if let favorite = favorites.first(where: { $0.recipeID == recipe.id.uuidString }) {
                context.delete(favorite)
                favorites.removeAll { $0.id == favorite.id }
            }
        } else {
            let favorite = FavoriteRecipe(recipeID: recipe.id.uuidString)
            context.insert(favorite)
            favorites.append(favorite)
        }

        try? context.save()
    }

    private func loadFavorites() {
        guard let context = modelContext else { return }
        let descriptor = FetchDescriptor<FavoriteRecipe>()
        favorites = (try? context.fetch(descriptor)) ?? []
    }

    func recipe(for id: String) -> Recipe? {
        recipes.first { $0.id.uuidString == id }
    }

    func randomRecipe() -> Recipe? {
        recipes.randomElement()
    }

    func randomRecipe(excluding category: MealCategory? = nil) -> Recipe? {
        let pool: [Recipe]
        if let category {
            pool = recipes.filter { $0.category != category }
        } else {
            pool = recipes
        }
        return pool.randomElement()
    }

    func favoriteRecipes() -> [Recipe] {
        favorites.compactMap { recipe(for: $0.recipeID) }
    }
}
