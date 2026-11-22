import Foundation

/// Stable diagnostic codes. Keep the raw values stable so a copied report
/// can be matched against docs and issue reports without guessing.
public enum DiagnosticErrorCode: String, Codable, Sendable, CaseIterable {
    case noFrames = "D01_NO_FRAMES"
    case permissionDenied = "D02_PERMISSION"
    case detectionUnknown = "D03_UNKNOWN"
    case activationFailed = "D04_ACTIVATION"
    case captureFailed = "D05_CAPTURE"
    case windowUnresolved = "D06_UNRESOLVED"
    case screenRecordingDenied = "D07_SCREEN_RECORDING"
    case accessibilityDenied = "D08_ACCESSIBILITY"

    public var title: String {
        switch self {
        case .noFrames:
            return "No frames arriving"
        case .permissionDenied:
            return "Permission missing"
        case .detectionUnknown:
            return "Detection returned unknown"
        case .activationFailed:
            return "Window activation failed"
        case .captureFailed:
            return "Capture session failed"
        case .windowUnresolved:
            return "Window could not be resolved"
        case .screenRecordingDenied:
            return "Screen Recording is not granted"
        case .accessibilityDenied:
            return "Accessibility is not granted"
        }
    }
}

/// Capture lifecycle as diagnostics sees it. Deliberately has no associated
/// message: capture errors can contain window titles and must not leak into
/// a copied report.
public enum DiagnosticCaptureState: String, Codable, Sendable, CaseIterable {
    case connecting
    case live
    case paused
    case windowClosed
    case failed
    case unresolved
}

public enum DiagnosticEventKind: String, Codable, Sendable, CaseIterable {
    case phaseTransition
    case error
}

/// One target row in a diagnostics report. There is intentionally no window
/// title or free-form error message here; only the app identity, phase and
/// stable codes are exportable.
public struct DiagnosticTarget: Identifiable, Equatable, Sendable {
    public var id: Int { slot }
    public let slot: Int
    public let bundleIdentifier: String
    public let phase: ReplyPhase
    public let captureState: DiagnosticCaptureState
    public let frameAgeSeconds: Double?
    public let frameRate: Double?
    public let detectionLatencyMilliseconds: Double?
    public let lastError: DiagnosticErrorCode?

    public init(
        slot: Int,
        bundleIdentifier: String,
        phase: ReplyPhase,
        captureState: DiagnosticCaptureState,
        frameAgeSeconds: Double? = nil,
        frameRate: Double? = nil,
        detectionLatencyMilliseconds: Double? = nil,
        lastError: DiagnosticErrorCode? = nil
    ) {
        self.slot = slot
        self.bundleIdentifier = bundleIdentifier
        self.phase = phase
        self.captureState = captureState
        self.frameAgeSeconds = frameAgeSeconds
        self.frameRate = frameRate
        self.detectionLatencyMilliseconds = detectionLatencyMilliseconds
        self.lastError = lastError
    }
}

/// A bounded, timestamped event. `slot` refers to the target's position in
/// the report, not its internal UUID; removing a target can renumber later
/// events, but the timestamp and code remain useful for diagnosis.
public struct DiagnosticEvent: Identifiable, Equatable, Sendable {
    public var id: Int { sequence }
    public let sequence: Int
    public let timestamp: Date
    public let slot: Int
    public let kind: DiagnosticEventKind
    public let code: DiagnosticErrorCode?
    public let fromPhase: ReplyPhase?
    public let toPhase: ReplyPhase?

    public init(
        sequence: Int,
        timestamp: Date,
        slot: Int,
        kind: DiagnosticEventKind,
        code: DiagnosticErrorCode? = nil,
        fromPhase: ReplyPhase? = nil,
        toPhase: ReplyPhase? = nil
    ) {
        self.sequence = sequence
        self.timestamp = timestamp
        self.slot = slot
        self.kind = kind
        self.code = code
        self.fromPhase = fromPhase
        self.toPhase = toPhase
    }
}

/// Local-only diagnostics snapshot. `redactedText()` is the only export
/// path; it never serializes pixels, OCR text or window titles.
public struct DiagnosticReport: Equatable, Sendable {
    public let generatedAt: Date
    public let appVersion: String
    public let osVersion: String
    public let screenRecording: CapturePermissionState
    public let accessibility: AccessibilityPermissionState
    public let targets: [DiagnosticTarget]
    public let events: [DiagnosticEvent]

    public init(
        generatedAt: Date,
        appVersion: String,
        osVersion: String,
        screenRecording: CapturePermissionState,
        accessibility: AccessibilityPermissionState,
        targets: [DiagnosticTarget],
        events: [DiagnosticEvent]
    ) {
        self.generatedAt = generatedAt
        self.appVersion = appVersion
        self.osVersion = osVersion
        self.screenRecording = screenRecording
        self.accessibility = accessibility
        self.targets = targets
        self.events = events
    }

    /// Plain text, safe to paste into an issue. It contains app identity,
    /// state, timings and stable codes only. No screenshots, OCR text or
    /// window titles are present by construction.
    public func redactedText() -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        var lines: [String] = [
            "Argus diagnostics",
            "Generated: \(formatter.string(from: generatedAt))",
            "Version: \(appVersion)",
            "macOS: \(osVersion)",
            "Screen Recording: \(Self.label(for: screenRecording))",
            "Accessibility: \(Self.label(for: accessibility))",
            "",
            "Targets:"
        ]

        if targets.isEmpty {
            lines.append("- none")
        } else {
            for target in targets {
                var fields = [
                    "Target \(target.slot)",
                    target.bundleIdentifier.isEmpty ? "(unknown bundle)" : target.bundleIdentifier,
                    "phase=\(target.phase.rawValue)",
                    "capture=\(target.captureState.rawValue)"
                ]
                if let frameRate = target.frameRate {
                    fields.append(String(format: "fps=%.1f", frameRate))
                }
                if let frameAge = target.frameAgeSeconds {
                    fields.append(String(format: "frameAge=%.1fs", frameAge))
                }
                if let latency = target.detectionLatencyMilliseconds {
                    fields.append(String(format: "detect=%.0fms", latency))
                }
                if let error = target.lastError {
                    fields.append("lastError=\(error.rawValue)")
                }
                lines.append("- " + fields.joined(separator: " | "))
            }
        }

        lines.append("")
        lines.append("Recent events:")
        if events.isEmpty {
            lines.append("- none")
        } else {
            for event in events {
                var fields = [
                    formatter.string(from: event.timestamp),
                    event.slot == 0 ? "App" : "Target \(event.slot)"
                ]
                if let code = event.code {
                    fields.append(code.rawValue)
                }
                if let from = event.fromPhase, let to = event.toPhase {
                    fields.append("\(from.rawValue)->\(to.rawValue)")
                } else if let to = event.toPhase {
                    fields.append("->\(to.rawValue)")
                }
                lines.append("- " + fields.joined(separator: " | "))
            }
        }

        lines.append("")
        lines.append("Privacy: no screenshots, OCR text or window titles are included.")
        return lines.joined(separator: "\n")
    }

    private static func label(for state: CapturePermissionState) -> String {
        switch state {
        case .granted:
            return "granted"
        case .denied:
            return "denied"
        case .notDetermined:
            return "not determined"
        }
    }

    private static func label(for state: AccessibilityPermissionState) -> String {
        switch state {
        case .granted:
            return "granted"
        case .denied:
            return "denied"
        case .notDetermined:
            return "not determined"
        }
    }
}
