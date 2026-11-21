import ArgusCore
import CoreGraphics
import ScreenCaptureKit

/// Maps `SCShareableContent` onto the pure `CaptureWindowInfo` model and
/// applies the docs/02 §目标解析 visibility rules (layer 0, drop Argus's own
/// windows and unusable sizes). Enumeration itself requires the Screen
/// Recording grant; the store only calls this after permission is granted.
enum WindowEnumerator {
    static let ownBundleIdentifier = Bundle.main.bundleIdentifier ?? "com.bayernjf.argus"

    static func enumerateWindows() async throws -> [CaptureWindowInfo] {
        let content = try await SCShareableContent.excludingDesktopWindows(true, onScreenWindowsOnly: true)
        let candidates = content.windows.compactMap { scWindow -> CaptureWindowInfo? in
            guard scWindow.windowLayer == 0, let app = scWindow.owningApplication else { return nil }
            return CaptureWindowInfo(
                id: scWindow.windowID,
                appName: app.applicationName,
                appBundleIdentifier: app.bundleIdentifier,
                windowTitle: scWindow.title ?? "",
                frame: scWindow.frame,
                processID: Int32(app.processID)
            )
        }
        return CaptureWindowInfo.validTargets(from: candidates, ownBundleIdentifier: ownBundleIdentifier)
    }
}
