import ArgusCore
import CoreGraphics
import SwiftUI

struct MonitoringCardView: View {
    let target: TargetApplication
    var frameImage: CGImage?
    var captureState: CaptureState?
    var onRemove: (() -> Void)?
    var onReselect: (() -> Void)?
    var onActivate: (() -> Void)?
    var onTogglePause: (() -> Void)?

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
            if case .unresolved = captureState {
                Button("Re-select window…") {
                    onReselect?()
                }
            }
            if case .windowClosed = captureState {
                Button("Re-select window…") {
                    onReselect?()
                }
            }
            if canTogglePause {
                Button(isPaused ? "Resume capture" : "Pause capture") {
                    onTogglePause?()
                }
            }
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
        .contentShape(RoundedRectangle(cornerRadius: 10))
        .onTapGesture {
            onActivate?()
        }
        .help("Bring this window to the front")
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
        .accessibilityLabel("Switch to \(target.displayName) window")
        .accessibilityAddTraits(.isButton)
    }

    private var badgeText: String {
        switch captureState {
        case .live: "LIVE · 2 FPS"
        case .connecting: "CONNECTING…"
        case .failed: "CAPTURE ERROR"
        case .unresolved: "NEEDS WINDOW"
        case .paused: "PAUSED"
        case .windowClosed: "WINDOW CLOSED"
        case nil: "NO SESSION"
        }
    }

    private var badgeTint: Color {
        switch captureState {
        case .failed: .red
        case .unresolved: .orange
        case .windowClosed: .red
        case .paused: .secondary
        default: Color.primary.opacity(0.55)
        }
    }

    private var dotTint: Color {
        switch captureState {
        case .live: .green
        case .connecting: .orange
        case .failed: .red
        case .unresolved: .orange
        case .windowClosed: .red
        case .paused: .gray
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
        } else if case .unresolved(let reason) = captureState {
            Text(reason)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.orange)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else if case .paused = captureState {
            Text("Paused · last frame kept in memory")
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else if case .windowClosed = captureState {
            Text("Waiting for this window to return…")
                .font(.caption2.weight(.medium))
                .foregroundStyle(.orange)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else if frameImage != nil {
            Text("Frames stay in memory · click to switch")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            Text("Click the preview to bring this window forward")
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
            Text(statusLabel)
                .font(.caption.weight(.medium))
                .foregroundStyle(statusTint)
        }
    }

    /// Capture state outranks the (M3) reply phase here: a paused or closed
    /// card must not keep saying "Idle" as if frames were still arriving.
    private var statusLabel: String {
        switch captureState {
        case .paused: "Paused"
        case .windowClosed: "Window closed"
        case .unresolved: "Needs window"
        case .failed: "Capture error"
        case .connecting: "Connecting"
        case .live, nil: target.phase.label
        }
    }

    private var statusTint: Color {
        switch captureState {
        case .paused: .secondary
        case .windowClosed, .failed: .red
        case .unresolved: .orange
        case .connecting: .orange
        case .live, nil: target.phase.tint
        }
    }

    private var statusDetail: String {
        switch captureState {
        case .paused: "No new frames until you resume"
        case .windowClosed: "Waiting for the window to return"
        case .unresolved: "Bind a window to resume capture"
        case .failed: "Capture stopped"
        case .connecting: "Starting the stream"
        case .live, nil: target.phase.detail
        }
    }

    private var isPaused: Bool {
        if case .paused = captureState { return true }
        return false
    }

    private var canTogglePause: Bool {
        switch captureState {
        case .live, .connecting, .paused: true
        default: false
        }
    }

    @ViewBuilder
    private var footer: some View {
        if case .unresolved = captureState {
            Button {
                onReselect?()
            } label: {
                Label("Re-select window…", systemImage: "arrow.triangle.2.circlepath")
                    .font(.caption)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }

        HStack {
            Text(statusDetail)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Spacer()
            if canTogglePause {
                Button {
                    onTogglePause?()
                } label: {
                    Image(systemName: isPaused ? "play.fill" : "pause.fill")
                }
                .buttonStyle(.borderless)
                .help(isPaused ? "Resume capture" : "Pause capture")
            }
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
