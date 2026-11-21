import ArgusCore

/// Bundle-keyed reply profiles. Unknown applications keep the conservative
/// generic profile so a missing calibration can never change detection.
enum ReplyProfileRegistry {
    /// The Doubao Work chat surface is a Chromium web view. The reply region
    /// excludes the left conversation rail and the bottom composer, and the
    /// control region is the right edge of the composer where the Stop control
    /// appears. Accessibility is intentionally still left to the probe; this
    /// profile only narrows vision/OCR inputs.
    static let doubaoWork = ReplyProfile(
        id: "doubao-work",
        bundleIdentifier: "com.work.pc.doubao",
        replyROI: NormalizedRect(x: 0.17, y: 0.08, width: 0.80, height: 0.78),
        controlROI: NormalizedRect(x: 0.88, y: 0.90, width: 0.07, height: 0.07),
        settleDuration: 1.0,
        ocrInterval: 0.5,
        changeThreshold: 0.005,
        stopKeywords: [
            "stop", "stop generating", "cancel", "generating", "thinking",
            "停止", "停止生成", "取消", "正在生成", "思考中",
        ],
        minConfidence: 0.6
    )

    static let profileForBundle: @Sendable (String) -> ReplyProfile = { bundleIdentifier in
        switch bundleIdentifier {
        case "com.work.pc.doubao":
            doubaoWork
        default:
            .generic
        }
    }
}
