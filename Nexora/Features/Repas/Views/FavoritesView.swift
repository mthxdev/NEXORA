import SwiftUI
import SwiftData

struct FavoritesView: View {
    @Query(sort: \FavoriteRecipe.dateAdded, order: .reverse) private var favorites: [FavoriteRecipe]

    private var favoriteRecipes: [Recipe] {
        favorites.compactMap { MealService.shared.recipe(for: $0.recipeID) }
    }

    var body: some View {
        Group {
            if favoriteRecipes.isEmpty {
                EmptyStateView(
                    icon: "heart.slash",
                    title: "Aucune recette favorite",
                    description: "Ajoutez des recettes à vos favoris depuis la vue détaillée"
                )
            } else {
                List {
                    ForEach(Array(favoriteRecipes)) { recipe in
                        NavigationLink(destination: RecipeDetailView(recipe: recipe)) {
                            RecipeRow(recipe: recipe)
                        }
                    }
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("Favoris")
        .navigationBarTitleDisplayMode(.large)
    }
}
