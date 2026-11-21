import ArgusCore
import CoreGraphics
import SwiftUI

struct MonitoringCardView: View {
    let target: TargetApplication
    var frameImage: CGImage?
    var captureState: CaptureState?
    var onRemove: (() -> Void)?

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
        .contextMenu {
            Button("Remove target", role: .destructive) {
                onRemove?()
            }
        }
    }

    @ViewBuilder
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

            if let frameImage {
                // scaledToFit, not Fill: a monitoring thumbnail must show the
                // whole window; center-cropping hid the reply area entirely.
                Image(decorative: frameImage, scale: 2.0, orientation: .up)
                    .resizable()
                    .scaledToFit()
            } else {
                Image(systemName: "macwindow")
                    .font(.system(size: 26, weight: .light))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(height: 150)
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(alignment: .top) {
            HStack {
                Text(badgeText)
                    .font(.caption2.weight(.bold))
                    .tracking(1)
                    .foregroundStyle(badgeTint)
                Spacer()
                Circle()
                    .fill(dotTint)
                    .frame(width: 7, height: 7)
            }
            .padding(.horizontal, 10)
            .padding(.top, 6)
        }
        .overlay(alignment: .bottom) {
            HStack {
                bottomCaption
            }
            .padding(.horizontal, 10)
            .padding(.bottom, 6)
        }
        .accessibilityLabel("\(target.displayName) preview")
    }

    private var badgeText: String {
        switch captureState {
        case .live: "LIVE · 2 FPS"
        case .connecting: "CONNECTING…"
        case .failed: "CAPTURE ERROR"
        case nil: "CAPTURE PENDING · M1C"
        }
    }

    private var badgeTint: Color {
        switch captureState {
        case .failed: .red
        default: Color.primary.opacity(0.55)
        }
    }

    private var dotTint: Color {
        switch captureState {
        case .live: .green
        case .connecting: .orange
        case .failed: .red
        case nil: target.phase.tint
        }
    }

    @ViewBuilder
    private var bottomCaption: some View {
        if case .failed(let reason) = captureState {
            Text(reason)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.orange)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else if frameImage != nil {
            Text("Frames stay in memory · nothing on disk")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            Text("Click thumbnail to switch in M2")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
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
