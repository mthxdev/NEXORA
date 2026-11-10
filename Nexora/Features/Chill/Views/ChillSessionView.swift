import SwiftUI

struct ChillSessionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var controller: ChillSessionController
    @State private var showingStopConfirmation = false
    @State private var showingAudioError = false

    init(pattern: ChillBreathingPattern, durationMinutes: Int, ambience: ChillAmbience, volume: Float) {
        _controller = StateObject(wrappedValue: ChillSessionController(
            pattern: pattern,
            durationMinutes: durationMinutes,
            ambience: ambience,
            volume: volume
        ))
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                LinearGradient(
                    colors: [Color(red: 0.08, green: 0.18, blue: 0.23), Color(red: 0.12, green: 0.27, blue: 0.30), Color(red: 0.17, green: 0.31, blue: 0.31)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                VStack(spacing: NexoraSpacing.lg) {
                    topBar
                    Spacer(minLength: 0)
                    if controller.timeline.status == .completed || controller.timeline.status == .stopped {
                        completionState
                    } else {
                        breathingCircle(size: min(geometry.size.width * 0.68, 270))
                        phaseText
                        sessionTime
                    }
                    Spacer(minLength: 0)
                    if let pauseMessage = controller.pauseMessage {
                        Text(pauseMessage)
                            .font(NexoraTypography.footnote)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.white.opacity(0.78))
                            .padding(.horizontal, NexoraSpacing.lg)
                            .accessibilityAddTraits(.updatesFrequently)
                    }
                    controls
                }
                .padding(.horizontal, NexoraSpacing.md)
                .padding(.top, NexoraSpacing.md)
                .padding(.bottom, NexoraSpacing.lg)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .preferredColorScheme(.dark)
        .onAppear(perform: controller.startIfNeeded)
        .onChange(of: scenePhase) { _, phase in controller.sceneDidChange(phase) }
        .onChange(of: controller.audioError) { _, value in showingAudioError = value != nil }
        .task {
            while !Task.isCancelled && !controller.isFinished {
                controller.refresh()
                let tick: Duration = scenePhase == .active ? .milliseconds(125) : .seconds(1)
                do { try await Task.sleep(for: tick) }
                catch { break }
            }
        }
        .onDisappear {
            if !controller.isFinished { controller.stop() }
        }
        .alert("Ambiance indisponible", isPresented: $showingAudioError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(controller.audioError ?? "Une erreur audio est survenue.")
        }
        .confirmationDialog("Arrêter cette séance ?", isPresented: $showingStopConfirmation, titleVisibility: .visible) {
            Button("Arrêter la séance", role: .destructive) { controller.stop() }
            Button("Continuer", role: .cancel) { }
        }
    }

    private var topBar: some View {
        HStack {
            Button {
                showingStopConfirmation = true
            } label: {
                Image(systemName: "xmark")
                    .font(.headline)
                    .foregroundStyle(.white.opacity(0.9))
                    .frame(width: 44, height: 44)
                    .background(.white.opacity(0.1), in: Circle())
            }
            .accessibilityLabel("Arrêter et quitter la séance")
            Spacer()
            Label(controller.ambience.title, systemImage: controller.ambience.symbol)
                .font(NexoraTypography.caption)
                .foregroundStyle(.white.opacity(0.78))
                .lineLimit(1)
        }
    }

    private func breathingCircle(size: CGFloat) -> some View {
        let timeline = controller.timeline
        let scale: CGFloat = {
            switch timeline.phase {
            case .inhale: return 0.80 + 0.20 * timeline.phaseProgress
            case .exhale: return 1.00 - 0.20 * timeline.phaseProgress
            }
        }()
        return ZStack {
            Circle()
                .stroke(.white.opacity(0.14), lineWidth: 1)
                .frame(width: size, height: size)
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color(red: 0.72, green: 0.91, blue: 0.83).opacity(0.94), Color(red: 0.34, green: 0.66, blue: 0.60).opacity(0.82)],
                        center: .center,
                        startRadius: 8,
                        endRadius: size / 2
                    )
                )
                .overlay {
                    Circle().stroke(.white.opacity(0.4), lineWidth: 1)
                }
                .frame(width: size * 0.72, height: size * 0.72)
                .shadow(color: Color.teal.opacity(0.32), radius: 34)
                .scaleEffect(scale)
                .animation(.linear(duration: 0.18), value: timeline.phaseProgress)
                .animation(.easeInOut(duration: 0.2), value: timeline.phase)
            VStack(spacing: NexoraSpacing.xs) {
                Text("\(timeline.phaseRemainingSeconds)")
                    .font(.system(size: 42, weight: .light, design: .rounded).monospacedDigit())
                    .contentTransition(.numericText())
                Text("SECONDES")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .tracking(2)
            }
            .foregroundStyle(Color(red: 0.09, green: 0.22, blue: 0.22))
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(timeline.phaseRemainingSeconds) secondes dans cette phase")
        }
        .frame(width: size, height: size)
        .accessibilityElement(children: .contain)
    }

    private var phaseText: some View {
        VStack(spacing: NexoraSpacing.xs) {
            Text(controller.timeline.phase == .inhale ? "Inspire" : "Expire")
                .font(.system(size: 34, weight: .light, design: .rounded))
                .foregroundStyle(.white)
                .contentTransition(.opacity)
                .accessibilityAddTraits(.updatesFrequently)
            Text("\(controller.timeline.pattern.inhaleSeconds) s d’inspiration · \(controller.timeline.pattern.exhaleSeconds) s d’expiration")
                .font(NexoraTypography.footnote)
                .foregroundStyle(.white.opacity(0.68))
        }
    }

    private var sessionTime: some View {
        VStack(spacing: NexoraSpacing.xs) {
            Text(formatTime(controller.timeline.remainingSeconds))
                .font(.system(size: 25, weight: .light, design: .rounded).monospacedDigit())
                .foregroundStyle(.white)
            Text("TEMPS RESTANT")
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .tracking(1.8)
                .foregroundStyle(.white.opacity(0.58))
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Temps restant : \(formatTime(controller.timeline.remainingSeconds))")
    }

    private var completionState: some View {
        VStack(spacing: NexoraSpacing.lg) {
            Image(systemName: controller.timeline.status == .completed ? "checkmark.circle" : "pause.circle")
                .font(.system(size: 64, weight: .ultraLight))
                .foregroundStyle(Color(red: 0.72, green: 0.91, blue: 0.83))
            Text(controller.timeline.status == .completed ? "Séance terminée" : "Séance arrêtée")
                .font(NexoraTypography.title1)
                .foregroundStyle(.white)
            Text(controller.timeline.status == .completed ? "Merci de vous être accordé ce moment." : "Vous pourrez reprendre une séance quand vous le souhaitez.")
                .font(NexoraTypography.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.7))
            Button("Terminer") { dismiss() }
                .font(NexoraTypography.headline)
                .foregroundStyle(Color(red: 0.09, green: 0.22, blue: 0.22))
                .padding(.horizontal, NexoraSpacing.xl)
                .padding(.vertical, NexoraSpacing.md)
                .background(Color(red: 0.72, green: 0.91, blue: 0.83), in: Capsule())
        }
        .padding(.horizontal, NexoraSpacing.lg)
    }

    private var controls: some View {
        Group {
            if controller.timeline.status == .running {
                HStack(spacing: NexoraSpacing.md) {
                    Button {
                        controller.pause()
                    } label: {
                        Label("Pause", systemImage: "pause.fill")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, NexoraSpacing.md)
                            .background(.white.opacity(0.13), in: Capsule())
                    }
                    Button {
                        showingStopConfirmation = true
                    } label: {
                        Label("Arrêter", systemImage: "stop.fill")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, NexoraSpacing.md)
                            .background(.white.opacity(0.13), in: Capsule())
                    }
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white)
            } else if controller.timeline.status == .paused {
                Button {
                    controller.resume()
                } label: {
                    Label("Reprendre", systemImage: "play.fill")
                        .font(NexoraTypography.headline)
                        .foregroundStyle(Color(red: 0.09, green: 0.22, blue: 0.22))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, NexoraSpacing.md)
                        .background(Color(red: 0.72, green: 0.91, blue: 0.83), in: Capsule())
                }
            } else {
                Color.clear.frame(height: 52)
            }
        }
        .frame(maxWidth: 420)
    }

    private func formatTime(_ seconds: Int) -> String {
        String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }
}
