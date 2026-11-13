import Foundation

enum ChillBreathingCue: Equatable {
    case inhale
    case exhale
}

// Fixed-pitch, softly struck notes: D4 marks inhale and A3 marks exhale.
// A short eased attack and tapered decay keep each original cue click-free.
// Samples are generated once and only emitted at breathing-phase boundaries.

final class ChillBreathingCueSound {
    static let sampleRate = 44_100.0
    static let durationSeconds = 0.26

    private static let peakLevel = 0.055
    private static let attackSeconds = 0.008
    private static let tailStartSeconds = 0.20
    private static let tailSeconds = durationSeconds - tailStartSeconds

    private let inhaleSamples: [Float]
    private let exhaleSamples: [Float]

    init() {
        inhaleSamples = Self.makeSamples(frequency: 293.66)
        exhaleSamples = Self.makeSamples(frequency: 220.0)
    }

    func samples(for cue: ChillBreathingCue) -> [Float] {
        switch cue {
        case .inhale: return inhaleSamples
        case .exhale: return exhaleSamples
        }
    }

    func sample(
        at elapsedSeconds: TimeInterval,
        sessionStartElapsed: TimeInterval,
        pattern: ChillBreathingPattern,
        volume: Double
    ) -> Float {
        guard elapsedSeconds.isFinite, sessionStartElapsed.isFinite,
              elapsedSeconds >= 0, sessionStartElapsed >= 0,
              volume.isFinite else { return 0 }

        let cycleLength = TimeInterval(pattern.cycleSeconds)
        let cyclePosition = elapsedSeconds.truncatingRemainder(dividingBy: cycleLength)
        let cycleStart = elapsedSeconds - cyclePosition
        let cueStart: TimeInterval
        let cueAge: TimeInterval
        let isInhale: Bool

        if cyclePosition < TimeInterval(pattern.inhaleSeconds) {
            cueStart = cycleStart
            cueAge = cyclePosition
            isInhale = true
        } else {
            cueStart = cycleStart + TimeInterval(pattern.inhaleSeconds)
            cueAge = cyclePosition - TimeInterval(pattern.inhaleSeconds)
            isInhale = false
        }

        guard cueStart >= sessionStartElapsed, cueAge >= 0,
              cueAge < Self.durationSeconds else { return 0 }
        let frame = Int(cueAge * Self.sampleRate)
        let safeVolume = Float(min(max(volume, 0), 1))
        if isInhale, inhaleSamples.indices.contains(frame) {
            return inhaleSamples[frame] * safeVolume
        }
        if !isInhale, exhaleSamples.indices.contains(frame) {
            return exhaleSamples[frame] * safeVolume
        }
        return 0
    }

    private static func makeSamples(frequency: Double) -> [Float] {
        let frameCount = Int(sampleRate * durationSeconds)
        return (0..<frameCount).map { frame in
            guard frame < frameCount - 1 else { return 0 }
            let time = Double(frame) / sampleRate
            let attack = time < attackSeconds
                ? 0.5 - 0.5 * cos(.pi * time / attackSeconds)
                : 1
            let decay = exp(-time / 0.11)
            let tail = time > tailStartSeconds
                ? 0.5 + 0.5 * cos(.pi * (time - tailStartSeconds) / tailSeconds)
                : 1
            let fundamental = sin(2 * .pi * frequency * time)
            let secondPartial = 0.18 * sin(2 * .pi * frequency * 2 * time + 0.18)
            let thirdPartial = 0.04 * sin(2 * .pi * frequency * 3 * time + 0.35)
            return Float(peakLevel * attack * decay * tail * (fundamental + secondPartial + thirdPartial))
        }
    }
}
