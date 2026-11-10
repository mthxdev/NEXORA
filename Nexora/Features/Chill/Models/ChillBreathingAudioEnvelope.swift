import Foundation

enum ChillBreathingAudioEnvelope {
    struct Position: Equatable {
        let phase: ChillSessionTimeline.Phase
        let progress: Double
    }

    static func position(at elapsedSeconds: TimeInterval, pattern: ChillBreathingPattern) -> Position {
        guard elapsedSeconds.isFinite, elapsedSeconds >= 0 else {
            return Position(phase: .inhale, progress: 0)
        }

        let cycleLength = TimeInterval(pattern.cycleSeconds)
        let cyclePosition = elapsedSeconds.truncatingRemainder(dividingBy: cycleLength)
        if cyclePosition < TimeInterval(pattern.inhaleSeconds) {
            return Position(
                phase: .inhale,
                progress: cyclePosition / TimeInterval(pattern.inhaleSeconds)
            )
        }

        return Position(
            phase: .exhale,
            progress: (cyclePosition - TimeInterval(pattern.inhaleSeconds)) / TimeInterval(pattern.exhaleSeconds)
        )
    }

    static func amplitude(progress: Double, volume: Double) -> Double {
        guard progress.isFinite, volume.isFinite else { return 0 }
        let phaseProgress = min(max(progress, 0), 1)
        let safeVolume = min(max(volume, 0), 1)
        let breathProgress = sin(.pi * phaseProgress)
        let breathEnvelope = breathProgress * breathProgress
        return 0.065 * safeVolume * breathEnvelope
    }

    static func frequency(at elapsedSeconds: TimeInterval, pattern: ChillBreathingPattern) -> Double {
        let position = position(at: elapsedSeconds, pattern: pattern)
        let progress = min(max(position.progress, 0), 1)
        let eased = progress * progress * (3 - 2 * progress)
        let startFrequency = position.phase == .inhale ? 330.0 : 440.0
        let endFrequency = position.phase == .inhale ? 440.0 : 330.0
        return startFrequency + (endFrequency - startFrequency) * eased
    }

    static func sample(at elapsedSeconds: TimeInterval, pattern: ChillBreathingPattern, volume: Double) -> Float {
        guard elapsedSeconds.isFinite, elapsedSeconds >= 0 else { return 0 }
        let position = position(at: elapsedSeconds, pattern: pattern)
        let level = amplitude(progress: position.progress, volume: volume)
        let cycleLength = TimeInterval(pattern.cycleSeconds)
        let cycleNumber = floor(elapsedSeconds / cycleLength)
        let inhaleCycles = integratedCycles(
            progress: position.phase == .inhale ? position.progress : 1,
            duration: TimeInterval(pattern.inhaleSeconds),
            startFrequency: 330,
            endFrequency: 440
        )
        let exhaleCycles = integratedCycles(
            progress: position.phase == .exhale ? position.progress : 0,
            duration: TimeInterval(pattern.exhaleSeconds),
            startFrequency: 440,
            endFrequency: 330
        )
        let cyclesPerFullCycle = TimeInterval(pattern.inhaleSeconds + pattern.exhaleSeconds) * 385
        let cycles = cycleNumber * cyclesPerFullCycle + inhaleCycles + exhaleCycles
        let tonePhase = 2 * .pi * cycles
        let softTone = 0.90 * sin(tonePhase) + 0.10 * sin(tonePhase * 2)
        return Float(level * softTone)
    }

    private static func integratedCycles(progress: Double, duration: TimeInterval, startFrequency: Double, endFrequency: Double) -> Double {
        let p = min(max(progress, 0), 1)
        let integratedSmoothStep = p * p * p - 0.5 * p * p * p * p
        return duration * (startFrequency * p + (endFrequency - startFrequency) * integratedSmoothStep)
    }
}
