import SwiftUI

struct RecipeRow: View {
    let recipe: Recipe
    
    var body: some View {
        HStack(spacing: NexoraSpacing.md) {
            Image(systemName: recipe.systemImage)
                .font(.title2)
                .foregroundStyle(recipe.category.color)
                .frame(width: 56, height: 56)
                .background(recipe.category.color.opacity(0.15))
                .cornerRadius(NexoraRadius.md)
            
            VStack(alignment: .leading, spacing: NexoraSpacing.xs) {
                Text(recipe.name)
                    .font(NexoraTypography.title3)
                    .fontWeight(.medium)
                    .foregroundStyle(NexoraColors.label)
                
                Text(recipe.description)
                    .font(NexoraTypography.caption)
                    .foregroundStyle(NexoraColors.secondaryLabel)
                    .lineLimit(2)
                
                HStack(spacing: NexoraSpacing.md) {
                    Label {
                        Text("\(recipe.prepTimeMinutes) min")
                    } icon: {
                        Image(systemName: "timer")
                    }
                    if let cookTime = recipe.cookTimeMinutes {
                        Label {
                            Text("\(cookTime) min")
                        } icon: {
                            Image(systemName: "flame.fill")
                        }
                    }
                    Label {
                        Text("\(recipe.servings) pers")
                    } icon: {
                        Image(systemName: "person.2.fill")
                    }
                }
                .font(NexoraTypography.caption)
                .foregroundStyle(NexoraColors.secondaryLabel)
            }
            
            Spacer(minLength: NexoraSpacing.md)
            
            if MealService.shared.isFavorite(recipe: recipe) {
                Image(systemName: "heart.fill")
                    .foregroundStyle(NexoraColors.primary)
                    .font(.title3)
            }
        }
        .padding(.vertical, NexoraSpacing.xs)
    }
}
