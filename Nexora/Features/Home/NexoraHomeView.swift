import SwiftUI
import SwiftData

struct NexoraHomeView: View {
    @AppStorage("appLogo") private var appLogo: AppLogo = .classic
    @Query(sort: \CompletedWorkout.date, order: .reverse) private var completedWorkouts: [CompletedWorkout]
    @Query(sort: \Program.createdAt) private var programs: [Program]
    
    var body: some View {
        NavigationStack {
            GeometryReader { viewport in
                ScrollView {
                    VStack(spacing: 0) {
                        headerSection

                        if let lastWorkout = completedWorkouts.first(where: { $0.finishedAt != nil }) {
                            Spacer(minLength: NexoraSpacing.sm)
                            lastWorkoutCard(lastWorkout)
                        }

                        if !programs.isEmpty {
                            Spacer(minLength: NexoraSpacing.sm)
                            programsSection
                        }

                        Spacer(minLength: NexoraSpacing.sm)
                        modulesSection
                    }
                    .padding(.horizontal, NexoraSpacing.md)
                    .padding(.top, NexoraSpacing.xs)
                    .padding(.bottom, NexoraSpacing.sm)
                    .frame(minHeight: viewport.size.height, alignment: .top)
                }
                .background(NexoraColors.groupedBackground)
            }
            .navigationTitle("Nexora")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NexoraSettingsToolbarButton()
                }
            }
        }
    }
    
    private var headerSection: some View {
        HStack(spacing: NexoraSpacing.md) {
            Image(appLogo.assetName)
                .resizable()
                .scaledToFit()
                .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: NexoraSpacing.xs) {
                Text("Bienvenue")
                    .font(NexoraTypography.title3)

                Text("Votre espace personnel unifié pour le sport, la culture et l'organisation.")
                    .font(NexoraTypography.subheadline)
                    .foregroundStyle(NexoraColors.secondaryLabel)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, NexoraSpacing.sm)
    }
    
    private func lastWorkoutCard(_ workout: CompletedWorkout) -> some View {
        VStack(alignment: .leading, spacing: NexoraSpacing.sm) {
            HStack {
                Label("Dernière séance", systemImage: "clock.arrow.circlepath")
                    .font(NexoraTypography.headline)
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: NexoraSpacing.xs) {
                Text(workout.workoutName)
                    .font(NexoraTypography.title3)
                Text("\(workout.programName) · \(workout.date.formatted(date: .abbreviated, time: .omitted))")
                    .font(NexoraTypography.subheadline)
                    .foregroundStyle(NexoraColors.secondaryLabel)
            }
            
            HStack {
                Image(systemName: "dumbbell.fill")
                    .font(.caption)
                Text("\(workout.exercises.count) exercice\(workout.exercises.count > 1 ? "s" : "")")
                    .font(NexoraTypography.caption)
                if let finishedAt = workout.finishedAt {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption)
                    Text(formatDuration(from: workout.startedAt, to: finishedAt))
                        .font(NexoraTypography.caption)
                }
            }
            .foregroundStyle(NexoraColors.tertiaryLabel)
        }
        .cardStyle(padding: NexoraSpacing.sm)
    }
    
    private var programsSection: some View {
        VStack(alignment: .leading, spacing: NexoraSpacing.sm) {
            Text("Vos programmes")
                .font(NexoraTypography.headline)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: NexoraSpacing.md) {
                    ForEach(programs.prefix(5)) { program in
                        NavigationLink(destination: ProgramDetailView(program: program)) {
                            ProgramCard(program: program)
                        }
                        .buttonStyle(.plain)
                    }
                    
                    NavigationLink(destination: ProgramFormView()) {
                        AddProgramCard()
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
    
    private var modulesSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Modules")
                .font(NexoraTypography.headline)

            Spacer(minLength: NexoraSpacing.sm)

            VStack(spacing: 0) {
                NavigationLink(destination: MuscuLogTabView()) {
                    ModuleCard(
                        icon: "dumbbell.fill",
                        title: "MuscuLog",
                        subtitle: "Suivi musculation & progression",
                        color: .blue,
                        stats: muscuLogStats
                    )
                }
                .accessibilityLabel("Ouvrir MuscuLog — \(muscuLogStats)")
                .buttonStyle(.plain)

                Spacer(minLength: NexoraSpacing.sm)

                 NavigationLink(destination: LogBookView()) {
                    ModuleCard(
                        icon: "book.fill",
                        title: "LogBook",
                        subtitle: "Films, séries, jeux, projets…",
                        color: .purple,
                        stats: "Bientôt disponible"
                    )
                }
                .accessibilityLabel("Ouvrir LogBook")
                .buttonStyle(.plain)

                Spacer(minLength: NexoraSpacing.sm)

                NavigationLink(destination: MealTabView()) {
                    ModuleCard(
                        icon: "carrot.fill",
                        title: "Repas",
                        subtitle: "Recettes, planification & favoris",
                        color: .orange,
                        stats: "\(SampleRecipes.all.count) recettes"
                    )
                }
                .accessibilityLabel("Ouvrir Repas — \(SampleRecipes.all.count) recettes")
                .buttonStyle(.plain)
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }
    
    private var muscuLogStats: String {
        let finishedCount = completedWorkouts.filter { $0.finishedAt != nil }.count
        if finishedCount == 0 {
            return "Aucune séance terminée"
        }
        return "\(finishedCount) séance\(finishedCount > 1 ? "s" : "") terminée\(finishedCount > 1 ? "s" : "")"
    }
    
    private func formatDuration(from start: Date, to end: Date) -> String {
        let diff = Int(end.timeIntervalSince(start))
        let hours = diff / 3600
        let minutes = (diff % 3600) / 60
        if hours > 0 {
            return "\(hours)h\(minutes > 0 ? " \(minutes)min" : "")"
        }
        return "\(minutes) min"
    }
}

struct ProgramCard: View {
    let program: Program
    
    var body: some View {
        VStack(alignment: .leading, spacing: NexoraSpacing.sm) {
            Text(program.name)
                .font(NexoraTypography.headline)
                .foregroundStyle(NexoraColors.label)
                .lineLimit(1)
            
            Text("\(program.workouts.count) séance\(program.workouts.count > 1 ? "s" : "")")
                .font(NexoraTypography.caption)
                .foregroundStyle(NexoraColors.secondaryLabel)
        }
        .frame(width: 160)
        .padding(NexoraSpacing.md)
        .background(NexoraColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: NexoraRadius.md))
        .overlay(
            RoundedRectangle(cornerRadius: NexoraRadius.md)
                .stroke(NexoraColors.separator, lineWidth: 0.5)
        )
        .accessibilityLabel("\(program.name), \(program.workouts.count) séance\(program.workouts.count > 1 ? "s" : "")")
    }
}

struct AddProgramCard: View {
    var body: some View {
        VStack(spacing: NexoraSpacing.sm) {
            Image(systemName: "plus.circle.fill")
                .font(.system(size: 32, weight: .light))
                .foregroundStyle(Color.accentColor)
            
            Text("Nouveau")
                .font(NexoraTypography.subheadline.weight(.medium))
                .foregroundStyle(Color.accentColor)
        }
        .frame(width: 160)
        .padding(NexoraSpacing.md)
        .background(NexoraColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: NexoraRadius.md))
        .overlay(
            RoundedRectangle(cornerRadius: NexoraRadius.md)
                .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [8, 4]))
                .foregroundStyle(Color.accentColor)
        )
        .accessibilityLabel("Nouveau programme")
    }
}

struct ModuleCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    let stats: String
    
    var body: some View {
        HStack(spacing: NexoraSpacing.md) {
            ZStack {
                RoundedRectangle(cornerRadius: NexoraRadius.md)
                    .fill(color.opacity(0.15))
                    .frame(width: 48, height: 48)
                
                Image(systemName: icon)
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(color)
            }
            
            VStack(alignment: .leading, spacing: NexoraSpacing.xs) {
                Text(title)
                    .font(NexoraTypography.headline)
                    .foregroundStyle(NexoraColors.label)
                Text(subtitle)
                    .font(NexoraTypography.subheadline)
                    .foregroundStyle(NexoraColors.secondaryLabel)
                Text(stats)
                    .font(NexoraTypography.caption)
                    .foregroundStyle(NexoraColors.tertiaryLabel)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(NexoraColors.tertiaryLabel)
        }
        .padding(NexoraSpacing.sm)
        .background(NexoraColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: NexoraRadius.md))
    }
}

#Preview {
    NexoraHomeView()
        .modelContainer(for: [Program.self, CompletedWorkout.self, FavoriteRecipe.self], inMemory: true)
}
