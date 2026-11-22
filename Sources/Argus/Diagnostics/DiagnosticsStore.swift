import ArgusCore
import Foundation
import Observation

/// In-memory diagnostics for the current app session. Nothing here is
/// persisted or sent over the network. Frame timestamps are used only to
/// estimate FPS; images and OCR text never enter this store.
@MainActor
@Observable
final class DiagnosticsStore {
    private struct TargetMetrics {
        var lastCapturedAt: Date?
        var frameTimes: [Date] = []
        var lastDetectionLatencySeconds: TimeInterval?
        var lastError: DiagnosticErrorCode?
        var lastErrorAt: Date?
    }

    private(set) var events: [DiagnosticEvent] = []
    private var metrics: [UUID: TargetMetrics] = [:]
    private var nextEventSequence = 0
    private var lastPermissionSignature: String?
    private let maxEvents = 40
    private let errorCooldown: TimeInterval = 10

    func recordFrame(targetID: UUID, capturedAt: Date) {
        var metric = metrics[targetID, default: TargetMetrics()]
        guard metric.lastCapturedAt != capturedAt else { return }
        metric.lastCapturedAt = capturedAt
        metric.frameTimes.append(capturedAt)
        metric.frameTimes.removeAll { capturedAt.timeIntervalSince($0) > 3 }
        metrics[targetID] = metric
    }

    func recordAnalysis(targetID: UUID, latency: TimeInterval) {
        var metric = metrics[targetID, default: TargetMetrics()]
        metric.lastDetectionLatencySeconds = max(0, latency)
        metrics[targetID] = metric
    }

    func recordError(
        _ code: DiagnosticErrorCode,
        targetID: UUID,
        slot: Int,
        at date: Date = Date()
    ) {
        var metric = metrics[targetID, default: TargetMetrics()]
        if metric.lastError == code,
           let lastErrorAt = metric.lastErrorAt,
           date.timeIntervalSince(lastErrorAt) < errorCooldown {
            return
        }
        metric.lastError = code
        metric.lastErrorAt = date
        metrics[targetID] = metric
        appendEvent(slot: slot, kind: .error, code: code, at: date)
    }

    func recordTransition(
        targetID: UUID,
        slot: Int,
        from: ReplyPhase,
        to: ReplyPhase,
        at date: Date
    ) {
        guard from != to else { return }
        appendEvent(
            slot: slot,
            kind: .phaseTransition,
            fromPhase: from,
            toPhase: to,
            at: date
        )
    }

    /// Permission changes are global, not target-specific. `slot: 0` marks
    /// an app-level event in the report.
    func recordPermission(
        screen: CapturePermissionState,
        accessibility: AccessibilityPermissionState,
        at date: Date = Date()
    ) {
        let signature = "\(permissionLabel(screen))/\(permissionLabel(accessibility))"
        guard signature != lastPermissionSignature else { return }
        lastPermissionSignature = signature

        if screen == .denied {
            appendEvent(slot: 0, kind: .error, code: .screenRecordingDenied, at: date)
        }
        if accessibility == .denied {
            appendEvent(slot: 0, kind: .error, code: .accessibilityDenied, at: date)
        }
    }

    func forget(targetID: UUID) {
        metrics.removeValue(forKey: targetID)
    }

    func frameRate(for targetID: UUID, at date: Date = Date()) -> Double? {
        guard let times = metrics[targetID]?.frameTimes.filter({
            date.timeIntervalSince($0) <= 3
        }), times.count >= 3,
        let first = times.first,
        let last = times.last,
        last > first
        else { return nil }
        return Double(times.count - 1) / last.timeIntervalSince(first)
    }

    func makeReport(
        targets: [TargetApplication],
        captureStates: [UUID: CaptureState],
        screenRecording: CapturePermissionState,
        accessibility: AccessibilityPermissionState,
        appVersion: String,
        osVersion: String,
        now: Date = Date()
    ) -> DiagnosticReport {
        let targetRows = targets.enumerated().map { index, target in
            let capture = diagnosticCaptureState(captureStates[target.id])
            var lastError = metrics[target.id]?.lastError
            if lastError == nil {
                switch capture {
                case .failed:
                    lastError = .captureFailed
                case .unresolved:
                    lastError = .windowUnresolved
                default:
                    break
                }
            }
            let frameAge = target.lastFrameAt.map {
                max(0, now.timeIntervalSince($0))
            }
            let latency = metrics[target.id]?.lastDetectionLatencySeconds
            return DiagnosticTarget(
                slot: index + 1,
                bundleIdentifier: target.bundleIdentifier,
                phase: target.phase,
                captureState: capture,
                frameAgeSeconds: frameAge,
                frameRate: frameRate(for: target.id, at: now),
                detectionLatencyMilliseconds: latency.map { $0 * 1_000 },
                lastError: lastError
            )
        }

        return DiagnosticReport(
            generatedAt: now,
            appVersion: appVersion,
            osVersion: osVersion,
            screenRecording: screenRecording,
            accessibility: accessibility,
            targets: targetRows,
            events: events
        )
    }

    private func appendEvent(
        slot: Int,
        kind: DiagnosticEventKind,
        code: DiagnosticErrorCode? = nil,
        fromPhase: ReplyPhase? = nil,
        toPhase: ReplyPhase? = nil,
        at date: Date
    ) {
        let event = DiagnosticEvent(
            sequence: nextEventSequence,
            timestamp: date,
            slot: slot,
            kind: kind,
            code: code,
            fromPhase: fromPhase,
            toPhase: toPhase
        )
        nextEventSequence += 1
        events.append(event)
        if events.count > maxEvents {
            events.removeFirst(events.count - maxEvents)
        }
    }

    private func permissionLabel(_ state: CapturePermissionState) -> String {
        switch state {
        case .granted:
            return "granted"
        case .denied:
            return "denied"
        case .notDetermined:
            return "notDetermined"
        }
    }

    private func permissionLabel(_ state: AccessibilityPermissionState) -> String {
        switch state {
        case .granted:
            return "granted"
        case .denied:
            return "denied"
        case .notDetermined:
            return "notDetermined"
        }
    }

    private func diagnosticCaptureState(_ state: CaptureState?) -> DiagnosticCaptureState {
        switch state {
        case .connecting:
            return .connecting
        case .live:
            return .live
        case .paused:
            return .paused
        case .windowClosed:
            return .windowClosed
        case .failed:
            return .failed
        case .unresolved:
            return .unresolved
        case .none:
            return .unresolved
        }
    }
}
