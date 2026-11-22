import AppKit
import ArgusCore
import Foundation
import SwiftUI

/// Minimal FR-11 surface: current per-target health, stable error codes and
/// a copy-only redacted export. No screenshot, OCR text or window title is
/// displayed or copied.
struct DiagnosticsView: View {
    let store: DashboardStore

    @Environment(\.dismiss) private var dismiss
    @State private var copied = false

    var body: some View {
        let report = store.diagnosticReport()
        VStack(alignment: .leading, spacing: 16) {
            header
            summary(report)
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    targetsSection(report)
                    eventsSection(report)
                }
                .padding(.vertical, 2)
            }
            privacyNote
        }
        .padding(20)
        .frame(width: 680, height: 580)
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Diagnostics")
                    .font(.title2.weight(.semibold))
                Text("Session-only, local, redacted before copying.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                copy()
            } label: {
                Label(copied ? "Copied" : "Copy diagnostics",
                      systemImage: copied ? "checkmark" : "doc.on.doc")
            }
            Button("Done") {
                dismiss()
            }
            .keyboardShortcut(.defaultAction)
        }
    }

    private func summary(_ report: DiagnosticReport) -> some View {
        HStack(spacing: 24) {
            metric("Screen Recording", permissionLabel(report.screenRecording))
            metric("Accessibility", permissionLabel(report.accessibility))
            metric("Targets", "\(report.targets.count)")
            Spacer()
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
    }

    private func targetsSection(_ report: DiagnosticReport) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Targets")
                .font(.headline)
            if report.targets.isEmpty {
                Text("No targets are being monitored.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(report.targets) { target in
                    targetRow(target)
                }
            }
        }
    }

    private func targetRow(_ target: DiagnosticTarget) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("Target \(target.slot)")
                    .font(.headline)
                Text(target.bundleIdentifier.isEmpty ? "(unknown bundle)" : target.bundleIdentifier)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(target.phase.rawValue.uppercased())
                    .font(.system(.caption2, design: .monospaced).weight(.semibold))
                    .foregroundStyle(phaseColor(target.phase))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(phaseColor(target.phase).opacity(0.12),
                                in: Capsule())
            }
            HStack(spacing: 14) {
                Text("capture \(target.captureState.rawValue)")
                if let fps = target.frameRate {
                    Text("\(String(format: "%.1f", fps)) fps")
                }
                if let age = target.frameAgeSeconds {
                    Text("frame age \(String(format: "%.1f", age))s")
                }
                if let latency = target.detectionLatencyMilliseconds {
                    Text("detect \(String(format: "%.0f", latency)) ms")
                }
            }
            .font(.caption.monospacedDigit())
            .foregroundStyle(.secondary)
            if let error = target.lastError {
                Text("\(error.rawValue) · \(error.title)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.orange)
            }
        }
        .padding(11)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 9))
    }

    private func eventsSection(_ report: DiagnosticReport) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Recent events")
                .font(.headline)
            if report.events.isEmpty {
                Text("No state or error events in this session.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(report.events.reversed())) { event in
                    eventRow(event)
                }
            }
        }
    }

    private func eventRow(_ event: DiagnosticEvent) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(event.timestamp, style: .time)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                Text(event.slot == 0 ? "App" : "Target \(event.slot)")
                    .font(.caption.weight(.medium))
                Spacer()
                if let code = event.code {
                    Text(code.rawValue)
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.orange)
                }
            }
            if let from = event.fromPhase, let to = event.toPhase {
                Text("\(from.rawValue) → \(to.rawValue)")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
            } else if let to = event.toPhase {
                Text("→ \(to.rawValue)")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.leading, 10)
    }

    private var privacyNote: some View {
        Text("Copy contains timing, state and stable error codes only. It never includes screenshots, OCR text or window titles.")
            .font(.caption2)
            .foregroundStyle(.secondary)
    }

    private func metric(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased())
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.callout.weight(.medium).monospacedDigit())
        }
    }

    private func permissionLabel(_ state: CapturePermissionState) -> String {
        switch state {
        case .granted:
            return "granted"
        case .denied:
            return "denied"
        case .notDetermined:
            return "not determined"
        }
    }

    private func permissionLabel(_ state: AccessibilityPermissionState) -> String {
        switch state {
        case .granted:
            return "granted"
        case .denied:
            return "denied"
        case .notDetermined:
            return "not determined"
        }
    }

    private func phaseColor(_ phase: ReplyPhase) -> Color {
        switch phase {
        case .idle:
            return .secondary
        case .streaming:
            return .blue
        case .settling:
            return .orange
        case .completed:
            return .green
        case .unknown:
            return .red
        }
    }

    private func copy() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(store.diagnosticText(), forType: .string)
        copied = true
    }
}
