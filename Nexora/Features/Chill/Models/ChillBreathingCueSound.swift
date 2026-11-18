import Foundation

enum ChillBreathingCue: Equatable {
    case inhale
    case exhale
}

// Warm prototype: soft fundamental with restrained second–fourth harmonics.
// Raised-cosine phase edges avoid clicks and follow the selected breathing pattern.
final class ChillBreathingCueSound {
    static let sampleRate = 44_100.0
    static let peakLevel = 0.22
    private let partials: [(ratio: Double, level: Double, phase: Double)] = [
        (2, 0.31, 0.10),
        (3, 0.12, 0.23),
        (4, 0.03, 0.37)
    ]
    private var inhaleSamples: [Float] = []
    private var exhaleSamples: [Float] = []

    func prepare(for pattern: ChillBreathingPattern) {
        inhaleSamples = makeSamples(durationSeconds: Double(pattern.inhaleSeconds))
        exhaleSamples = makeSamples(durationSeconds: Double(pattern.exhaleSeconds))
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
        let inhaleDuration = TimeInterval(pattern.inhaleSeconds)
        let isInhale = cyclePosition < inhaleDuration
        let cueStart = isInhale ? cycleStart : cycleStart + inhaleDuration
        let cueAge = isInhale ? cyclePosition : cyclePosition - inhaleDuration
        let samples = isInhale ? inhaleSamples : exhaleSamples

        guard cueStart >= sessionStartElapsed, cueAge >= 0 else { return 0 }
        let frame = Int(cueAge * Self.sampleRate)
        guard samples.indices.contains(frame) else { return 0 }
        let safeVolume = Float(min(max(volume, 0), 1))
        return samples[frame] * safeVolume
    }

    private func makeSamples(durationSeconds: TimeInterval) -> [Float] {
        let frameCount = Int(Self.sampleRate * durationSeconds)
        let fadeInSeconds = min(0.9, durationSeconds / 3)
        let fadeOutSeconds = min(1.1, durationSeconds / 3)
        let fadeOutStart = durationSeconds - fadeOutSeconds
        let conservativePeakBound = 1 + partials.reduce(0) { $0 + $1.level }

        return (0..<frameCount).map { frame in
            let time = Double(frame) / Self.sampleRate
            let envelope: Double
            if time < fadeInSeconds {
                envelope = 0.5 - 0.5 * cos(.pi * time / fadeInSeconds)
            } else if time > fadeOutStart {
                envelope = 0.5 + 0.5 * cos(.pi * (time - fadeOutStart) / fadeOutSeconds)
            } else {
                envelope = 1
            }
            let fundamental = sin(2 * .pi * 174.61 * time)
            let harmonics = partials.reduce(0.0) { sum, partial in
                sum + partial.level * sin(2 * .pi * 174.61 * partial.ratio * time + partial.phase)
            }
            return Float((Self.peakLevel / conservativePeakBound) * envelope * (fundamental + harmonics))
        }
    }
}
