import ArgusCore
import SwiftUI

struct DashboardView: View {
    @State private var store: DashboardStore

    init(store: DashboardStore = DashboardStore()) {
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

            ScrollView {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(store.targets) { target in
                        MonitoringCardView(
                            target: target,
                            frameImage: store.latestFrames[target.id],
                            captureState: store.captureStates[target.id],
                            onRemove: {
                                store.removeTarget(id: target.id)
                            },
                            onReselect: {
                                store.beginRebind(targetID: target.id)
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
        .frame(minWidth: 900, minHeight: 600)
        .background(Color(nsColor: .windowBackgroundColor))
        .sheet(isPresented: $store.isShowingPicker, onDismiss: store.pickerDidDismiss) {
            WindowPickerSheet(store: store)
        }
        .task {
            await store.refreshPermission()
            await store.restorePersistedTargets()
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
        HStack(spacing: 18) {
            metric("Targets", value: "\(store.targets.count)/\(TargetLimits.maximumMonitoredTargets)")
            metric("Completed", value: "\(store.targets.filter { $0.phase == .completed }.count)")
            metric("Streaming", value: "\(store.targets.filter { $0.phase == .streaming }.count)")
            Spacer()
            Text("M2a: persisted targets · click-to-switch lands in M2b")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
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
            Text("P-01 / Tier 2")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    DashboardView(store: DashboardStore(initialTargets: ArgusPreviewData.targets))
}
