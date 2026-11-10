import Foundation
import SwiftUI

@MainActor
final class ChillSessionController: ObservableObject {
    @Published private(set) var timeline: ChillSessionTimeline
    @Published private(set) var audioError: String?
    @Published private(set) var pauseMessage: String?

    let soundGuidanceEnabled: Bool
    private let audioService: (any ChillCuePlaying)?
    private let clock: ContinuousClock
    private let origin: ContinuousClock.Instant
    private var hasStarted = false

    init(
        pattern: ChillBreathingPattern,
        durationMinutes: Int,
        soundGuidanceEnabled: Bool,
        audioService: (any ChillCuePlaying)? = nil
    ) {
        let clock = ContinuousClock()
        self.clock = clock
        self.origin = clock.now
        self.soundGuidanceEnabled = soundGuidanceEnabled
        if let audioService {
            self.audioService = audioService
        } else if soundGuidanceEnabled {
            self.audioService = ChillAudioService()
        } else {
            self.audioService = nil
        }
        self.timeline = ChillSessionTimeline(
            pattern: pattern,
            durationSeconds: TimeInterval(min(max(durationMinutes, 1), 60) * 60)
        )

        if soundGuidanceEnabled {
            self.audioService?.onInterruption = { [weak self] in
                self?.pauseForSystemEvent("La séance est en pause après une interruption audio.")
            }
            self.audioService?.onHeadphonesDisconnected = { [weak self] in
                self?.pauseForSystemEvent("La sortie audio a été déconnectée. La séance est en pause.")
            }
            self.audioService?.onMediaServicesReset = { [weak self] in
                self?.pauseForSystemEvent("Le service audio a été réinitialisé. Reprenez la séance pour relancer les signaux.")
            }
            self.audioService?.onPlayRequest = { [weak self] in self?.resume() }
            self.audioService?.onPauseRequest = { [weak self] in self?.pause() }
            self.audioService?.onStopRequest = { [weak self] in self?.stop() }
        }
    }

    var isRunning: Bool { timeline.status == .running }
    var isPaused: Bool { timeline.status == .paused }
    var isFinished: Bool { timeline.status == .completed || timeline.status == .stopped }

    var currentTimeline: ChillSessionTimeline {
        var snapshot = timeline
        if snapshot.status == .running { snapshot.refresh(at: monotonicSeconds) }
        return snapshot
    }

    func startIfNeeded() {
        guard !hasStarted else { return }
        if soundGuidanceEnabled {
            guard let audioService else {
                audioError = "Le service de guidage sonore est indisponible."
                return
            }
            do {
                try audioService.start(pattern: timeline.pattern, durationSeconds: timeline.durationSeconds)
            } catch {
                audioService.stop()
                audioError = error.localizedDescription
                return
            }
        }
        var next = timeline
        next.start(at: monotonicSeconds)
        timeline = next
        hasStarted = true
    }

    func refresh() {
        refresh(atMonotonicSeconds: monotonicSeconds)
    }

    func refresh(atMonotonicSeconds now: TimeInterval) {
        guard timeline.status == .running else { return }
        var next = timeline
        next.refresh(at: now)
        timeline = next
        if soundGuidanceEnabled {
            audioService?.updateNowPlaying(elapsedSeconds: next.elapsedSeconds, durationSeconds: next.durationSeconds, isPaused: false)
            if next.status == .completed { audioService?.stop() }
        }
    }

    func pause() {
        guard timeline.status == .running else { return }
        var next = timeline
        next.pause(at: monotonicSeconds)
        timeline = next
        if soundGuidanceEnabled {
            if next.status == .completed {
                audioService?.stop()
            } else {
                audioService?.pause()
                audioService?.updateNowPlaying(elapsedSeconds: next.elapsedSeconds, durationSeconds: next.durationSeconds, isPaused: true)
            }
        }
        pauseMessage = nil
    }

    func resume() {
        guard timeline.status == .paused else { return }
        if soundGuidanceEnabled {
            guard let audioService else {
                audioError = "Le service de guidage sonore est indisponible."
                return
            }
            do { try audioService.resume(after: timeline.elapsedSeconds) }
            catch {
                audioError = error.localizedDescription
                return
            }
        }
        var next = timeline
        next.resume(at: monotonicSeconds)
        timeline = next
        pauseMessage = nil
    }

    func stop() {
        guard timeline.status == .running || timeline.status == .paused else { return }
        var next = timeline
        if next.status == .running { next.pause(at: monotonicSeconds) }
        next.stop()
        timeline = next
        if soundGuidanceEnabled { audioService?.stop() }
    }

    func sceneDidChange(_ phase: ScenePhase) {
        if phase == .background {
            if !soundGuidanceEnabled, timeline.status == .running {
                pauseForSystemEvent("Sans guidage sonore, la séance se met en pause en arrière-plan.")
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
        if soundGuidanceEnabled {
            if next.status == .completed {
                audioService?.stop()
            } else {
                audioService?.pause()
                audioService?.updateNowPlaying(elapsedSeconds: next.elapsedSeconds, durationSeconds: next.durationSeconds, isPaused: true)
            }
        }
        pauseMessage = message
    }

    private var monotonicSeconds: TimeInterval {
        let components = origin.duration(to: clock.now).components
        return TimeInterval(components.seconds) + TimeInterval(components.attoseconds) / 1_000_000_000_000_000_000
    }
}
