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
            VStack(alignment: .leading, spacing: NexoraSpacing.xl) {
                // Header section with recipe image/icon and key info
                headerSection
                
                // Nutrition summary card
                nutritionSection
                
                // Ingredients section with servings stepper
                ingredientsSection
                
                // Steps section
                stepsSection
                
                // Notes section (if present)
                if let notes = recipe.notes, !notes.isEmpty {
                    notesSection(notes)
                }
            }
            .padding(.horizontal, NexoraSpacing.md)
            .padding(.bottom, NexoraSpacing.xl)
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
    
    // MARK: - Sections
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: NexoraSpacing.md) {
            // Recipe icon/illustration
            HStack {
                Spacer()
                Image(systemName: recipe.systemImage)
                    .font(.system(size: 56, weight: .light))
                    .foregroundStyle(recipe.category.color)
                    .frame(width: 80, height: 80)
                    .background(recipe.category.color.opacity(0.12))
                    .cornerRadius(NexoraRadius.lg)
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: NexoraSpacing.xs) {
                Text(recipe.name)
                    .font(NexoraTypography.largeTitle)
                    .fontWeight(.bold)
                    .foregroundStyle(NexoraColors.label)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, alignment: .center)
                
                Text(recipe.description)
                    .font(NexoraTypography.body)
                    .foregroundStyle(NexoraColors.secondaryLabel)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            // Key metrics row
            HStack(spacing: NexoraSpacing.lg) {
                MetricBadge(icon: "timer", value: "\(recipe.prepTimeMinutes) min", label: "Préparation")
                MetricBadge(icon: "flame.fill", value: recipe.cookTimeMinutes.map { "\($0) min" } ?? "—", label: "Cuisson")
                MetricBadge(icon: "person.2.fill", value: "\(recipe.servings) pers", label: "Portions")
                MetricBadge(icon: "chart.bar.fill", value: "\(recipe.totalTime) min", label: "Total")
            }
        }
    }
    
    private var nutritionSection: some View {
        let nutrition = recipe.estimatedNutrition(for: selectedServings)
        
        return VStack(alignment: .leading, spacing: NexoraSpacing.sm) {
            Text("Nutrition estimée (par portion)")
                .font(NexoraTypography.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(NexoraColors.label)
            
            HStack(spacing: NexoraSpacing.md) {
                NutritionMetric(
                    icon: "flame.fill",
                    value: "\(nutrition.calories)",
                    unit: "kcal",
                    label: "Calories",
                    color: .orange
                )
                NutritionMetric(
                    icon: "leaf.fill",
                    value: "\(nutrition.protein)",
                    unit: "g",
                    label: "Protéines",
                    color: .green
                )
            }
            
            Text("Valeurs approximatives calculées à partir des ingrédients.")
                .font(NexoraTypography.caption2)
                .foregroundStyle(NexoraColors.tertiaryLabel)
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(NexoraSpacing.md)
        .background(NexoraColors.cardBackground)
        .cornerRadius(NexoraRadius.md)
    }
    
    private var ingredientsSection: some View {
        VStack(alignment: .leading, spacing: NexoraSpacing.md) {
            HStack {
                Text("Ingrédients")
                    .font(NexoraTypography.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(NexoraColors.label)
                
                Spacer()
                
                // Servings stepper
                Stepper(value: $selectedServings, in: 1...12) {
                    Text("Pour \(selectedServings) personne\(selectedServings > 1 ? "s" : "")")
                        .font(NexoraTypography.body)
                        .fontWeight(.medium)
                        .foregroundStyle(NexoraColors.label)
                }
                .labelsHidden()
            }
            
            VStack(spacing: NexoraSpacing.xs) {
                ForEach(recipe.scaledIngredients(for: selectedServings)) { ingredient in
                    IngredientRow(ingredient: ingredient)
                }
            }
        }
    }
    
    private var stepsSection: some View {
        VStack(alignment: .leading, spacing: NexoraSpacing.md) {
            Text("Étapes de préparation")
                .font(NexoraTypography.title2)
                .fontWeight(.bold)
                .foregroundStyle(NexoraColors.label)
            
            VStack(spacing: NexoraSpacing.md) {
                ForEach(recipe.steps.indices, id: \.self) { index in
                    let step = recipe.steps[index]
                    StepRow(step: step, number: index + 1, isLast: index == recipe.steps.count - 1)
                }
            }
        }
    }
    
    private func notesSection(_ notes: String) -> some View {
        VStack(alignment: .leading, spacing: NexoraSpacing.sm) {
            Text("Remarques")
                .font(NexoraTypography.title2)
                .fontWeight(.bold)
                .foregroundStyle(NexoraColors.label)
            
            Text(notes)
                .font(NexoraTypography.body)
                .foregroundStyle(NexoraColors.secondaryLabel)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(NexoraSpacing.md)
        .background(NexoraColors.cardBackground)
        .cornerRadius(NexoraRadius.md)
    }
}

// MARK: - Supporting Views

private struct MetricBadge: View {
    let icon: String
    let value: String
    let label: String
    
    var body: some View {
        VStack(spacing: 2) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(NexoraColors.primary)
            Text(value)
                .font(NexoraTypography.subheadline)
                .fontWeight(.bold)
                .foregroundStyle(NexoraColors.label)
            Text(label)
                .font(NexoraTypography.caption2)
                .foregroundStyle(NexoraColors.secondaryLabel)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, NexoraSpacing.sm)
        .background(NexoraColors.cardBackground)
        .cornerRadius(NexoraRadius.md)
    }
}

private struct NutritionMetric: View {
    let icon: String
    let value: String
    let unit: String
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 2) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
            
            HStack(alignment: .lastTextBaseline, spacing: 1) {
                Text(value)
                    .font(NexoraTypography.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(NexoraColors.label)
                Text(unit)
                    .font(NexoraTypography.caption)
                    .foregroundStyle(NexoraColors.secondaryLabel)
            }
            
            Text(label)
                .font(NexoraTypography.caption)
                .foregroundStyle(NexoraColors.secondaryLabel)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, NexoraSpacing.sm)
        .background(NexoraColors.cardBackground)
        .cornerRadius(NexoraRadius.md)
    }
}

