import SwiftUI

struct RecipeCatalogView: View {
    @ObservedObject private var mealService = MealService.shared
    @State private var searchText = ""
    let selectedCategory: MealCategory? = nil

    var filteredRecipes: [Recipe] {
        mealService.recipes
            .filter { recipe in
                if let category = selectedCategory {
                    return recipe.category == category
                }
                return true
            }
            .filter { recipe in
                searchText.isEmpty || recipe.name.localizedCaseInsensitiveContains(searchText)
            }
    }

    var body: some View {
        List {
            ForEach(Array(filteredRecipes)) { recipe in
                NavigationLink(destination: RecipeDetailView(recipe: recipe)) {
                    RecipeRow(recipe: recipe)
                }
            }
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
        }
        .listStyle(.insetGrouped)
        .navigationTitle(titleText)
        .navigationBarTitleDisplayMode(.large)
        .searchable(text: $searchText)
    }

    private var titleText: String {
        switch selectedCategory {
        case .express: return "Semaine express"
        case .gourmand: return "Semaine gourmande"
        case .weekend: return "Week-end"
        case .none: return "Toutes les recettes"
        }
    }
}

struct RecipeCatalogView_Previews: PreviewProvider {
    static var previews: some View {
        RecipeCatalogView()
    }
}
