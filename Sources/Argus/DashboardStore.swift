import ArgusCore
import AppKit
import CoreGraphics
import Observation

/// Per-target capture lifecycle as the cards see it. Failed capture keeps
/// the last reason string so the card can explain itself.
enum CaptureState: Equatable, Sendable {
    case connecting
    case live
    case failed(String)
}

/// Builds a capture session for a picked window. Injectable so tests can
/// drive deterministic frames (docs/02 §测试接缝).
typealias CaptureSessionFactory = @Sendable (CaptureWindowInfo) async throws -> CaptureSource

/// Sendable holder so the nonisolated deinit can cancel the poll loop;
/// @Observable cannot carry nonisolated mutable stored properties itself.
private final class PollTaskBox: @unchecked Sendable {
    private let lock = NSLock()
    private var underlying: Task<Void, Never>?

    var task: Task<Void, Never>? {
        get {
            lock.lock()
            defer { lock.unlock() }
            return underlying
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            underlying = newValue
        }
    }

    func cancel() {
        task?.cancel()
        task = nil
    }
}

/// M1 dashboard state owner (docs/02 §模块边界): targets, permission state,
/// window enumeration and per-target capture sessions. Window activation is
/// M2 scope; reply detection is M3.
@MainActor
@Observable
final class DashboardStore {
    private(set) var targets: [TargetApplication] = []
    private(set) var permissionState: CapturePermissionState = .notDetermined
    private(set) var availableWindows: [CaptureWindowInfo] = []
    /// Eligible windows before excluding monitored ones; lets the picker
    /// distinguish "nothing on screen" from "everything is monitored".
    private(set) var eligibleWindowCount = 0
    private(set) var isEnumerating = false
    private(set) var enumerationError: String?

    /// Latest captured frame per target, in memory only (docs/02: 禁止落盘).
    private(set) var latestFrames: [UUID: CGImage] = [:]
    private(set) var captureStates: [UUID: CaptureState] = [:]

    /// Picked-window id per target (CGWindowID space, same as SCWindow.windowID).
    private var targetWindowIDs: [UUID: UInt32] = [:]

    var isShowingPicker = false

    private let permission: CapturePermissionProviding
    private let makeSession: CaptureSessionFactory
    private var sessions: [UUID: CaptureSource] = [:]
    private let pollTaskBox = PollTaskBox()

    init(
        permission: CapturePermissionProviding = PermissionManager(),
        initialTargets: [TargetApplication] = [],
        captureFactory: @escaping CaptureSessionFactory = { try await ScreenCaptureSession(target: $0) }
    ) {
        self.permission = permission
        self.targets = initialTargets
        self.makeSession = captureFactory
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
        pollTaskBox.cancel()
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
            let all = try await WindowEnumerator.enumerateWindows()
            eligibleWindowCount = all.count
            // Windows already being monitored disappear from the picker;
            // removing a target brings them back on the next enumeration.
            let monitored = Set(targetWindowIDs.values)
            availableWindows = CaptureWindowInfo.excludingMonitored(all, monitoredWindowIDs: monitored)
            enumerationError = nil
        } catch {
            availableWindows = []
            eligibleWindowCount = 0
            enumerationError = error.localizedDescription
        }
    }

    func addTarget(_ window: CaptureWindowInfo) {
        // The picker filters already-monitored windows, but a stale sheet
        // could still offer one; a duplicate target would double-capture.
        guard !targetWindowIDs.values.contains(window.id) else { return }
        let target = window.makeTarget()
        targets.append(target)
        targetWindowIDs[target.id] = window.id
        isShowingPicker = false
        startCapture(for: target, window: window)
    }

    func removeTarget(id: UUID) {
        targets.removeAll { $0.id == id }
        targetWindowIDs.removeValue(forKey: id)
        if let session = sessions.removeValue(forKey: id) {
            session.stop()
        }
        latestFrames.removeValue(forKey: id)
        captureStates.removeValue(forKey: id)
        if sessions.isEmpty {
            pollTaskBox.cancel()
        }
    }

    // MARK: Capture sessions

    private func startCapture(for target: TargetApplication, window: CaptureWindowInfo) {
        captureStates[target.id] = .connecting
        ensureFramePolling()
        Task {
            do {
                let session = try await makeSession(window)
                try await session.start()
                sessions[target.id] = session
                captureStates[target.id] = .live
            } catch {
                captureStates[target.id] = .failed(describeCaptureError(error))
            }
        }
    }

    /// The frame protocol is pull-based, so one poller drains every live
    /// session onto the observable frame dict at twice the capture rate.
    private func ensureFramePolling() {
        guard pollTaskBox.task == nil else { return }
        pollTaskBox.task = Task {
            while !Task.isCancelled {
                pollFrames()
                try? await Task.sleep(nanoseconds: 250_000_000)
            }
        }
    }

    private func pollFrames() {
        var deadIDs: [UUID] = []
        for (id, session) in sessions {
            if session.isFailed {
                captureStates[id] = .failed(session.failureMessage ?? "Capture failed")
                deadIDs.append(id)
                continue
            }
            // SCStream keeps delivering a frozen last frame when the picked
            // window closes without sending didStopWithError (observed on
            // macOS 27), so existence is re-checked against CGWindowList.
            // The .optionAll list still contains minimized windows, so a
            // minimized target is not mistaken for a closed one.
            if let windowID = targetWindowIDs[id], !windowExists(windowID) {
                captureStates[id] = .failed("Window closed")
                deadIDs.append(id)
                continue
            }
            guard let frame = session.latestFrame() else { continue }
            latestFrames[id] = frame.image
            if let index = targets.firstIndex(where: { $0.id == id }) {
                targets[index].lastFrameAt = frame.capturedAt
            }
        }
        for id in deadIDs {
            sessions.removeValue(forKey: id)?.stop()
        }
    }

    private func windowExists(_ windowID: UInt32) -> Bool {
        let list = CGWindowListCopyWindowInfo([.optionAll], kCGNullWindowID) as? [[String: Any]] ?? []
        return list.contains { ($0[kCGWindowNumber as String] as? NSNumber)?.uint32Value == windowID }
    }

    private func describeCaptureError(_ error: Error) -> String {
        (error as? CaptureSessionError)?.description ?? error.localizedDescription
    }

    func openScreenRecordingSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!
        NSWorkspace.shared.open(url)
    }
}
