import ArgusCore
import AppKit
import CoreGraphics
import Observation

/// Per-target capture lifecycle as the cards see it. A failed capture keeps
/// the last reason string so the card can explain itself. `unresolved` is a
/// restored card whose window could not be bound without guessing.
enum CaptureState: Equatable, Sendable {
    case connecting
    case live
    case failed(String)
    case unresolved(String)
}

/// Builds a capture session for a card and its picked window. The card id is
/// passed in so `CaptureFrame.targetID` stays meaningful. Injectable so tests
/// can drive deterministic frames (docs/02 §测试接缝).
typealias CaptureSessionFactory = @Sendable (UUID, CaptureWindowInfo) async throws -> CaptureSource

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

/// Dashboard state owner (docs/02 §模块边界): targets, permission state,
/// window enumeration, per-target capture sessions and the persisted list.
/// Window activation is M2b; reply detection is M3.
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
    /// Target being re-bound from an unresolved card; the picker replaces it
    /// instead of adding a fourth card.
    private(set) var rebindTargetID: UUID?

    var isShowingPicker = false

    var canAddTarget: Bool {
        TargetLimits.allowsAnotherTarget(currentCount: targets.count)
    }

    var isRebinding: Bool {
        rebindTargetID != nil
    }

    private let permission: CapturePermissionProviding
    private let makeSession: CaptureSessionFactory
    private let files: TargetFileStore
    private var sessions: [UUID: CaptureSource] = [:]
    private let pollTaskBox = PollTaskBox()

    /// Last loaded list; used to retry unresolved cards once Screen Recording
    /// becomes available without re-reading the file on every attempt.
    private var persistedRecords: [PersistedTarget] = []
    private var didLoadPersistedRecords = false

    init(
        permission: CapturePermissionProviding = PermissionManager(),
        initialTargets: [TargetApplication] = [],
        files: TargetFileStore = TargetFileStore(),
        captureFactory: @escaping CaptureSessionFactory = { targetID, window in
            try await ScreenCaptureSession(targetID: targetID, window: window)
        }
    ) {
        self.permission = permission
        self.targets = initialTargets
        self.files = files
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
                await restorePersistedTargets()
                await enumerateWindows()
            }
        }
    }

    /// Re-checks permission, retries unresolved restored cards and refreshes
    /// the window list; wired to the picker's Retry button.
    func retryAccess() async {
        await refreshPermission()
        if permissionState != .granted {
            permissionState = await permission.requestAccess()
        }
        if permissionState == .granted {
            await restorePersistedTargets()
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

    // MARK: Target list

    func addTarget(_ window: CaptureWindowInfo) {
        if let rebindTargetID {
            rebind(targetID: rebindTargetID, to: window)
            return
        }
        // The picker filters already-monitored windows and the cap, but a
        // stale sheet could still offer one; a duplicate target would
        // double-capture, and a fourth card breaks the M2 limit.
        guard canAddTarget else { return }
        guard !targetWindowIDs.values.contains(window.id) else { return }
        let target = window.makeTarget()
        targets.append(target)
        targetWindowIDs[target.id] = window.id
        isShowingPicker = false
        persistTargets()
        startCapture(for: target, window: window)
    }

    /// Starts replacement mode for an unresolved card: the next pick rebinds
    /// this card instead of adding a new one.
    func beginRebind(targetID: UUID) {
        guard targets.contains(where: { $0.id == targetID }) else { return }
        rebindTargetID = targetID
        openPicker()
    }

    func pickerDidDismiss() {
        rebindTargetID = nil
    }

    func removeTarget(id: UUID) {
        targets.removeAll { $0.id == id }
        targetWindowIDs.removeValue(forKey: id)
        if let session = sessions.removeValue(forKey: id) {
            session.stop()
        }
        latestFrames.removeValue(forKey: id)
        captureStates.removeValue(forKey: id)
        persistedRecords.removeAll { $0.id == id }
        if rebindTargetID == id {
            rebindTargetID = nil
        }
        if sessions.isEmpty {
            pollTaskBox.cancel()
        }
        persistTargets()
    }

    // MARK: Restore

    /// Restores persisted cards without guessing (owner decision 2026-11-21).
    /// Safe to call repeatedly: already bound cards are skipped, unresolved
    /// ones are retried, and new records only fill free slots.
    func restorePersistedTargets() async {
        loadPersistedRecordsIfNeeded()

        let boundIDs = Set(targetWindowIDs.keys)
        let shownUnresolved = persistedRecords.filter { record in
            !boundIDs.contains(record.id) && targets.contains { $0.id == record.id }
        }
        let notShown = persistedRecords.filter { record in
            !targets.contains { $0.id == record.id }
        }
        let freeSlots = max(0, TargetLimits.maximumMonitoredTargets - targets.count)
        let pending = shownUnresolved + notShown.prefix(freeSlots)
        guard !pending.isEmpty else { return }

        await refreshPermission()
        guard permissionState == .granted else {
            for record in pending {
                markUnresolved(record, issue: .permissionRequired, candidateCount: 0)
            }
            return
        }

        do {
            let windows = try await WindowEnumerator.enumerateWindows()
            let restoration = TargetRestorer.restore(pending, against: windows)
            for outcome in restoration.outcomes {
                switch outcome {
                case .restored(let restored):
                    markRestored(restored)
                case .unresolved(let unresolved):
                    markUnresolved(unresolved.record, issue: unresolved.issue, candidateCount: unresolved.candidateCount)
                }
            }
        } catch {
            for record in pending {
                markUnresolved(record, message: "Window list unavailable: \(error.localizedDescription)")
            }
        }
    }

    private func loadPersistedRecordsIfNeeded() {
        guard !didLoadPersistedRecords else { return }
        didLoadPersistedRecords = true
        do {
            persistedRecords = try files.load()?.targets ?? []
        } catch {
            persistedRecords = []
            NSLog("[Argus] targets file unreadable: %@", String(describing: error))
        }
    }

    private func markRestored(_ restored: RestoredTarget) {
        let id = restored.record.id
        let window = restored.window

        if let index = targets.firstIndex(where: { $0.id == id }) {
            targets[index] = window.makeTarget(id: id)
        } else {
            guard canAddTarget else { return }
            targets.append(window.makeTarget(id: id))
        }
        targetWindowIDs[id] = window.id
        latestFrames.removeValue(forKey: id)
        guard let target = targets.first(where: { $0.id == id }) else { return }
        startCapture(for: target, window: window)
    }

    private func markUnresolved(_ record: PersistedTarget, issue: TargetRestoreIssue, candidateCount: Int) {
        let message: String
        switch issue {
        case .permissionRequired:
            message = "Screen Recording is required to restore this target."
        case .missingBundleIdentifier:
            message = "This window reported no app bundle. Re-select it."
        case .noEligibleWindow:
            message = "\(record.displayName) has no on-screen window. Open the app, then re-select."
        case .ambiguousWindows:
            message = "\(candidateCount) windows of \(record.displayName) are open. Re-select the one you want."
        case .windowAlreadyClaimed:
            message = "Another saved target already uses the only \(record.displayName) window. Re-select."
        }
        markUnresolved(record, message: message)
    }

    private func markUnresolved(_ record: PersistedTarget, message: String) {
        guard canAddTarget || targets.contains(where: { $0.id == record.id }) else { return }
        if let index = targets.firstIndex(where: { $0.id == record.id }) {
            var target = targets[index]
            target.displayName = record.displayName
            target.bundleIdentifier = record.bundleIdentifier
            target.windowTitle = record.windowTitle
            targets[index] = target
        } else {
            targets.append(record.makeTargetApplication())
        }
        captureStates[record.id] = .unresolved(message)
    }

    private func rebind(targetID: UUID, to window: CaptureWindowInfo) {
        guard let index = targets.firstIndex(where: { $0.id == targetID }) else {
            rebindTargetID = nil
            return
        }
        guard !targetWindowIDs.values.contains(window.id) else { return }

        if let session = sessions.removeValue(forKey: targetID) {
            session.stop()
        }
        latestFrames.removeValue(forKey: targetID)
        captureStates.removeValue(forKey: targetID)
        targetWindowIDs[targetID] = window.id
        targets[index] = window.makeTarget(id: targetID)
        rebindTargetID = nil
        isShowingPicker = false
        persistTargets()
        startCapture(for: targets[index], window: window)
    }

    private func persistTargets() {
        let records = targets.map(PersistedTarget.init(target:))
        do {
            try files.save(TargetFile(targets: records))
        } catch {
            NSLog("[Argus] failed to save targets: %@", String(describing: error))
        }
    }

    // MARK: Capture sessions

    private func startCapture(for target: TargetApplication, window: CaptureWindowInfo) {
        captureStates[target.id] = .connecting
        ensureFramePolling()
        Task {
            do {
                let session = try await makeSession(target.id, window)
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
        // One window-list snapshot per cycle instead of one per target:
        // three targets at 4 Hz used to mean 12 full CGWindowList copies a
        // second (M2a fix).
        let existingWindowIDs = sessions.isEmpty ? Set<UInt32>() : currentWindowIDs()
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
            if let windowID = targetWindowIDs[id], !existingWindowIDs.contains(windowID) {
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

    private func currentWindowIDs() -> Set<UInt32> {
        let list = CGWindowListCopyWindowInfo([.optionAll], kCGNullWindowID) as? [[String: Any]] ?? []
        return Set(list.compactMap { ($0[kCGWindowNumber as String] as? NSNumber)?.uint32Value })
    }

    private func describeCaptureError(_ error: Error) -> String {
        (error as? CaptureSessionError)?.description ?? error.localizedDescription
    }

    func openScreenRecordingSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!
        NSWorkspace.shared.open(url)
    }
}
