import ArgusCore
import SwiftUI

struct MonitoringCardView: View {
    let target: TargetApplication

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            thumbnail
            titleRow
            Text(target.windowTitle)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            footer
        }
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(.white.opacity(0.08), lineWidth: 1)
        }
    }

    private var thumbnail: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(
                    LinearGradient(
                        colors: [Color.black.opacity(0.32), Color.black.opacity(0.12)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Image(systemName: "macwindow")
                .font(.system(size: 26, weight: .light))
                .foregroundStyle(.secondary)

            VStack {
                HStack {
                    Text("LIVE PREVIEW")
                        .font(.caption2.weight(.bold))
                        .tracking(1)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Circle()
                        .fill(target.phase.tint)
                        .frame(width: 7, height: 7)
                }
                Spacer()
                Text("Click thumbnail to switch in M2")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(10)
        }
        .frame(height: 150)
        .accessibilityLabel("\(target.displayName) live preview")
    }

    private var titleRow: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(target.displayName)
                .font(.headline)
            Spacer()
            Text(target.phase.label)
                .font(.caption.weight(.medium))
                .foregroundStyle(target.phase.tint)
        }
    }

    private var footer: some View {
        HStack {
            Text(target.phase.detail)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Spacer()
            if let lastFrameAt = target.lastFrameAt {
                Text(lastFrameAt, style: .relative)
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private extension ReplyPhase {
    var label: String {
        switch self {
        case .idle: "Idle"
        case .streaming: "Streaming"
        case .settling: "Settling"
        case .completed: "Completed"
        case .unknown: "Unknown"
        }
    }

    var detail: String {
        switch self {
        case .idle: "No visible generation yet"
        case .streaming: "Text is still changing"
        case .settling: "Waiting for a stable frame"
        case .completed: "Reply appears complete"
        case .unknown: "Signal unavailable"
        }
    }

    var tint: Color {
        switch self {
        case .idle: .secondary
        case .streaming: .blue
        case .settling: .orange
        case .completed: .green
        case .unknown: .gray
        }
    }
}
