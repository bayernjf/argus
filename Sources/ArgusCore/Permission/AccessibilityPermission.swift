import Foundation

/// Accessibility (AX) permission as Argus carries it. Like Screen
/// Recording, TCC cannot distinguish "never asked" from "denied" through
/// `AXIsProcessTrusted`, so the in-launch bookkeeping lives in the Argus
/// target and core only carries the outcome.
public enum AccessibilityPermissionState: Equatable, Sendable {
    case granted
    case denied
    case notDetermined
}

/// Injectable seam so activation flows can describe the degraded path
/// without touching real TCC (docs/06 contract level).
public protocol AccessibilityPermissionProviding: Sendable {
    func currentState() async -> AccessibilityPermissionState
    /// Shows the system prompt when appropriate and returns the state after
    /// the user responds.
    func requestAccess() async -> AccessibilityPermissionState
}
