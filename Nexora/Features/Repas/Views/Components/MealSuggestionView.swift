import SwiftUI

struct MealSuggestionView: View {
    let recipe: Recipe

    var body: some View {
        VStack(alignment: .leading, spacing: NexoraSpacing.sm) {
            Text("Suggestion du jour")
                .font(NexoraTypography.caption)
                .foregroundStyle(NexoraColors.secondaryLabel)

            Text(recipe.name)
                .font(NexoraTypography.title2)
                .fontWeight(.bold)
                .foregroundStyle(NexoraColors.label)

            Text(recipe.description)
                .font(NexoraTypography.body)
                .foregroundStyle(NexoraColors.secondaryLabel)
                .lineLimit(2)

            HStack {
                Label("\(recipe.totalTime) min", systemImage: "clock")
                Label("\(recipe.servings) pers", systemImage: "person")
            }
            .font(NexoraTypography.caption)
            .foregroundStyle(NexoraColors.secondaryLabel)

            Image(systemName: recipe.systemImage)
                .font(.system(size: 32))
                .foregroundStyle(recipe.category.color)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding()
        .background(NexoraColors.cardBackground)
        .cornerRadius(NexoraRadius.md)
    }
}
