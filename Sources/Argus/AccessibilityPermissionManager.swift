@preconcurrency import ApplicationServices
import ArgusCore

/// Accessibility TCC mapping for the optional exact-window switch (docs/02
/// §6). `AXIsProcessTrusted` cannot tell "never asked" from "denied", so the
/// in-launch request bookkeeping lives here.
@MainActor
final class AccessibilityPermissionManager: AccessibilityPermissionProviding {
    private var hasRequestedThisLaunch = false

    func currentState() async -> AccessibilityPermissionState {
        if AXIsProcessTrusted() {
            return .granted
        }
        return hasRequestedThisLaunch ? .denied : .notDetermined
    }

    /// The prompt is deliberately user-initiated (status-strip button), not
    /// triggered by the first capture click: docs/02 forbids mixing a
    /// permission request with an action the user thinks is something else.
    /// The prompt also adds Argus to the Accessibility list, which makes the
    /// System Settings deep link actionable.
    func requestAccess() async -> AccessibilityPermissionState {
        hasRequestedThisLaunch = true
        if AXIsProcessTrusted() {
            return .granted
        }
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        let granted = AXIsProcessTrustedWithOptions(options)
        return granted ? .granted : .denied
    }
}
