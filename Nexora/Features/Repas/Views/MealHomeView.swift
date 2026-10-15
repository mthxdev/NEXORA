import SwiftUI

struct MealHomeView: View {
    @StateObject private var viewModel = MealHomeViewModel()

    var body: some View {
        ScrollView {
            LazyVStack(spacing: NexoraSpacing.md) {
                Text("Repas")
                    .font(NexoraTypography.largeTitle)
                    .fontWeight(.bold)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)

                if let suggestion = viewModel.suggestion {
                    NavigationLink(destination: RecipeDetailView(recipe: suggestion)) {
                        MealSuggestionView(recipe: suggestion)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal)
                }

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: NexoraSpacing.md) {
                    ForEach(MealCategory.allCases) { category in
                        NavigationLink(destination: RecipeCatalogView(selectedCategory: category)) {
                            CategoryCard(category: category)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)

                NavigationLink(destination: RecipeCatalogView()) {
                    HStack {
                        Image(systemName: "books.vertical")
                        Text("Toutes les recettes")
                    }
                    .font(NexoraTypography.body)
                    .fontWeight(.medium)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(NexoraColors.cardBackground)
                    .cornerRadius(NexoraRadius.md)
                }
                .buttonStyle(.plain)
                .padding(.horizontal)

                NavigationLink(destination: FavoritesView()) {
                    HStack {
                        Image(systemName: "heart.fill")
                        Text("Recettes favorites")
                    }
                    .font(NexoraTypography.body)
                    .fontWeight(.medium)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(NexoraColors.cardBackground)
                    .cornerRadius(NexoraRadius.md)
                }
                .buttonStyle(.plain)
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .navigationBarTitleDisplayMode(.large)
    }
}

struct CategoryCard: View {
    let category: MealCategory

    var body: some View {
        VStack(alignment: .leading, spacing: NexoraSpacing.sm) {
            Text(category.rawValue)
                .font(NexoraTypography.title3)
                .fontWeight(.bold)
                .foregroundStyle(category.color)
            Image(systemName: category.icon)
                .font(.largeTitle)
                .foregroundStyle(category.color)
            Text(samplesCountText)
                .font(NexoraTypography.caption)
                .foregroundStyle(NexoraColors.secondaryLabel)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(category.color.opacity(0.1))
        .cornerRadius(NexoraRadius.md)
    }

    private var samplesCountText: String {
        let count = SampleRecipes.all.filter { $0.category == category }.count
        return "\(count) recettes"
    }
}

final class MealHomeViewModel: ObservableObject {
    @Published var suggestion: Recipe?

    init() {
        suggestion = MealService.shared.randomRecipe()
    }
}
