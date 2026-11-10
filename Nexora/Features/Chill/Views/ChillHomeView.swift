import SwiftUI

struct ChillHomeView: View {
    @State private var mode: ChillBreathingMode = .coherence
    @State private var customInhale = 4
    @State private var customExhale = 6
    @State private var durationMinutes = 10
    @State private var ambience: ChillAmbience = .rain
    @State private var volume = 0.22
    @State private var showingCredits = false

    private let presetDurations = [5, 10, 15, 20]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: NexoraSpacing.xl) {
                hero
                breathingChoices
                durationChoices
                ambienceChoices
                startButton
                Button {
                    showingCredits = true
                } label: {
                    Label("Sources et licences des sons", systemImage: "info.circle")
                        .font(NexoraTypography.footnote)
                        .foregroundStyle(NexoraColors.secondaryLabel)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, NexoraSpacing.md)
            .padding(.vertical, NexoraSpacing.lg)
        }
        .background(
            LinearGradient(
                colors: [Color(red: 0.91, green: 0.96, blue: 0.95), NexoraColors.groupedBackground],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        )
        .navigationTitle("Chill")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingCredits) {
            ChillAudioCreditsView()
        }
    }

    private var hero: some View {
        VStack(spacing: NexoraSpacing.md) {
            ZStack {
                Circle()
                    .fill(Color.teal.opacity(0.12))
                    .frame(width: 108, height: 108)
                Circle()
                    .stroke(Color.teal.opacity(0.25), lineWidth: 1)
                    .frame(width: 92, height: 92)
                Image(systemName: "wind")
                    .font(.system(size: 38, weight: .light))
                    .foregroundStyle(Color.teal)
            }
            .accessibilityHidden(true)

            Text("Prenez un instant pour vous")
                .font(NexoraTypography.title1)
                .foregroundStyle(NexoraColors.label)
                .multilineTextAlignment(.center)

            Text("Un souffle à la fois, à votre rythme.")
                .font(NexoraTypography.body)
                .foregroundStyle(NexoraColors.secondaryLabel)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, NexoraSpacing.sm)
    }

    private var breathingChoices: some View {
        VStack(alignment: .leading, spacing: NexoraSpacing.md) {
            SectionHeader(title: "Votre rythme")
            VStack(spacing: NexoraSpacing.sm) {
                ForEach(ChillBreathingMode.allCases) { option in
                    Button {
                        mode = option
                    } label: {
                        HStack(spacing: NexoraSpacing.md) {
                            Image(systemName: mode == option ? "largecircle.fill.circle" : "circle")
                                .font(.title3)
                                .foregroundStyle(mode == option ? Color.teal : NexoraColors.tertiaryLabel)
                            VStack(alignment: .leading, spacing: NexoraSpacing.xs) {
                                HStack {
                                    Text(option.title)
                                        .font(NexoraTypography.headline)
                                        .foregroundStyle(NexoraColors.label)
                                    Spacer()
                                    Text(patternSummary(for: option))
                                        .font(NexoraTypography.caption.weight(.semibold))
                                        .foregroundStyle(Color.teal)
                                }
                                Text(option.subtitle)
                                    .font(NexoraTypography.footnote)
                                    .foregroundStyle(NexoraColors.secondaryLabel)
                                    .multilineTextAlignment(.leading)
                            }
                        }
                        .padding(NexoraSpacing.md)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(NexoraColors.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: NexoraRadius.lg))
                        .overlay {
                            RoundedRectangle(cornerRadius: NexoraRadius.lg)
                                .stroke(mode == option ? Color.teal.opacity(0.55) : .clear, lineWidth: 1.5)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(mode == option ? .isSelected : [])
                }
            }

            if mode == .custom {
                VStack(spacing: NexoraSpacing.md) {
                    secondsStepper(title: "Inspiration", value: $customInhale)
                    secondsStepper(title: "Expiration", value: $customExhale)
                }
                .padding(NexoraSpacing.md)
                .cardStyle()
                .accessibilityElement(children: .contain)
            }
        }
    }

    private var durationChoices: some View {
        VStack(alignment: .leading, spacing: NexoraSpacing.md) {
            SectionHeader(title: "Durée")
            HStack(spacing: NexoraSpacing.sm) {
                ForEach(presetDurations, id: \.self) { minutes in
                    Button {
                        durationMinutes = minutes
                    } label: {
                        Text("\(minutes) min")
                            .font(NexoraTypography.subheadline.weight(.semibold))
                            .foregroundStyle(durationMinutes == minutes ? .white : NexoraColors.label)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, NexoraSpacing.sm)
                            .background(durationMinutes == minutes ? Color.teal : NexoraColors.cardBackground)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            HStack {
                Text("Personnaliser")
                    .font(NexoraTypography.subheadline)
                Spacer()
                Stepper("\(durationMinutes) minutes", value: $durationMinutes, in: 1...60)
                    .labelsHidden()
                    .accessibilityLabel("Durée personnalisée, \(durationMinutes) minutes")
                Text("\(durationMinutes) min")
                    .font(NexoraTypography.headline.monospacedDigit())
                    .frame(minWidth: 55, alignment: .trailing)
            }
            .padding(NexoraSpacing.md)
            .cardStyle()
            Text("De 1 à 60 minutes")
                .font(NexoraTypography.caption)
                .foregroundStyle(NexoraColors.secondaryLabel)
        }
    }

    private var ambienceChoices: some View {
        VStack(alignment: .leading, spacing: NexoraSpacing.md) {
            SectionHeader(title: "Ambiance sonore")
            Text("Choisissez un son pour accompagner la séance, ou gardez le silence.")
                .font(NexoraTypography.footnote)
                .foregroundStyle(NexoraColors.secondaryLabel)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: NexoraSpacing.sm) {
                    ForEach(ChillAmbience.allCases) { option in
                        Button {
                            ambience = option
                        } label: {
                            VStack(spacing: NexoraSpacing.sm) {
                                Image(systemName: option.symbol)
                                    .font(.title2.weight(.light))
                                    .frame(height: 28)
                                Text(option.title)
                                    .font(NexoraTypography.caption.weight(.medium))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                            }
                            .foregroundStyle(ambience == option ? Color.teal : NexoraColors.secondaryLabel)
                            .frame(width: 96, height: 82)
                            .background(NexoraColors.cardBackground)
                            .clipShape(RoundedRectangle(cornerRadius: NexoraRadius.md))
                            .overlay {
                                RoundedRectangle(cornerRadius: NexoraRadius.md)
                                    .stroke(ambience == option ? Color.teal.opacity(0.65) : NexoraColors.separator.opacity(0.25), lineWidth: ambience == option ? 1.5 : 0.5)
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(ambience == option ? .isSelected : [])
                    }
                }
                .padding(.vertical, 2)
            }
            if ambience != .none {
                VStack(alignment: .leading, spacing: NexoraSpacing.xs) {
                    HStack {
                        Label("Volume", systemImage: "speaker.wave.2")
                            .font(NexoraTypography.subheadline)
                        Spacer()
                        Text("\(Int(volume * 100)) %")
                            .font(NexoraTypography.caption.monospacedDigit())
                            .foregroundStyle(NexoraColors.secondaryLabel)
                    }
                    Slider(value: $volume, in: 0.05...0.75)
                        .tint(.teal)
                        .accessibilityLabel("Volume de l’ambiance")
                }
                .padding(NexoraSpacing.md)
                .cardStyle()
            }
        }
    }

    private var startButton: some View {
        NavigationLink {
            ChillSessionView(
                pattern: mode.pattern(customInhale: customInhale, customExhale: customExhale),
                durationMinutes: durationMinutes,
                ambience: ambience,
                volume: Float(volume)
            )
        } label: {
            Label("Commencer ma séance", systemImage: "wind")
                .font(NexoraTypography.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, NexoraSpacing.md)
                .background(Color.teal.gradient)
                .clipShape(RoundedRectangle(cornerRadius: NexoraRadius.lg))
        }
        .accessibilityHint("Démarre une séance de respiration de \(durationMinutes) minutes")
    }

    private func secondsStepper(title: String, value: Binding<Int>) -> some View {
        HStack {
            Text(title)
                .font(NexoraTypography.subheadline)
            Spacer()
            Stepper("\(value.wrappedValue) secondes", value: value, in: ChillBreathingPattern.customRange)
                .labelsHidden()
                .accessibilityLabel("\(title), \(value.wrappedValue) secondes")
            Text("\(value.wrappedValue) s")
                .font(NexoraTypography.headline.monospacedDigit())
                .frame(minWidth: 45, alignment: .trailing)
        }
    }

    private func patternSummary(for option: ChillBreathingMode) -> String {
        let pattern = option.pattern(customInhale: customInhale, customExhale: customExhale)
        return "\(pattern.inhaleSeconds) s / \(pattern.exhaleSeconds) s"
    }
}

private struct ChillAudioCreditsView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Enregistrements audio") {
                    credit(
                        name: "Pluie — Garden rainfall",
                        author: "Lionel Allorge · Lune Rouge",
                        source: "https://commons.wikimedia.org/wiki/File:Garden_rainfall.ogg",
                        license: "Licence Art Libre 1.3",
                        licenseURL: "https://artlibre.org/licence/lal/en/",
                        change: "AAC et boucle avec fondu de 2 secondes"
                    )
                    credit(
                        name: "Feu — Fire burning",
                        author: "Gpkp",
                        source: "https://commons.wikimedia.org/wiki/File:Fire_burning.webm",
                        license: "Creative Commons BY-SA 4.0",
                        licenseURL: "https://creativecommons.org/licenses/by-sa/4.0/",
                        change: "Extraction audio, AAC et boucle avec fondu de 2 secondes ; fichier diffusé sous la même licence"
                    )
                    credit(
                        name: "Vagues — Waves",
                        author: "Dsw4",
                        source: "https://commons.wikimedia.org/wiki/File:Waves.ogg",
                        license: "Domaine public",
                        licenseURL: "https://creativecommons.org/publicdomain/zero/1.0/",
                        change: "AAC et boucle avec fondu de 2 secondes"
                    )
                    credit(
                        name: "Forêt — Forest ambience",
                        author: "Gravity Sound",
                        source: "https://commons.wikimedia.org/wiki/File:Forest_ambience_(Gravity_Sound).wav",
                        license: "Creative Commons BY 4.0",
                        licenseURL: "https://creativecommons.org/licenses/by/4.0/",
                        change: "AAC et boucle avec fondu de 2 secondes"
                    )
                    credit(
                        name: "Nuit — Oecanthus pellucens song 23C",
                        author: "Gunther Tschuch (enregistrement à 21 h)",
                        source: "https://commons.wikimedia.org/wiki/File:Oecanthus_pellucens_song_23C.wav",
                        license: "Creative Commons BY-SA 4.0",
                        licenseURL: "https://creativecommons.org/licenses/by-sa/4.0/",
                        change: "AAC et boucle avec fondu de 2 secondes ; fichier diffusé sous la même licence"
                    )
                }
                Section {
                    Text("Les fichiers audio sont intégrés à l’application : aucune connexion réseau n’est nécessaire. Les ambiances sont jouées à faible volume et répétées en boucle. Le lecteur les diffuse pendant l’écran verrouillé lorsque l’ambiance est activée.")
                        .font(NexoraTypography.footnote)
                        .foregroundStyle(NexoraColors.secondaryLabel)
                }
            }
            .navigationTitle("Sources audio")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fermer") { dismiss() }
                }
            }
        }
    }

    private func credit(name: String, author: String, source: String, license: String, licenseURL: String, change: String) -> some View {
        VStack(alignment: .leading, spacing: NexoraSpacing.xs) {
            Text(name).font(NexoraTypography.headline)
            Text("Auteur : \(author)")
                .font(NexoraTypography.footnote)
                .foregroundStyle(NexoraColors.secondaryLabel)
            Text("Modifications : \(change)")
                .font(NexoraTypography.caption)
                .foregroundStyle(NexoraColors.secondaryLabel)
            HStack {
                Link("Source", destination: URL(string: source)!)
                Text("·")
                Link(license, destination: URL(string: licenseURL)!)
            }
            .font(NexoraTypography.caption)
        }
        .padding(.vertical, NexoraSpacing.xs)
    }
}
