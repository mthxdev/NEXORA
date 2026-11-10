import AVFoundation
import XCTest
@testable import Nexora

final class ChillSessionTimelineTests: XCTestCase {
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

    func testPhaseChangesAtExactBoundaryAndCountdownUsesCeiling() {
        var timeline = ChillSessionTimeline(pattern: .fourSix, durationSeconds: 300)
        timeline.start(at: 100)

        timeline.refresh(at: 103.2)
        XCTAssertEqual(timeline.phase, .inhale)
        XCTAssertEqual(timeline.phaseRemainingSeconds, 1)
        XCTAssertEqual(timeline.remainingSeconds, 297)

        timeline.refresh(at: 104)
        XCTAssertEqual(timeline.phase, .exhale)
        XCTAssertEqual(timeline.phaseRemainingSeconds, 6)

        timeline.refresh(at: 110)
        XCTAssertEqual(timeline.phase, .inhale)
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

    func testManualStopPreventsLaterRefreshFromAdvancingTimeline() {
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
    func testAudioInterruptionNotificationPausesUntilTheUserResumes() async throws {
        let controller = ChillSessionController(
            pattern: .coherence,
            durationMinutes: 5,
            ambience: .none,
            volume: 0.2
        )
        controller.startIfNeeded()
        XCTAssertEqual(controller.timeline.status, .running)

        NotificationCenter.default.post(
            name: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            userInfo: [AVAudioSessionInterruptionTypeKey: AVAudioSession.InterruptionType.began.rawValue]
        )
        try await Task.sleep(for: .milliseconds(25))

        XCTAssertEqual(controller.timeline.status, .paused)
        controller.resume()
        XCTAssertEqual(controller.timeline.status, .running)
        controller.stop()
    }

    @MainActor
    func testEveryBundledAmbienceHasAPlayableAudioResource() throws {
        for ambience in ChillAmbience.allCases where ambience != .none {
            let url = try XCTUnwrap(ChillAudioService.resourceURL(for: ambience), "Missing audio resource for \(ambience)")
            let player = try AVAudioPlayer(contentsOf: url)
            XCTAssertGreaterThan(player.duration, 20, "Audio resource for \(ambience) is too short to provide a useful ambience")
        }
    }

    func testRequestedSessionDurationIsBoundedToOneThroughSixtyMinutes() {
        XCTAssertEqual(ChillSessionTimeline(pattern: .coherence, durationSeconds: 5).durationSeconds, 60)
        XCTAssertEqual(ChillSessionTimeline(pattern: .coherence, durationSeconds: 90_000).durationSeconds, 3_600)
    }
}
