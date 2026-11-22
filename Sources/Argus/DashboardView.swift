import ArgusCore
import SwiftUI

struct DashboardView: View {
    @State private var store: DashboardStore
    @State private var showingDiagnostics = false
    /// One clock for all cards. The thumbnail itself updates at 1 fps; the
    /// elapsed footer only needs coarse resolution, so 2 s halves SwiftUI
    /// invalidation cost without affecting the freshness requirement.
    @State private var clock = Date()

    init(store: DashboardStore = DashboardStore(profileForBundle: ReplyProfileRegistry.profileForBundle)) {
        _store = State(initialValue: store)
    }

    private let columns = [
        GridItem(.adaptive(minimum: 300, maximum: 420), spacing: 16)
    ]

    var body: some View {
        @Bindable var store = store
        VStack(alignment: .leading, spacing: 20) {
            header
            statusStrip

            if let notice = store.activationNotice {
                activationBanner(notice)
            }

            ScrollView {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(store.targets) { target in
                        MonitoringCardView(
                            target: target,
                            frameImage: store.latestFrames[target.id],
                            captureState: store.captureStates[target.id],
                            now: clock,
                            onRemove: {
                                store.removeTarget(id: target.id)
                            },
                            onReselect: {
                                store.beginRebind(targetID: target.id)
                            },
                            onActivate: {
                                store.activateTarget(id: target.id)
                            },
                            onTogglePause: {
                                store.togglePause(id: target.id)
                            }
                        )
                    }

                    if store.targets.isEmpty {
                        emptyHint
                    }
                }
                .padding(.vertical, 4)
            }

            footer
        }
        .padding(24)
        .frame(minWidth: 600, minHeight: 600)
        .background(Color(nsColor: .windowBackgroundColor))
        .sheet(isPresented: $store.isShowingPicker, onDismiss: store.pickerDidDismiss) {
            WindowPickerSheet(store: store)
        }
        .task {
            await store.refreshPermission()
            await store.refreshAccessibility()
            await store.restorePersistedTargets()
        }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                guard !Task.isCancelled else { return }
                clock = Date()
            }
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 6) {
                Text("ARGUS")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .tracking(2)
                Text("Multi-target AI reply monitor")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if store.accessibilityState != .granted {
                Button {
                    Task { await store.requestAccessibility() }
                } label: {
                    Label("Enable exact switching", systemImage: "hand.raised")
                }
                .controlSize(.small)
                .help("Accessibility permission lets Argus raise the exact window instead of only bringing the app forward.")
            }

            Button {
                store.openPicker()
            } label: {
                Label("Add target", systemImage: "plus")
            }
            .disabled(!store.canAddTarget)
            .help(store.canAddTarget
                  ? "Pick an on-screen window to monitor"
                  : "Target limit reached (\(ArgusCore.TargetLimits.maximumMonitoredTargets)). Remove a card to add another.")
        }
    }

    private var statusStrip: some View {
        ViewThatFits(in: .horizontal) {
            statusStripContent(showsHint: true)
            statusStripContent(showsHint: false)
        }
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private func statusStripContent(showsHint: Bool) -> some View {
        HStack(spacing: 18) {
            metric("Targets", value: "\(store.targets.count)/\(TargetLimits.maximumMonitoredTargets)")
            metric("Paused", value: "\(store.pausedTargetIDs.count)")
            metric("Completed", value: "\(store.targets.filter { $0.phase == .completed }.count)")
            metric("Streaming", value: "\(store.targets.filter { $0.phase == .streaming }.count)")
            Spacer(minLength: 12)
            if showsHint {
                Text("M4: frame diff + OCR · diagnostics local-only")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }

    private func activationBanner(_ notice: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: "info.circle")
                .foregroundStyle(.secondary)
            Text(notice)
                .font(.callout)
            Spacer()
            Button("Dismiss") {
                store.clearActivationNotice()
            }
            .buttonStyle(.plain)
            .font(.caption)
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
    }

    private var emptyHint: some View {
        VStack(spacing: 8) {
            Image(systemName: "plus.viewfinder")
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(.secondary)
            Text("No targets yet")
                .font(.headline)
            Text("Use “Add target” to pick a window and start live capture.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.vertical, 48)
    }

    private func metric(_ label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased())
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.weight(.semibold).monospacedDigit())
        }
    }

    private var footer: some View {
        HStack {
            Text("Local-first · no cloud upload · macOS 14+")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Button {
                showingDiagnostics = true
            } label: {
                Label("Diagnostics", systemImage: "stethoscope")
            }
            .buttonStyle(.plain)
            .font(.caption)
            .sheet(isPresented: $showingDiagnostics) {
                DiagnosticsView(store: store)
            }
            Text("P-01 / Tier 2")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    DashboardView(store: DashboardStore(initialTargets: ArgusPreviewData.targets))
}
