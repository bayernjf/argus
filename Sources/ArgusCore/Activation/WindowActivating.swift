import Foundation

public enum WindowActivationError: Error, Equatable, Sendable, CustomStringConvertible {
    case targetNotRunning
    /// No window of the target app can be identified as the card's window.
    case windowNotFound
    /// Several windows share the identity; Argus refuses to pick one.
    case ambiguousWindows(count: Int)

    public var description: String {
        switch self {
        case .targetNotRunning:
            "The target application is not running."
        case .windowNotFound:
            "The target window could not be identified."
        case .ambiguousWindows(let count):
            "\(count) windows match the target; refusing to guess which one to raise."
        }
    }
}

/// How much of the switch actually happened. `applicationOnly` means the
/// app was brought forward but Argus could not raise the exact window, so
/// the UI must explain the degradation instead of claiming success.
public enum WindowActivationOutcome: Equatable, Sendable {
    case exactWindow
    case applicationOnly(WindowActivationFallback)
}

public enum WindowActivationFallback: Equatable, Sendable {
    case accessibilityNotGranted
}

/// Brings the target window to the foreground (docs/02 §5, ADR-012).
///
/// Matching happens before activation: when the window cannot be identified
/// uniquely, the app is deliberately left untouched so the user never gets
/// yanked into the wrong window.
@MainActor
public protocol WindowActivating {
    func activate(_ target: TargetApplication) throws -> WindowActivationOutcome
}
