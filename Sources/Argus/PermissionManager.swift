import ArgusCore
import CoreGraphics

/// Screen Recording TCC mapping (docs/02 §权限). CGPreflight cannot tell
/// "never asked" from "denied", so the in-launch request bookkeeping lives
/// here; hot updates are driven by the store re-querying on app activation.
@MainActor
final class PermissionManager: CapturePermissionProviding {
    private var hasRequestedThisLaunch = false

    func currentState() -> CapturePermissionState {
        if CGPreflightScreenCaptureAccess() {
            return .granted
        }
        return hasRequestedThisLaunch ? .denied : .notDetermined
    }

    /// Shows the system prompt when the state allows it. The request runs off
    /// the main thread so the TCC dialog never blocks the UI runloop; the
    /// picker sheet stays interactive while it is up.
    func requestAccess() async -> CapturePermissionState {
        hasRequestedThisLaunch = true
        if CGPreflightScreenCaptureAccess() {
            return .granted
        }
        let granted = await Task.detached(priority: .userInitiated) {
            CGRequestScreenCaptureAccess()
        }.value
        return granted ? .granted : .denied
    }
}
