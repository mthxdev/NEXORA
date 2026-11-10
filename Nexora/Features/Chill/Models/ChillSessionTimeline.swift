import Foundation

struct ChillSessionTimeline {
    enum Status: Equatable {
        case ready
        case running
        case paused
        case completed
        case stopped
    }

    enum Phase: Equatable {
        case inhale
        case exhale
    }

    let pattern: ChillBreathingPattern
    let durationSeconds: TimeInterval

    private(set) var status: Status = .ready
    private(set) var elapsedSeconds: TimeInterval = 0
    private var elapsedBeforeCurrentRun: TimeInterval = 0
    private var currentRunStartedAt: TimeInterval?

    init(pattern: ChillBreathingPattern, durationSeconds: TimeInterval) {
        self.pattern = pattern
        self.durationSeconds = min(max(durationSeconds, 60), 60 * 60)
    }

    mutating func start(at now: TimeInterval) {
        guard status == .ready else { return }
        elapsedSeconds = 0
        elapsedBeforeCurrentRun = 0
        currentRunStartedAt = now
        status = .running
    }

    mutating func pause(at now: TimeInterval) {
        refresh(at: now)
        guard status == .running else { return }
        elapsedBeforeCurrentRun = elapsedSeconds
        currentRunStartedAt = nil
        status = .paused
    }

    mutating func resume(at now: TimeInterval) {
        guard status == .paused else { return }
        currentRunStartedAt = now
        elapsedBeforeCurrentRun = elapsedSeconds
        status = .running
    }

    mutating func stop() {
        guard status == .running || status == .paused else { return }
        currentRunStartedAt = nil
        status = .stopped
    }

    mutating func refresh(at now: TimeInterval) {
        guard status == .running, let runStartedAt = currentRunStartedAt else { return }
        let runElapsed = max(0, now - runStartedAt)
        elapsedSeconds = min(elapsedBeforeCurrentRun + runElapsed, durationSeconds)
        if elapsedSeconds >= durationSeconds {
            currentRunStartedAt = nil
            elapsedBeforeCurrentRun = durationSeconds
            status = .completed
        }
    }

    var remainingSeconds: Int {
        Int(ceil(max(0, durationSeconds - elapsedSeconds)))
    }

    var phase: Phase {
        guard status != .completed, status != .stopped else { return .inhale }
        let position = elapsedSeconds.truncatingRemainder(dividingBy: TimeInterval(pattern.cycleSeconds))
        return position < TimeInterval(pattern.inhaleSeconds) ? .inhale : .exhale
    }

    var phaseProgress: Double {
        guard status == .running || status == .paused else { return 0 }
        let position = elapsedSeconds.truncatingRemainder(dividingBy: TimeInterval(pattern.cycleSeconds))
        let phaseDuration: TimeInterval
        let phaseElapsed: TimeInterval
        switch phase {
        case .inhale:
            phaseDuration = TimeInterval(pattern.inhaleSeconds)
            phaseElapsed = position
        case .exhale:
            phaseDuration = TimeInterval(pattern.exhaleSeconds)
            phaseElapsed = position - TimeInterval(pattern.inhaleSeconds)
        }
        return min(max(phaseElapsed / phaseDuration, 0), 1)
    }

    var phaseRemainingSeconds: Int {
        let position = elapsedSeconds.truncatingRemainder(dividingBy: TimeInterval(pattern.cycleSeconds))
        let left: TimeInterval
        switch phase {
        case .inhale:
            left = TimeInterval(pattern.inhaleSeconds) - position
        case .exhale:
            left = TimeInterval(pattern.cycleSeconds) - position
        }
        return max(1, Int(ceil(left)))
    }
}
