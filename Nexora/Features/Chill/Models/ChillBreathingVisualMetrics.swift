import Foundation

enum ChillBreathingVisualMetrics {
    static func maximumDiameter(availableWidth: Double, availableHeight: Double) -> Double {
        guard availableWidth.isFinite, availableHeight.isFinite else { return 0 }
        return max(0, min(420, min(availableWidth - 48, availableHeight * 0.42)))
    }

    static func diameter(maximum: Double, phase: ChillSessionTimeline.Phase, progress: Double) -> Double {
        guard maximum.isFinite, maximum > 0 else { return 0 }
        let linearProgress = min(max(progress.isFinite ? progress : 0, 0), 1)
        let easedProgress = linearProgress * linearProgress * (3 - 2 * linearProgress)
        let minimum = maximum * 0.48
        let travel = maximum - minimum
        switch phase {
        case .inhale:
            return minimum + travel * easedProgress
        case .exhale:
            return maximum - travel * easedProgress
        }
    }
}
