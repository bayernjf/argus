import ArgusCore
import Foundation

/// Mock data for the M0 UI skeleton. It is not a claim that these apps are
/// supported yet; the first supported target list is an open product decision.
enum ArgusPreviewData {
    static let targets: [TargetApplication] = [
        TargetApplication(
            displayName: "ChatGPT",
            bundleIdentifier: "com.argus.preview.chatgpt",
            windowTitle: "Drafting a migration plan",
            phase: .streaming,
            lastFrameAt: Date(timeIntervalSinceNow: -2)
        ),
        TargetApplication(
            displayName: "Claude",
            bundleIdentifier: "com.argus.preview.claude",
            windowTitle: "Reviewing a release checklist",
            phase: .settling,
            lastFrameAt: Date(timeIntervalSinceNow: -4)
        ),
        TargetApplication(
            displayName: "Cursor",
            bundleIdentifier: "com.argus.preview.cursor",
            windowTitle: "Explaining a failing test",
            phase: .completed,
            lastFrameAt: Date(timeIntervalSinceNow: -8)
        )
    ]
}
