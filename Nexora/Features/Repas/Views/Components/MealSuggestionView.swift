import SwiftUI

struct MealSuggestionView: View {
    let recipe: Recipe
    
    var body: some View {
        VStack(alignment: .leading, spacing: NexoraSpacing.md) {
            // Header
            HStack {
                Text("Suggestion du jour")
                    .font(NexoraTypography.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(recipe.category.color)
                    .textCase(.uppercase)
                
                Spacer()
                
                Image(systemName: recipe.category.icon)
                    .font(.title2)
                    .foregroundStyle(recipe.category.color)
            }
            
            // Recipe name and description
            VStack(alignment: .leading, spacing: NexoraSpacing.xs) {
                Text(recipe.name)
                    .font(NexoraTypography.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(NexoraColors.label)
                    .lineLimit(2)
                
                Text(recipe.description)
                    .font(NexoraTypography.body)
                    .foregroundStyle(NexoraColors.secondaryLabel)
                    .lineLimit(3)
            }
            
            // Metrics row
            HStack(spacing: NexoraSpacing.lg) {
                MetricBadge(icon: "timer", value: "\(recipe.prepTimeMinutes) min", label: "Prépa")
                MetricBadge(icon: "flame.fill", value: recipe.cookTimeMinutes.map { "\($0) min" } ?? "—", label: "Cuisson")
                MetricBadge(icon: "person.2.fill", value: "\(recipe.servings) pers", label: "Portions")
            }
            
            // Category badge
            HStack {
                Spacer()
                Text(recipe.category.rawValue)
                    .font(NexoraTypography.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(recipe.category.color)
                    .padding(.horizontal, NexoraSpacing.sm)
                    .padding(.vertical, 4)
                    .background(recipe.category.color.opacity(0.15))
                    .cornerRadius(NexoraRadius.full)
            }
        }
        .padding(NexoraSpacing.md)
        .background(NexoraColors.cardBackground)
        .cornerRadius(NexoraRadius.lg)
        .overlay(
            RoundedRectangle(cornerRadius: NexoraRadius.lg)
                .stroke(recipe.category.color.opacity(0.3), lineWidth: 1)
        )
    }
}

private struct MetricBadge: View {
    let icon: String
    let value: String
    let label: String
    
    var body: some View {
        VStack(spacing: 2) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
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
        .padding(.vertical, NexoraSpacing.xs)
        .background(NexoraColors.cardBackground)
        .cornerRadius(NexoraRadius.md)
    }
}
