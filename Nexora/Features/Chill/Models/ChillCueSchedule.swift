import Foundation

struct ChillCueEvent: Equatable {
    let elapsedSeconds: TimeInterval
    let phase: ChillSessionTimeline.Phase
}

enum ChillCueSchedule {
    static func events(
        pattern: ChillBreathingPattern,
        durationSeconds: TimeInterval,
        strictlyAfter elapsedSeconds: TimeInterval? = nil
    ) -> [ChillCueEvent] {
        guard durationSeconds > 0 else { return [] }
        var result: [ChillCueEvent] = []
        var time: TimeInterval = 0
        var phase: ChillSessionTimeline.Phase = .inhale

        while time < durationSeconds {
            let shouldInclude = elapsedSeconds.map { time > $0 } ?? true
            if shouldInclude {
                result.append(ChillCueEvent(elapsedSeconds: time, phase: phase))
            }
            let length = phase == .inhale ? pattern.inhaleSeconds : pattern.exhaleSeconds
            time += TimeInterval(length)
            phase = phase == .inhale ? .exhale : .inhale
        }
        return result
    }
}
