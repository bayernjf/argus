import Foundation

/// Product limits shared by UI and persistence. Owner decision 2026-11-21:
/// the M2 dashboard caps at three monitored targets, matching the M2 exit
/// criterion (3 targets, 30 minutes). M4 soak data can revise this.
public enum TargetLimits {
    public static let maximumMonitoredTargets = 3

    public static func allowsAnotherTarget(currentCount: Int) -> Bool {
        currentCount < maximumMonitoredTargets
    }
}
