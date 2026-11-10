import SwiftUI

struct ChillSessionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var controller: ChillSessionController
    @State private var showingAudioError = false

    init(pattern: ChillBreathingPattern, durationMinutes: Int, soundGuidanceEnabled: Bool, soundVolume: Double) {
        _controller = StateObject(wrappedValue: ChillSessionController(
            pattern: pattern,
            durationMinutes: durationMinutes,
            soundGuidanceEnabled: soundGuidanceEnabled,
            soundVolume: soundVolume
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

                if controller.audioError != nil && controller.timeline.status == .ready {
                    audioFailureState
                } else if controller.isFinished {
                    completionState
                } else {
                    activeSession(size: breathingDiameter(in: geometry.size))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .toolbar(.hidden, for: .navigationBar)
        .preferredColorScheme(.dark)
        .onChange(of: scenePhase) { _, phase in controller.sceneDidChange(phase) }
        .onChange(of: controller.audioError) { _, value in showingAudioError = value != nil }
        .task {
            controller.startIfNeeded()
            while !Task.isCancelled && !controller.isFinished {
                controller.refresh()
                do { try await Task.sleep(for: .seconds(1)) }
                catch { break }
            }
        }
        .onDisappear {
            if !controller.isFinished { controller.stop() }
        }
        .alert("Guidage sonore indisponible", isPresented: $showingAudioError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(controller.audioError ?? "Une erreur audio est survenue.")
        }
    }

    private func activeSession(size: CGFloat) -> some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: !controller.isRunning)) { _ in
            let timeline = controller.currentTimeline
            VStack(spacing: 0) {
                HStack {
                    Text("CHILL")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .tracking(2.2)
                        .foregroundStyle(.white.opacity(0.58))
                    Spacer()
                    Text("\(timeline.pattern.inhaleSeconds) / \(timeline.pattern.exhaleSeconds) s")
                        .font(.system(.footnote, design: .rounded, weight: .medium).monospacedDigit())
                        .foregroundStyle(.white.opacity(0.68))
                        .accessibilityLabel("Inspiration \(timeline.pattern.inhaleSeconds) secondes, expiration \(timeline.pattern.exhaleSeconds) secondes")
                }
                .frame(maxWidth: 500)
                .padding(.horizontal, 24)
                .padding(.top, 10)

                Spacer(minLength: 8)
                breathingCircle(size: size, timeline: timeline)
                Text(timeline.phase == .inhale ? "Inspiration" : "Expiration")
                    .font(.system(.title2, design: .rounded, weight: .light))
                    .foregroundStyle(.white)
                    .padding(.top, 14)
                    .accessibilityAddTraits(.updatesFrequently)
                sessionTime(timeline)
                    .padding(.top, 18)
                Spacer(minLength: 12)

                if let message = controller.pauseMessage {
                    Text(message)
                        .font(NexoraTypography.footnote)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white.opacity(0.78))
                        .frame(maxWidth: 420)
                        .padding(.horizontal, 24)
                        .padding(.bottom, 12)
                }

                controls
                    .frame(maxWidth: 420)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 18)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func breathingCircle(size: CGFloat, timeline: ChillSessionTimeline) -> some View {
        let diameter = CGFloat(ChillBreathingVisualMetrics.diameter(
            maximum: Double(size),
            phase: timeline.phase,
            progress: timeline.phaseProgress
        ))
        return ZStack {
            Circle()
                .stroke(.white.opacity(0.16), lineWidth: 1)
                .frame(width: size, height: size)
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color(red: 0.82, green: 0.95, blue: 0.88), Color(red: 0.38, green: 0.72, blue: 0.65)],
                        center: .center,
                        startRadius: 5,
                        endRadius: diameter / 2
                    )
                )
                .overlay(Circle().stroke(.white.opacity(0.46), lineWidth: 1))
                .frame(width: diameter, height: diameter)
                .shadow(color: Color.teal.opacity(0.22), radius: 24)
            if diameter > 0 {
                Image(systemName: "wind")
                    .font(.system(size: max(8, min(44, diameter * 0.10)), weight: .ultraLight))
                    .foregroundStyle(Color(red: 0.10, green: 0.27, blue: 0.26).opacity(0.72))
            }
        }
        .frame(width: size, height: size)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(timeline.phase == .inhale ? "Cercle en expansion, inspiration" : "Cercle en contraction, expiration")
    }

    private func sessionTime(_ timeline: ChillSessionTimeline) -> some View {
        VStack(spacing: 4) {
            Text(formatTime(timeline.remainingSeconds))
                .font(.system(size: 25, weight: .light, design: .rounded).monospacedDigit())
                .foregroundStyle(.white)
            Text("TEMPS RESTANT")
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .tracking(1.8)
                .foregroundStyle(.white.opacity(0.58))
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Temps restant : \(formatTime(timeline.remainingSeconds))")
    }

    private var controls: some View {
        HStack(spacing: 12) {
            if controller.isRunning {
                Button(action: controller.pause) {
                    Label("Pause", systemImage: "pause.fill")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(.white.opacity(0.13), in: Capsule())
                }
                Button(action: controller.stop) {
                    Label("Arrêter", systemImage: "stop.fill")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(.white.opacity(0.13), in: Capsule())
                }
            } else {
                Button(action: controller.resume) {
                    Label("Reprendre", systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(Color(red: 0.82, green: 0.95, blue: 0.88), in: Capsule())
                        .foregroundStyle(Color(red: 0.10, green: 0.27, blue: 0.26))
                }
                Button(action: controller.stop) {
                    Label("Arrêter", systemImage: "stop.fill")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(.white.opacity(0.13), in: Capsule())
                        .foregroundStyle(.white)
                }
            }
        }
        .font(NexoraTypography.headline)
        .buttonStyle(.plain)
        .foregroundStyle(.white)
    }

    private var completionState: some View {
        VStack(spacing: 18) {
            Image(systemName: controller.timeline.status == .completed ? "checkmark.circle" : "stop.circle")
                .font(.system(size: 58, weight: .ultraLight))
                .foregroundStyle(Color(red: 0.82, green: 0.95, blue: 0.88))
            Text(controller.timeline.status == .completed ? "Séance terminée" : "Séance arrêtée")
                .font(NexoraTypography.title1)
                .foregroundStyle(.white)
            Text("Durée effectuée · \(formatTime(Int(controller.timeline.elapsedSeconds.rounded(.down))))")
                .font(NexoraTypography.body)
                .foregroundStyle(.white.opacity(0.74))
            Button("Retour à Chill") { dismiss() }
                .font(NexoraTypography.headline)
                .foregroundStyle(Color(red: 0.10, green: 0.27, blue: 0.26))
                .padding(.horizontal, 26)
                .padding(.vertical, 14)
                .background(Color(red: 0.82, green: 0.95, blue: 0.88), in: Capsule())
                .padding(.top, 8)
        }
        .padding(28)
        .frame(maxWidth: 460)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var audioFailureState: some View {
        VStack(spacing: 18) {
            Image(systemName: "speaker.slash")
                .font(.system(size: 48, weight: .ultraLight))
                .foregroundStyle(.white.opacity(0.8))
            Text("Séance non démarrée")
                .font(NexoraTypography.title2)
                .foregroundStyle(.white)
            Text("Le moteur de signaux sonores n’a pas pu démarrer.")
                .font(NexoraTypography.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.72))
            Button("Retour à Chill") { dismiss() }
                .font(NexoraTypography.headline)
                .foregroundStyle(Color(red: 0.10, green: 0.27, blue: 0.26))
                .padding(.horizontal, 26)
                .padding(.vertical, 14)
                .background(Color(red: 0.82, green: 0.95, blue: 0.88), in: Capsule())
        }
        .padding(28)
        .frame(maxWidth: 460)
    }

    private func breathingDiameter(in size: CGSize) -> CGFloat {
        CGFloat(ChillBreathingVisualMetrics.maximumDiameter(
            availableWidth: Double(size.width),
            availableHeight: Double(size.height)
        ))
    }

    private func formatTime(_ seconds: Int) -> String {
        String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }
}
