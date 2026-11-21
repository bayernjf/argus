import ArgusCore
import SwiftUI

struct DashboardView: View {
    @State private var targets = ArgusPreviewData.targets

    private let columns = [
        GridItem(.adaptive(minimum: 300, maximum: 420), spacing: 16)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            header
            statusStrip

            ScrollView {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(targets) { target in
                        MonitoringCardView(target: target)
                    }
                }
                .padding(.vertical, 4)
            }

            footer
        }
        .padding(24)
        .frame(minWidth: 900, minHeight: 600)
        .background(Color(nsColor: .windowBackgroundColor))
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
                // Target picker lands in M1.
            } label: {
                Label("Add target", systemImage: "plus")
            }
            .disabled(true)
            .help("Window picker lands in M1")
        }
    }

    private var statusStrip: some View {
        HStack(spacing: 18) {
            metric("Targets", value: "\(targets.count)")
            metric("Completed", value: "\(targets.filter { $0.phase == .completed }.count)")
            metric("Streaming", value: "\(targets.filter { $0.phase == .streaming }.count)")
            Spacer()
            Text("M0 skeleton · capture and activation are not wired yet")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
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
    DashboardView()
}
