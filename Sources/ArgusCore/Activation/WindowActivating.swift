import Foundation

public enum WindowActivationError: Error, Equatable, Sendable {
    case targetNotRunning
    case windowNotFound
}

/// Brings the target application's window to the foreground.
public protocol WindowActivating {
    func activate(_ target: TargetApplication) throws
}
