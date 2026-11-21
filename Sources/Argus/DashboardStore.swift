import ArgusCore
import AppKit
import Observation

/// M1 dashboard state owner (docs/02 §模块边界): targets, permission state
/// and window enumeration for the picker. Capture sessions attach in M1c;
/// activation of picked windows is M2 scope.
@MainActor
@Observable
final class DashboardStore {
    private(set) var targets: [TargetApplication] = []
    private(set) var permissionState: CapturePermissionState = .notDetermined
    private(set) var availableWindows: [CaptureWindowInfo] = []
    private(set) var isEnumerating = false
    private(set) var enumerationError: String?

    var isShowingPicker = false

    private let permission: CapturePermissionProviding

    init(
        permission: CapturePermissionProviding = PermissionManager(),
        initialTargets: [TargetApplication] = []
    ) {
        self.permission = permission
        self.targets = initialTargets
        // TCC has no change notification; re-query when the app comes back
        // to the front, which covers "user granted/revoked in System
        // Settings and switched back" (docs/02 §权限 热更新).
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidBecomeActive),
            name: NSApplication.didBecomeActiveNotification,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func appDidBecomeActive() {
        Task { await refreshPermission() }
    }

    func refreshPermission() async {
        permissionState = await permission.currentState()
    }

    /// Opens the picker flow from the Add-target button: request the prompt
    /// when appropriate, then enumerate on success. Kept separate from
    /// "start capture" per docs/02 (不把权限请求和开始捕获合并到一次点击).
    func openPicker() {
        isShowingPicker = true
        Task {
            await refreshPermission()
            if permissionState != .granted {
                permissionState = await permission.requestAccess()
            }
            if permissionState == .granted {
                await enumerateWindows()
            }
        }
    }

    /// Re-checks permission and refreshes the window list; wired to the
    /// picker's Retry button and the System Settings return path.
    func retryAccess() async {
        await refreshPermission()
        if permissionState != .granted {
            permissionState = await permission.requestAccess()
        }
        if permissionState == .granted {
            await enumerateWindows()
        }
    }

    func enumerateWindows() async {
        guard permissionState == .granted else { return }
        isEnumerating = true
        defer { isEnumerating = false }
        do {
            availableWindows = try await WindowEnumerator.enumerateWindows()
            enumerationError = nil
        } catch {
            availableWindows = []
            enumerationError = error.localizedDescription
        }
    }

    func addTarget(_ window: CaptureWindowInfo) {
        targets.append(window.makeTarget())
        isShowingPicker = false
    }

    func removeTarget(id: UUID) {
        targets.removeAll { $0.id == id }
    }

    func openScreenRecordingSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!
        NSWorkspace.shared.open(url)
    }
}
