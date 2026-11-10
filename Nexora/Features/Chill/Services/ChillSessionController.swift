import Foundation
import SwiftUI

@MainActor
final class ChillSessionController: ObservableObject {
    @Published private(set) var timeline: ChillSessionTimeline
    @Published private(set) var audioError: String?
    @Published private(set) var pauseMessage: String?

    let ambience: ChillAmbience
    private let audioService: ChillAudioService
    private let initialVolume: Float
    private let clock: ContinuousClock
    private let origin: ContinuousClock.Instant
    private var hasStarted = false

    init(
        pattern: ChillBreathingPattern,
        durationMinutes: Int,
        ambience: ChillAmbience,
        volume: Float,
        audioService: ChillAudioService = ChillAudioService()
    ) {
        let clock = ContinuousClock()
        self.clock = clock
        self.origin = clock.now
        self.ambience = ambience
        self.audioService = audioService
        self.initialVolume = min(max(volume, 0.05), 0.75)
        self.timeline = ChillSessionTimeline(
            pattern: pattern,
            durationSeconds: TimeInterval(min(max(durationMinutes, 1), 60) * 60)
        )
        audioService.onInterruption = { [weak self] in
            self?.pauseForSystemEvent("La séance est en pause après une interruption audio.")
        }
        audioService.onHeadphonesDisconnected = { [weak self] in
            self?.pauseForSystemEvent("La sortie audio a été déconnectée. La séance est en pause.")
        }
        audioService.onMediaServicesReset = { [weak self] in
            self?.pauseForSystemEvent("Le service audio a été réinitialisé. Relancez la séance audio manuellement.")
        }
    }

    var isRunning: Bool { timeline.status == .running }
    var isPaused: Bool { timeline.status == .paused }
    var isFinished: Bool { timeline.status == .completed || timeline.status == .stopped }

    func startIfNeeded() {
        guard !hasStarted else { return }
        do {
            try audioService.start(ambience: ambience, volume: initialVolume)
            var next = timeline
            next.start(at: monotonicSeconds)
            timeline = next
            hasStarted = true
        } catch {
            audioService.stopImmediately()
            audioError = "L’ambiance sonore n’a pas pu démarrer : \(error.localizedDescription)"
        }
    }

    func refresh() {
        guard timeline.status == .running else { return }
        var next = timeline
        next.refresh(at: monotonicSeconds)
        timeline = next
        if next.status == .completed {
            audioService.stop()
        }
    }

    func pause() {
        guard timeline.status == .running else { return }
        var next = timeline
        next.pause(at: monotonicSeconds)
        timeline = next
        if next.status == .completed {
            audioService.stop()
        } else {
            audioService.pause()
        }
        pauseMessage = nil
    }

    func resume() {
        guard timeline.status == .paused else { return }
        do {
            try audioService.resume()
            var next = timeline
            next.resume(at: monotonicSeconds)
            timeline = next
            pauseMessage = nil
        } catch {
            audioError = "La lecture audio n’a pas pu reprendre : \(error.localizedDescription)"
        }
    }

    func stop() {
        var next = timeline
        next.stop()
        timeline = next
        audioService.stop()
    }

    func sceneDidChange(_ phase: ScenePhase) {
        if phase == .background {
            if ambience == .none, timeline.status == .running {
                pauseForSystemEvent("Sans ambiance sonore, la séance se met en pause en arrière-plan.")
            }
        } else if phase == .active {
            refresh()
        }
    }

    private func pauseForSystemEvent(_ message: String) {
        guard timeline.status == .running else { return }
        var next = timeline
        next.pause(at: monotonicSeconds)
        timeline = next
        if next.status == .completed {
            audioService.stop()
        } else {
            audioService.pause()
        }
        pauseMessage = message
    }

    private var monotonicSeconds: TimeInterval {
        let components = origin.duration(to: clock.now).components
        return TimeInterval(components.seconds) + TimeInterval(components.attoseconds) / 1_000_000_000_000_000_000
    }
}
