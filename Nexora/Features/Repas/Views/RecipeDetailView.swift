import SwiftUI

struct RecipeDetailView: View {
    let recipe: Recipe
    @State private var selectedServings: Int
    @ObservedObject private var mealService = MealService.shared

    init(recipe: Recipe) {
        self.recipe = recipe
        _selectedServings = State(initialValue: recipe.servings)
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: NexoraSpacing.lg) {
                VStack(alignment: .leading, spacing: NexoraSpacing.sm) {
                    Text(recipe.name)
                        .font(NexoraTypography.largeTitle)
                        .fontWeight(.bold)
                        .foregroundStyle(NexoraColors.label)

                    Text(recipe.description)
                        .font(NexoraTypography.body)
                        .foregroundStyle(NexoraColors.secondaryLabel)

                    HStack {
                        Label("\(recipe.totalTime) min", systemImage: "clock")
                        Label("\(recipe.servings) pers", systemImage: "person")
                    }
                    .font(NexoraTypography.caption)
                    .foregroundStyle(NexoraColors.secondaryLabel)
                }

                VStack(alignment: .leading, spacing: NexoraSpacing.sm) {
                    Label("Nutrition estimée", systemImage: "chart.bar.xaxis")
                        .font(NexoraTypography.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(NexoraColors.label)

                    let nutrition = recipe.estimatedNutrition(for: selectedServings)
                    HStack {
                        VStack(alignment: .center) {
                            Text("\(nutrition.calories)")
                                .font(NexoraTypography.title2)
                                .fontWeight(.bold)
                                .foregroundStyle(NexoraColors.primary)
                            Text("Calories (approx.)")
                                .font(NexoraTypography.caption2)
                                .foregroundStyle(NexoraColors.secondaryLabel)
                        }
                        Spacer()
                        VStack(alignment: .center) {
                            Text("\(nutrition.protein) g")
                                .font(NexoraTypography.title2)
                                .fontWeight(.bold)
                                .foregroundStyle(NexoraColors.primary)
                            Text("Protéines (approx.)")
                                .font(NexoraTypography.caption2)
                                .foregroundStyle(NexoraColors.secondaryLabel)
                        }
                    }

                    Text("Valeurs nutritionnelles estimées à partir des ingrédients. Les valeurs réelles peuvent varier.")
                        .font(NexoraTypography.caption2)
                        .foregroundStyle(NexoraColors.secondaryLabel)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                }
                .padding()
                .background(NexoraColors.cardBackground)
                .cornerRadius(NexoraRadius.md)

                VStack(alignment: .leading, spacing: NexoraSpacing.sm) {
                    Text("Ingrédients")
                        .font(NexoraTypography.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(NexoraColors.label)

                    Stepper(value: $selectedServings, in: 1...8) {
                        Text("Pour \(selectedServings) personne\(selectedServings > 1 ? "s" : "")")
                    }
                    .font(NexoraTypography.body)
                    .foregroundStyle(NexoraColors.label)

                    ForEach(recipe.scaledIngredients(for: selectedServings)) { ingredient in
                        HStack {
                            Image(systemName: "checkmark.circle")
                                .foregroundStyle(NexoraColors.primary)
                            Text(ingredient.name)
                            Spacer()
                            Text(ingredient.displayQuantity)
                                .foregroundStyle(NexoraColors.secondaryLabel)
                        }
                        .font(NexoraTypography.body)
                    }
                }

                VStack(alignment: .leading, spacing: NexoraSpacing.md) {
                    Text("Étapes")
                        .font(NexoraTypography.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(NexoraColors.label)

                    ForEach(recipe.steps.indices, id: \.self) { index in
                        let step = recipe.steps[index]
                        HStack(alignment: .top, spacing: NexoraSpacing.sm) {
                            Text("\(index + 1)")
                                .font(NexoraTypography.caption2)
                                .fontWeight(.bold)
                                .foregroundStyle(NexoraColors.primary)
                                .frame(minWidth: 24, minHeight: 24)
                                .background(NexoraColors.primary.opacity(0.1))
                                .cornerRadius(NexoraRadius.full)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(step.instruction)
                                    .font(NexoraTypography.body)
                                    .foregroundStyle(NexoraColors.label)

                                if step.durationMinutes != nil {
                                    Text(step.durationDisplay)
                                        .font(NexoraTypography.caption2)
                                        .foregroundStyle(NexoraColors.secondaryLabel)
                                }
                            }
                        }
                    }
                }

                if recipe.notes != nil {
                    VStack(alignment: .leading, spacing: NexoraSpacing.sm) {
                        Text("Remarques")
                            .font(NexoraTypography.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(NexoraColors.label)

                        Text(recipe.notes!)
                            .font(NexoraTypography.body)
                            .foregroundStyle(NexoraColors.secondaryLabel)
                    }
                }
            }
            .padding()
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    mealService.toggleFavorite(recipe: recipe)
                } label: {
                    Image(systemName: mealService.isFavorite(recipe: recipe) ? "heart.fill" : "heart")
                }
                .foregroundStyle(NexoraColors.primary)
            }
        }
    }
}
