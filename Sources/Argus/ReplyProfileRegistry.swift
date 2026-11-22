import ArgusCore

/// Bundle-keyed reply profiles. Unknown applications keep the conservative
/// generic profile so a missing calibration can never change detection.
enum ReplyProfileRegistry {
    /// The reply region is the answer body only: it starts below the user's
    /// prompt bubble so a newly sent prompt does not look like assistant text
    /// growth. The leftrail and bottom composer stay excluded.
    static let doubaoWork = ReplyProfile(
        id: "doubao-work",
        bundleIdentifier: "com.work.pc.doubao",
        replyROI: NormalizedRect(x: 0.17, y: 0.20, width: 0.80, height: 0.66),
        controlROI: NormalizedRect(x: 0.88, y: 0.90, width: 0.07, height: 0.07),
        settleDuration: 1.0,
        ocrInterval: 0.5,
        changeThreshold: 0.005,
        stopKeywords: [
            "stop", "stop generating", "cancel", "generating", "thinking",
            "停止", "停止生成", "取消", "正在生成", "思考中",
        ],
        minConfidence: 0.6,
        answerTextBelowPrompt: true
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
