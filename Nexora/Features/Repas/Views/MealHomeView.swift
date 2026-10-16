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

                suggestionSection

                categorySection

                catalogLinkSection

                favoritesLinkSection
            }
            .padding(.vertical)
        }
        .navigationBarTitleDisplayMode(.large)
    }

    @ViewBuilder
    private var suggestionSection: some View {
        VStack(alignment: .leading, spacing: NexoraSpacing.sm) {
            Text("Une idée pour aujourd'hui")
                .font(NexoraTypography.headline)
                .foregroundStyle(NexoraColors.label)
                .padding(.horizontal)

            if let suggestion = viewModel.suggestion {
                NavigationLink(destination: RecipeDetailView(recipe: suggestion)) {
                    MealSuggestionView(recipe: suggestion)
                }
                .buttonStyle(.plain)
                .padding(.horizontal)

                suggestionActionButton
            } else {
                Text("Aucune recette disponible dans le catalogue.")
                    .font(NexoraTypography.caption)
                    .foregroundStyle(NexoraColors.secondaryLabel)
                    .padding(.horizontal)
            }
        }
    }

    @ViewBuilder
    private var suggestionActionButton: some View {
        if viewModel.hasAlternative {
            Button {
                viewModel.refreshSuggestion()
            } label: {
                Label("Autre idée", systemImage: "arrow.clockwise")
                    .font(NexoraTypography.body)
                    .fontWeight(.medium)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, NexoraSpacing.sm)
                    .background(NexoraColors.cardBackground)
                    .cornerRadius(NexoraRadius.md)
            }
            .padding(.horizontal)
        } else if viewModel.suggestion != nil {
            Text("Il n'y a pas d'autre recette disponible dans cette catégorie.")
                .font(NexoraTypography.caption)
                .foregroundStyle(NexoraColors.secondaryLabel)
                .padding(.horizontal)
        }
    }

    private var categorySection: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: NexoraSpacing.md) {
            ForEach(MealCategory.allCases) { category in
                NavigationLink(destination: RecipeCatalogView(selectedCategory: category)) {
                    CategoryCard(category: category)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal)
    }

    private var catalogLinkSection: some View {
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
    }

    private var favoritesLinkSection: some View {
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
        return "\(count) recette\(count > 1 ? "s" : "")"
    }
}

final class MealHomeViewModel: ObservableObject {
    @Published var suggestion: Recipe?
    private var lastSuggestedID: UUID?

    init() {
        refreshSuggestion()
    }

    func refreshSuggestion() {
        let recipe = MealService.shared.suggestRecipe(for: Date(), excluding: lastSuggestedID)

        if let recipe {
            suggestion = recipe
            lastSuggestedID = recipe.id
        } else if suggestion == nil {
            suggestion = MealService.shared.suggestRecipe(for: Date())
            lastSuggestedID = suggestion?.id
        }
    }

    var hasAlternative: Bool {
        guard let current = suggestion else { return false }
        let candidates = MealService.shared.suggestedRecipes(for: Date())
        return candidates.contains { $0.id != current.id }
    }
}
