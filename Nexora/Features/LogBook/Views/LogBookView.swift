import SwiftUI

struct LogBookView: View {
    private let categories = [
        LogBookCategory(icon: "film.fill", title: "Films", color: .red, description: "Suivi des films vus et à voir"),
        LogBookCategory(icon: "tv.fill", title: "Séries", color: .blue, description: "Épisodes, saisons, progression"),
        LogBookCategory(icon: "sparkles.tv.fill", title: "Animés", color: .pink, description: "Anime, manga, planning"),
        LogBookCategory(icon: "gamecontroller.fill", title: "Jeux vidéo", color: .green, description: "Backlog, temps de jeu, notes"),
        LogBookCategory(icon: "folder.fill.badge.gearshape", title: "Projets", color: .orange, description: "Projets perso, avancement, tâches"),
        LogBookCategory(icon: "book.fill", title: "Apprentissages", color: .purple, description: "Cours, compétences, certificats")
    ]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: NexoraSpacing.lg) {
                    headerSection
                    
                    categoriesSection
                    
                    comingSoonSection
                    
                    Spacer(minLength: NexoraSpacing.xxl)
                }
                .padding(.horizontal, NexoraSpacing.md)
                .padding(.top, NexoraSpacing.sm)
            }
            .background(NexoraColors.groupedBackground)
            .navigationTitle("LogBook")
            .navigationBarTitleDisplayMode(.large)
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: NexoraSpacing.sm) {
            Image(systemName: "book.closed.fill")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(.purple)
            
            Text("LogBook")
                .font(NexoraTypography.title1)
            
            Text("Votre carnet de bord culturel et personnel.\nSuivez films, séries, jeux, projets et apprentissages.")
                .font(NexoraTypography.body)
                .foregroundStyle(NexoraColors.secondaryLabel)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, NexoraSpacing.md)
    }
    
    private var categoriesSection: some View {
        VStack(alignment: .leading, spacing: NexoraSpacing.md) {
            Text("Catégories prévues")
                .font(NexoraTypography.headline)
            
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: NexoraSpacing.md),
                GridItem(.flexible(), spacing: NexoraSpacing.md)
            ], spacing: NexoraSpacing.md) {
                ForEach(categories) { category in
                    CategoryCard(category: category)
                }
            }
        }
    }
    
    private var comingSoonSection: some View {
        VStack(spacing: NexoraSpacing.md) {
            Divider()
                .padding(.horizontal, -NexoraSpacing.md)
            
            VStack(spacing: NexoraSpacing.sm) {
                Image(systemName: "hammer.fill")
                    .font(.system(size: 32, weight: .light))
                    .foregroundStyle(NexoraColors.tertiaryLabel)
                
                Text("Module en développement")
                    .font(NexoraTypography.title3)
                    .foregroundStyle(NexoraColors.label)
                
                Text("LogBook sera développé dans une phase ultérieure.\nLes catégories ci-dessus définissent le périmètre prévu.")
                    .font(NexoraTypography.subheadline)
                    .foregroundStyle(NexoraColors.secondaryLabel)
                    .multilineTextAlignment(.center)
            }
            .padding(NexoraSpacing.lg)
            .background(NexoraColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: NexoraRadius.md))
        }
    }
}

struct LogBookCategory: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let color: Color
    let description: String
}

struct CategoryCard: View {
    let category: LogBookCategory
    
    var body: some View {
        VStack(alignment: .leading, spacing: NexoraSpacing.sm) {
            ZStack {
                RoundedRectangle(cornerRadius: NexoraRadius.md)
                    .fill(category.color.opacity(0.15))
                    .frame(height: 56)
                
                Image(systemName: category.icon)
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(category.color)
            }
            
            VStack(alignment: .leading, spacing: NexoraSpacing.xs) {
                Text(category.title)
                    .font(NexoraTypography.headline)
                    .foregroundStyle(NexoraColors.label)
                Text(category.description)
                    .font(NexoraTypography.caption)
                    .foregroundStyle(NexoraColors.secondaryLabel)
                    .lineLimit(2)
            }
        }
        .padding(NexoraSpacing.md)
        .background(NexoraColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: NexoraRadius.md))
        .overlay(
            RoundedRectangle(cornerRadius: NexoraRadius.md)
                .stroke(NexoraColors.separator, lineWidth: 0.5)
        )
    }
}

#Preview {
    LogBookView()
}