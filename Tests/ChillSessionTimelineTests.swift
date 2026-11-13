import SwiftUI
import XCTest
@testable import Nexora

final class ChillSessionTimelineTests: XCTestCase {
    func testChillIsOneOfFivePrimaryTabs() {
        XCTAssertEqual(AppTab.allCases.count, 5)
        XCTAssertEqual(AppTab.allCases.filter { $0 == .chill }.count, 1)
    }

    func testPresetPatternsMatchTheirPublishedDurations() {
        XCTAssertEqual(ChillBreathingMode.coherence.pattern(customInhale: 2, customExhale: 10), .coherence)
        XCTAssertEqual(ChillBreathingMode.fourSix.pattern(customInhale: 2, customExhale: 10), .fourSix)
        XCTAssertEqual(ChillBreathingMode.fourFour.pattern(customInhale: 2, customExhale: 10), .fourFour)
        XCTAssertEqual(ChillBreathingPattern.coherence.cycleSeconds, 10)
        XCTAssertEqual(ChillBreathingPattern.fourSix.cycleSeconds, 10)
        XCTAssertEqual(ChillBreathingPattern.fourFour.cycleSeconds, 8)
    }

    func testCustomPatternClampsBothPhasesToComfortableBounds() {
        XCTAssertEqual(ChillBreathingPattern(inhaleSeconds: 1, exhaleSeconds: 30), ChillBreathingPattern(inhaleSeconds: 2, exhaleSeconds: 10))
        XCTAssertEqual(ChillBreathingMode.custom.pattern(customInhale: 7, customExhale: 3), ChillBreathingPattern(inhaleSeconds: 7, exhaleSeconds: 3))
    }

    func testPhaseAndProgressAdvanceContinuouslyAtExactBoundaries() {
        var timeline = ChillSessionTimeline(pattern: .fourSix, durationSeconds: 300)
        timeline.start(at: 100)
        timeline.refresh(at: 103.5)
        XCTAssertEqual(timeline.phase, .inhale)
        XCTAssertEqual(timeline.phaseProgress, 0.875, accuracy: 0.0001)
        XCTAssertEqual(timeline.remainingSeconds, 297)
        timeline.refresh(at: 104)
        XCTAssertEqual(timeline.phase, .exhale)
        XCTAssertEqual(timeline.phaseProgress, 0, accuracy: 0.0001)
        timeline.refresh(at: 107)
        XCTAssertEqual(timeline.phaseProgress, 0.5, accuracy: 0.0001)
        timeline.refresh(at: 110)
        XCTAssertEqual(timeline.phase, .inhale)
        XCTAssertEqual(timeline.phaseProgress, 0, accuracy: 0.0001)
    }

    func testPauseFreezesElapsedTimeAndResumeContinuesFromSamePhase() {
        var timeline = ChillSessionTimeline(pattern: .fourSix, durationSeconds: 600)
        timeline.start(at: 20)
        timeline.pause(at: 23)
        XCTAssertEqual(timeline.elapsedSeconds, 3)
        XCTAssertEqual(timeline.status, .paused)
        XCTAssertEqual(timeline.phase, .inhale)
        timeline.refresh(at: 90)
        XCTAssertEqual(timeline.elapsedSeconds, 3)
        timeline.resume(at: 90)
        timeline.refresh(at: 91)
        XCTAssertEqual(timeline.elapsedSeconds, 4)
        XCTAssertEqual(timeline.phase, .exhale)
        XCTAssertEqual(timeline.status, .running)
    }

    func testManualStopFreezesTimeline() {
        var timeline = ChillSessionTimeline(pattern: .coherence, durationSeconds: 600)
        timeline.start(at: 0)
        timeline.refresh(at: 12)
        timeline.stop()
        timeline.refresh(at: 100)
        XCTAssertEqual(timeline.status, .stopped)
        XCTAssertEqual(timeline.elapsedSeconds, 12)
        XCTAssertEqual(timeline.remainingSeconds, 588)
    }

    func testSessionCompletesAutomaticallyAndCapsElapsedTime() {
        var timeline = ChillSessionTimeline(pattern: .fourFour, durationSeconds: 60)
        timeline.start(at: 5)
        timeline.refresh(at: 64.9)
        XCTAssertEqual(timeline.status, .running)
        XCTAssertEqual(timeline.remainingSeconds, 1)
        timeline.refresh(at: 65)
        XCTAssertEqual(timeline.status, .completed)
        XCTAssertEqual(timeline.remainingSeconds, 0)
        XCTAssertEqual(timeline.elapsedSeconds, 60)
        timeline.refresh(at: 500)
        XCTAssertEqual(timeline.elapsedSeconds, 60)
    }

