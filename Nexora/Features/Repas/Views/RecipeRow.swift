import SwiftUI

struct RecipeRow: View {
    let recipe: Recipe

    var body: some View {
        HStack(spacing: NexoraSpacing.md) {
            Image(systemName: recipe.systemImage)
                .font(.title2)
                .foregroundStyle(recipe.category.color)
                .frame(width: 50, height: 50)
                .background(recipe.category.color.opacity(0.15))
                .cornerRadius(NexoraRadius.sm)

            VStack(alignment: .leading, spacing: 4) {
                Text(recipe.name)
                    .font(NexoraTypography.title3)
                    .fontWeight(.medium)
                    .foregroundStyle(NexoraColors.label)

                Text(recipe.description)
                    .font(NexoraTypography.caption)
                    .foregroundStyle(NexoraColors.secondaryLabel)
                    .lineLimit(1)

                HStack {
                    Label("\(recipe.totalTime) min", systemImage: "clock")
                    Label("\(recipe.servings) pers", systemImage: "person")
                }
                .font(NexoraTypography.caption)
                .foregroundStyle(NexoraColors.secondaryLabel)
            }

            Spacer()

            if MealService.shared.isFavorite(recipe: recipe) {
                Image(systemName: "heart.fill")
                    .foregroundStyle(NexoraColors.primary)
            }
        }
        .padding(.vertical, NexoraSpacing.sm)
    }
}