private struct IngredientRow: View {
    let ingredient: RecipeIngredient
    
    var body: some View {
        HStack(spacing: NexoraSpacing.md) {
            Circle()
                .fill(NexoraColors.primary)
                .frame(width: 8, height: 8)
            
            Text(ingredient.name)
                .font(NexoraTypography.body)
                .foregroundStyle(NexoraColors.label)
            
            Spacer()
            
            Text(ingredient.displayQuantity)
                .font(NexoraTypography.body)
                .fontWeight(.medium)
                .foregroundStyle(NexoraColors.secondaryLabel)
        }
        .padding(.vertical, 4)
    }
}

private struct StepRow: View {
    let step: RecipeStep
    let number: Int
    let isLast: Bool
    
    var body: some View {
        HStack(alignment: .top, spacing: NexoraSpacing.md) {
            // Number circle with connecting line
            VStack(spacing: 0) {
                ZStack {
                    Circle()
                        .fill(NexoraColors.primary)
                        .frame(width: 32, height: 32)
                    
                    Text("\(number)")
                        .font(NexoraTypography.body)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                }
                
                if !isLast {
                    Rectangle()
                        .fill(NexoraColors.primary.opacity(0.3))
                        .frame(width: 2)
                        .frame(maxHeight: .infinity)
                }
            }
            
            VStack(alignment: .leading, spacing: NexoraSpacing.xs) {
                Text(step.instruction)
                    .font(NexoraTypography.body)
                    .foregroundStyle(NexoraColors.label)
                    .fixedSize(horizontal: false, vertical: true)
                
                if let duration = step.durationMinutes {
                    Label("\(duration) min", systemImage: "timer")
                        .font(NexoraTypography.caption)
                        .foregroundStyle(NexoraColors.secondaryLabel)
                }
            }
        }
    }
}
