import SwiftUI

struct ChillHomeView: View {
    @State private var mode: ChillBreathingMode = .coherence
    @State private var customInhale = 4
    @State private var customExhale = 6
    @State private var durationMinutes = 10
    @State private var usesCustomDuration = false
    @AppStorage("chillSoundGuidanceEnabled") private var soundGuidanceEnabled = true
    @AppStorage("chillSoundVolume") private var soundVolume = 0.25

    private let presetDurations = [5, 10, 15, 20]
    private let contentWidth: CGFloat = 560

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 30) {
                introduction
                rhythmSection
                durationSection
                soundGuidanceSection
                startButton
            }
            .frame(maxWidth: contentWidth, alignment: .leading)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 22)
            .padding(.vertical, 20)
        }
        .background(NexoraColors.groupedBackground.ignoresSafeArea())
        .navigationTitle("Chill")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NexoraSettingsToolbarButton()
            }
        }
    }

    private var introduction: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Respirez à votre rythme")
                .font(.system(.title2, design: .rounded, weight: .medium))
                .foregroundStyle(NexoraColors.label)
            Text("Choisissez un rythme, puis laissez le cercle vous guider.")
                .font(NexoraTypography.body)
                .foregroundStyle(NexoraColors.secondaryLabel)
        }
        .padding(.top, 4)
    }

    private var rhythmSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Rythme respiratoire")
            VStack(spacing: 0) {
                ForEach(ChillBreathingMode.allCases) { option in
                    Button {
                        mode = option
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: mode == option ? "largecircle.fill.circle" : "circle")
                                .font(.title3)
                                .foregroundStyle(mode == option ? Color.teal : NexoraColors.tertiaryLabel)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(option.title)
                                    .font(NexoraTypography.headline)
                                    .foregroundStyle(NexoraColors.label)
                                Text(patternSummary(for: option))
                                    .font(NexoraTypography.footnote)
                                    .foregroundStyle(NexoraColors.secondaryLabel)
                            }
                            Spacer(minLength: 8)
                            if mode == option {
                                Image(systemName: "checkmark")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(Color.teal)
                            }
                        }
                        .contentShape(Rectangle())
                        .padding(.vertical, 13)
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(mode == option ? .isSelected : [])
                    if option != .custom {
                        Divider().padding(.leading, 42)
                    }
                }
            }

            if mode == .custom {
                VStack(spacing: 2) {
                    secondsStepper(title: "Inspiration", value: $customInhale)
                    Divider().padding(.leading, 18)
                    secondsStepper(title: "Expiration", value: $customExhale)
                }
                .padding(.horizontal, 14)
                .background(NexoraColors.cardBackground, in: RoundedRectangle(cornerRadius: 16))
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: mode)
    }

    private var durationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Durée")
            ViewThatFits(in: .horizontal) {
                durationPresets
                durationPresetsCompact
            }
            if usesCustomDuration {
                HStack {
                    Text("Durée personnalisée")
                        .font(NexoraTypography.subheadline)
                    Spacer()
                    Text("\(durationMinutes) min")
                        .font(NexoraTypography.headline.monospacedDigit())
                        .foregroundStyle(Color.teal)
                    Stepper("Durée personnalisée, \(durationMinutes) minutes", value: $durationMinutes, in: 1...60)
                        .labelsHidden()
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(NexoraColors.cardBackground, in: RoundedRectangle(cornerRadius: 16))
            }
        }
    }

    private var durationPresets: some View {
        HStack(spacing: 8) {
            ForEach(presetDurations, id: \.self) { minutes in
                durationButton(minutes)
            }
            customDurationButton
        }
    }

    private var durationPresetsCompact: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                ForEach(presetDurations.prefix(3), id: \.self) { minutes in durationButton(minutes) }
            }
            HStack(spacing: 8) {
                durationButton(presetDurations[3])
                customDurationButton
            }
        }
    }

    private func durationButton(_ minutes: Int) -> some View {
        Button {
            durationMinutes = minutes
            usesCustomDuration = false
        } label: {
            Text("\(minutes) min")
                .font(NexoraTypography.subheadline.weight(.medium))
                .foregroundStyle(!usesCustomDuration && durationMinutes == minutes ? .white : NexoraColors.label)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(!usesCustomDuration && durationMinutes == minutes ? Color.teal : NexoraColors.cardBackground, in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(!usesCustomDuration && durationMinutes == minutes ? .isSelected : [])
    }

    private var customDurationButton: some View {
        Button {
            usesCustomDuration = true
        } label: {
            Text("Autre")
                .font(NexoraTypography.subheadline.weight(.medium))
                .foregroundStyle(usesCustomDuration ? .white : NexoraColors.label)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(usesCustomDuration ? Color.teal : NexoraColors.cardBackground, in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(usesCustomDuration ? "Durée personnalisée, \(durationMinutes) minutes" : "Choisir une durée personnalisée")
        .accessibilityAddTraits(usesCustomDuration ? .isSelected : [])
    }

    private var soundGuidanceSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "Guidage sonore")
            Toggle(isOn: $soundGuidanceEnabled) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Signaux respiratoires")
                        .font(NexoraTypography.headline)
                    Text("Un souffle sonore doux suit chaque cycle.")
                        .font(NexoraTypography.footnote)
                        .foregroundStyle(NexoraColors.secondaryLabel)
                }
            }
            .tint(.teal)
            .padding(.vertical, 5)

            if soundGuidanceEnabled {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Volume")
                            .font(NexoraTypography.subheadline)
                        Spacer()
                        Text("\(Int(soundVolume * 100)) %")
                            .font(NexoraTypography.caption.monospacedDigit())
                            .foregroundStyle(NexoraColors.secondaryLabel)
                    }
                    Slider(value: $soundVolume, in: 0.05...1, step: 0.01)
                        .tint(.teal)
                        .accessibilityLabel("Volume du guidage sonore")
                }
                .padding(.top, 2)
            }
        }
    }

    private var startButton: some View {
        NavigationLink {
            ChillSessionView(
                pattern: mode.pattern(customInhale: customInhale, customExhale: customExhale),
                durationMinutes: durationMinutes,
                soundGuidanceEnabled: soundGuidanceEnabled,
                soundVolume: soundVolume
            )
        } label: {
            Label("Commencer", systemImage: "wind")
                .font(NexoraTypography.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.teal.gradient, in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityHint("Démarre une séance de respiration de \(durationMinutes) minutes")
    }

    private func secondsStepper(title: String, value: Binding<Int>) -> some View {
        HStack {
            Text(title).font(NexoraTypography.subheadline)
            Spacer()
            Text("\(value.wrappedValue) s")
                .font(NexoraTypography.headline.monospacedDigit())
                .foregroundStyle(Color.teal)
            Stepper("\(title), \(value.wrappedValue) secondes", value: value, in: ChillBreathingPattern.customRange)
                .labelsHidden()
        }
        .padding(.vertical, 8)
    }

    private func patternSummary(for option: ChillBreathingMode) -> String {
        let pattern = option.pattern(customInhale: customInhale, customExhale: customExhale)
        return "Inspire \(pattern.inhaleSeconds) s · expire \(pattern.exhaleSeconds) s"
    }
}
