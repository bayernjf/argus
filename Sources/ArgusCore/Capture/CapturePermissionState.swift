import Foundation

/// Screen Recording permission as Argus carries it. TCC does not distinguish
/// "never asked" from "explicitly denied" through its preflight API, so the
/// mapping (`notDetermined` before the first in-launch request) lives in the
/// Argus target; core only carries the outcome.
public enum CapturePermissionState: Equatable, Sendable {
    case granted
    case denied
    case notDetermined
}

/// Injectable seam for permission queries so capture flows can be exercised
/// without touching TCC (docs/02 §测试接缝, docs/06 contract level).
public protocol CapturePermissionProviding: Sendable {
    func currentState() async -> CapturePermissionState
    /// Triggers the system prompt when appropriate; returns the state after
    /// the user responds (or immediately when the prompt cannot be shown).
    func requestAccess() async -> CapturePermissionState
}