    func testBackgroundGapIsReconciledFromMonotonicElapsedTime() {
        var timeline = ChillSessionTimeline(pattern: .coherence, durationSeconds: 300)
        timeline.start(at: 10)
        timeline.refresh(at: 130)
        XCTAssertEqual(timeline.elapsedSeconds, 120)
        XCTAssertEqual(timeline.remainingSeconds, 180)
        XCTAssertEqual(timeline.phase, .inhale)
    }

    @MainActor
    func testStartPauseResumeStopDoNotCreateDuplicateAudioEngines() {
        let audio = ChillCueSpy()
        let controller = ChillSessionController(pattern: .coherence, durationMinutes: 5, soundGuidanceEnabled: true, audioService: audio)
        controller.startIfNeeded()
        controller.startIfNeeded()
        XCTAssertEqual(audio.startCount, 1)
        XCTAssertEqual(controller.timeline.status, .running)
        controller.pause()
        XCTAssertEqual(audio.pauseCount, 1)
        XCTAssertEqual(controller.timeline.status, .paused)
        controller.resume()
        XCTAssertEqual(audio.resumeCount, 1)
        XCTAssertEqual(controller.timeline.status, .running)
        controller.stop()
        controller.stop()
        XCTAssertEqual(audio.stopCount, 1)
        XCTAssertEqual(controller.timeline.status, .stopped)
    }

    @MainActor
    func testDisabledGuidanceDoesNotStartAudioAndPausesInBackground() {
        let audio = ChillCueSpy()
        let controller = ChillSessionController(pattern: .coherence, durationMinutes: 5, soundGuidanceEnabled: false, audioService: audio)
        controller.startIfNeeded()
        XCTAssertEqual(controller.timeline.status, .running)
        XCTAssertEqual(audio.startCount, 0)
        controller.sceneDidChange(.background)
        XCTAssertEqual(controller.timeline.status, .paused)
        XCTAssertEqual(audio.pauseCount, 0)
    }

    @MainActor
    func testRemoteCommandsUseTheSamePauseResumeAndStopTransitions() {
        let audio = ChillCueSpy()
        let controller = ChillSessionController(pattern: .coherence, durationMinutes: 5, soundGuidanceEnabled: true, audioService: audio)
        controller.startIfNeeded()
        audio.onPauseRequest?()
        XCTAssertEqual(controller.timeline.status, .paused)
        audio.onPlayRequest?()
        XCTAssertEqual(controller.timeline.status, .running)
        audio.onStopRequest?()
        XCTAssertEqual(controller.timeline.status, .stopped)
    }

    @MainActor
    func testEnabledGuidanceKeepsSessionRunningInBackgroundAndInterruptionPauses() {
        let audio = ChillCueSpy()
        let controller = ChillSessionController(pattern: .fourSix, durationMinutes: 5, soundGuidanceEnabled: true, audioService: audio)
        controller.startIfNeeded()
        controller.sceneDidChange(.background)
        XCTAssertEqual(controller.timeline.status, .running)
        audio.onInterruption?()
        XCTAssertEqual(controller.timeline.status, .paused)
        XCTAssertEqual(controller.pauseMessage, "La séance est en pause après une interruption audio.")
    }

    @MainActor
    func testManualStopStopsCueService() {
        let audio = ChillCueSpy()
        let controller = ChillSessionController(pattern: .coherence, durationMinutes: 1, soundGuidanceEnabled: true, audioService: audio)
        controller.startIfNeeded()
        controller.stop()
        XCTAssertEqual(controller.timeline.status, .stopped)
        XCTAssertEqual(audio.stopCount, 1)
    }

    @MainActor
    func testAutomaticCompletionStopsCueService() {
        let audio = ChillCueSpy()
        let controller = ChillSessionController(pattern: .coherence, durationMinutes: 1, soundGuidanceEnabled: true, audioService: audio)
        controller.startIfNeeded()
        controller.refresh(atMonotonicSeconds: 61)
        XCTAssertEqual(controller.timeline.status, .completed)
        XCTAssertEqual(audio.stopCount, 1)
    }

    func testRequestedSessionDurationIsBoundedToOneThroughSixtyMinutes() {
        XCTAssertEqual(ChillSessionTimeline(pattern: .coherence, durationSeconds: 5).durationSeconds, 60)
        XCTAssertEqual(ChillSessionTimeline(pattern: .coherence, durationSeconds: 90_000).durationSeconds, 3_600)
    }

