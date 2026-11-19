import Foundation

enum ChillBreathingCue: Equatable {
    case inhale
    case exhale
}

// A rounded two-partial waveform avoids the buzzy character of the Warm prototype.
// A proportional raised-cosine release shortens the audible plateau without changing phase timing.
final class ChillBreathingCueSound {
    static let sampleRate = 44_100.0
    static let peakLevel = 0.28
    private let inhalePartials: [(ratio: Double, level: Double)] = [(2, 0.17), (3, 0.05)]
    private let exhalePartials: [(ratio: Double, level: Double)] = [(2, 0.13), (3, 0.015)]
    private var inhaleSamples: [Float] = []
    private var exhaleSamples: [Float] = []

    func prepare(for pattern: ChillBreathingPattern) {
        inhaleSamples = makeSamples(cue: .inhale, durationSeconds: Double(pattern.inhaleSeconds))
        exhaleSamples = makeSamples(cue: .exhale, durationSeconds: Double(pattern.exhaleSeconds))
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
        let framePosition = cueAge * Self.sampleRate
        let frame = Int(framePosition)
        guard samples.indices.contains(frame) else { return 0 }
        let fraction = Float(framePosition - Double(frame))
        let sample = if samples.indices.contains(frame + 1) {
            samples[frame] + (samples[frame + 1] - samples[frame]) * fraction
        } else {
            samples[frame]
        }
        let safeVolume = Float(min(max(volume, 0), 1))
        return sample * safeVolume
    }

    private func makeSamples(cue: ChillBreathingCue, durationSeconds: TimeInterval) -> [Float] {
        let frameCount = Int(Self.sampleRate * durationSeconds)
        let frequency = cue == .inhale ? 200.0 : 170.0
        let partials = cue == .inhale ? inhalePartials : exhalePartials
        let fadeOutSeconds = durationSeconds * 0.2
        let fadeOutStart = durationSeconds - fadeOutSeconds
        let conservativePeakBound = 1 + partials.reduce(0) { $0 + $1.level }

        return (0..<frameCount).map { frame in
            let time = Double(frame) / Self.sampleRate
            let envelope: Double
            if time <= fadeOutStart {
                envelope = 1
            } else {
                let progress = min(1, (time - fadeOutStart) / fadeOutSeconds)
                envelope = 0.5 + 0.5 * cos(.pi * progress)
            }
            let phase = 2 * .pi * frequency * time
            let fundamental = sin(phase)
            let harmonics = partials.reduce(0.0) { sum, partial in
                sum + partial.level * sin(phase * partial.ratio)
            }
            return Float((Self.peakLevel / conservativePeakBound) * envelope * (fundamental + harmonics))
        }
    }
}
