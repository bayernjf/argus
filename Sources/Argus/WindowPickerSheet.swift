import ArgusCore
import SwiftUI

/// M1b window picker: guidance + System Settings jump when Screen Recording
/// is not granted, otherwise the eligible window list (FR-01 / FR-09).
struct WindowPickerSheet: View {
    let store: DashboardStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Choose a window to monitor")
                    .font(.headline)
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            switch store.permissionState {
            case .granted:
                windowList
            case .denied, .notDetermined:
                permissionGate
            }
        }
        .padding(20)
        .frame(width: 480, height: 520)
    }

    // MARK: Permission gate

    private var permissionGate: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: "eye.slash")
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(.secondary)
            Text("Screen Recording permission is needed")
                .font(.title3.weight(.semibold))
            Text("""
Argus reads the pixels of the windows you explicitly pick, locally, to detect reply status. Nothing is uploaded or written to disk. Grant Screen Recording to Argus in System Settings, then come back and retry.
""")
            .font(.callout)
            .foregroundStyle(.secondary)

            if store.permissionState == .denied {
                Label("Permission is currently denied for Argus.", systemImage: "exclamationmark.triangle")
                    .font(.callout)
                    .foregroundStyle(.orange)
            }

            Spacer()

            HStack {
                Button("Open System Settings") {
                    store.openScreenRecordingSettings()
                }
                Button("Retry") {
                    Task { await store.retryAccess() }
                }
                .keyboardShortcut(.defaultAction)
                Spacer()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    // MARK: Window list

    private var windowList: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("On-screen windows")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    Task { await store.enumerateWindows() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(store.isEnumerating)
                .help("Refresh window list")
            }

            if let error = store.enumerationError {
                Label("Window enumeration failed: \(error)", systemImage: "exclamationmark.triangle")
                    .font(.callout)
                    .foregroundStyle(.orange)
            }

            if store.isEnumerating {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text("Enumerating windows…")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 40)
            } else if store.availableWindows.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "rectangle.dashed")
                        .font(.system(size: 24, weight: .light))
                        .foregroundStyle(.secondary)
                    Text("No eligible on-screen windows")
                        .foregroundStyle(.secondary)
                    Text("Open the target app and make sure its window is on screen, then refresh.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 40)
            } else {
                List(store.availableWindows) { window in
                    Button {
                        store.addTarget(window)
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "macwindow")
                                .foregroundStyle(.secondary)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(window.appName)
                                    .font(.body.weight(.medium))
                                Text(window.windowTitle.isEmpty ? "(no title)" : window.windowTitle)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            Spacer()
                            Text("\(Int(window.frame.width)) × \(Int(window.frame.height))")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                .listStyle(.inset)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