    func testBreathingCircleReachesBothExactEndpointsAndFitsCompactScreens() {
        let maxDiameter = ChillBreathingVisualMetrics.maximumDiameter(availableWidth: 320, availableHeight: 600)
        XCTAssertEqual(maxDiameter, 252, accuracy: 0.001)
        XCTAssertEqual(ChillBreathingVisualMetrics.diameter(maximum: maxDiameter, phase: .inhale, progress: 0), maxDiameter * 0.48, accuracy: 0.001)
        XCTAssertEqual(ChillBreathingVisualMetrics.diameter(maximum: maxDiameter, phase: .inhale, progress: 1), maxDiameter, accuracy: 0.001)
        XCTAssertEqual(ChillBreathingVisualMetrics.diameter(maximum: maxDiameter, phase: .exhale, progress: 0), maxDiameter, accuracy: 0.001)
        XCTAssertEqual(ChillBreathingVisualMetrics.diameter(maximum: maxDiameter, phase: .exhale, progress: 1), maxDiameter * 0.48, accuracy: 0.001)
        XCTAssertEqual(ChillBreathingVisualMetrics.maximumDiameter(availableWidth: 320, availableHeight: 100), 42, accuracy: 0.001)
        XCTAssertEqual(ChillBreathingVisualMetrics.maximumDiameter(availableWidth: 40, availableHeight: 100), 0, accuracy: 0.001)
    }

    func testBreathingCueSamplesAreShortDistinctAndTapered() {
        let sound = ChillBreathingCueSound()
        let inhale = sound.samples(for: .inhale)
        let exhale = sound.samples(for: .exhale)
        let inhalePeak = inhale.map { abs($0) }.max() ?? 0
        let exhalePeak = exhale.map { abs($0) }.max() ?? 0

        XCTAssertEqual(inhale.count, Int(ChillBreathingCueSound.sampleRate * ChillBreathingCueSound.durationSeconds))
        XCTAssertNotEqual(inhale, exhale)
        XCTAssertEqual(inhale.first ?? 1, 0, accuracy: 0.000001)
        XCTAssertEqual(inhale.last ?? 1, 0, accuracy: 0.000001)
        XCTAssertGreaterThan(inhalePeak, 0.04)
        XCTAssertLessThan(inhalePeak, 0.08)
        XCTAssertEqual(exhalePeak, inhalePeak, accuracy: 0.02)
    }

    func testBreathingCuePlaybackIsPhaseSynchronizedAndSilentBetweenCues() {
        let pattern = ChillBreathingPattern(inhaleSeconds: 4, exhaleSeconds: 6)
        let sound = ChillBreathingCueSound()
        func output(at elapsed: TimeInterval, sessionStart: TimeInterval = 0, volume: Double = 1) -> Float {
            sound.sample(
                at: elapsed,
                sessionStartElapsed: sessionStart,
                pattern: pattern,
                volume: volume
            )
        }

        XCTAssertNotEqual(output(at: 0.01), 0)
        XCTAssertEqual(output(at: 0.30), 0)
        XCTAssertNotEqual(output(at: 4.01), 0)
        XCTAssertEqual(output(at: 7), 0)
        XCTAssertNotEqual(output(at: 10.01), 0)
        XCTAssertEqual(output(at: 0.11, sessionStart: 0.10), 0)
        XCTAssertNotEqual(output(at: 4.01, sessionStart: 0.10), 0)
        XCTAssertEqual(output(at: 4.11, sessionStart: 4.10), 0)
        XCTAssertNotEqual(output(at: 10.01, sessionStart: 4.10), 0)
        XCTAssertEqual(output(at: 0.01, volume: 0.5), output(at: 0.01) * 0.5, accuracy: 0.000001)
    }

    @MainActor
    func testConfiguredSoundVolumeIsPassedToTheAudioService() {
        let audio = ChillCueSpy()
        let controller = ChillSessionController(
            pattern: .coherence,
            durationMinutes: 5,
            soundGuidanceEnabled: true,
            soundVolume: 0.42,
            audioService: audio
        )
        controller.startIfNeeded()
        XCTAssertEqual(audio.lastStartVolume, 0.42, accuracy: 0.0001)
    }
}

@MainActor
private final class ChillCueSpy: ChillCuePlaying {
    var onInterruption: (() -> Void)?
    var onHeadphonesDisconnected: (() -> Void)?
    var onMediaServicesReset: (() -> Void)?
    var onPlayRequest: (() -> Void)?
    var onPauseRequest: (() -> Void)?
    var onStopRequest: (() -> Void)?
    private(set) var startCount = 0
    private(set) var pauseCount = 0
    private(set) var resumeCount = 0
    private(set) var stopCount = 0
    private(set) var lastStartVolume = 0.0

    func start(pattern: ChillBreathingPattern, durationSeconds: TimeInterval, volume: Double) throws {
        startCount += 1
        lastStartVolume = volume
    }
    func pause() { pauseCount += 1 }
    func resume(after elapsedSeconds: TimeInterval, volume: Double) throws { resumeCount += 1 }
    func updateNowPlaying(elapsedSeconds: TimeInterval, durationSeconds: TimeInterval, isPaused: Bool) { }
    func stop() { stopCount += 1 }
}
