import CoreGraphics
import Foundation

/// One capturable window candidate produced by `SCShareableContent`
/// enumeration. ArgusCore keeps the pure shape so filtering and target
/// mapping stay unit-testable; the ScreenCaptureKit mapping lives in the
/// Argus target (docs/02 §目标解析).
public struct CaptureWindowInfo: Identifiable, Hashable, Sendable {
    /// `SCWindow.windowID`; stable for the lifetime of the window.
    public let id: UInt32
    public var appName: String
    public var appBundleIdentifier: String
    public var windowTitle: String
    public var frame: CGRect
    /// Owning process, when known. Accessibility probing uses it to inspect
    /// only the process that owns the picked window, never a sibling instance.
    public var processID: Int32?

    public init(
        id: UInt32,
        appName: String,
        appBundleIdentifier: String,
        windowTitle: String,
        frame: CGRect,
        processID: Int32? = nil
    ) {
        self.id = id
        self.appName = appName
        self.appBundleIdentifier = appBundleIdentifier
        self.windowTitle = windowTitle
        self.frame = frame
        self.processID = processID
    }
}

public extension CaptureWindowInfo {
    /// Minimum plausible chat-surface size. Menu-bar stubs, 1px helper
    /// windows and overlay panels never make useful targets.
    static let minimumContentSize: CGFloat = 120

    /// M1 visibility rules from docs/02 §目标解析: drop Argus's own windows
    /// and anything too small to carry a monitored reply surface.
    static func validTargets(
        from windows: [CaptureWindowInfo],
        ownBundleIdentifier: String
    ) -> [CaptureWindowInfo] {
        windows.filter { window in
            window.appBundleIdentifier != ownBundleIdentifier
                && window.frame.width >= minimumContentSize
                && window.frame.height >= minimumContentSize
        }
    }

    /// The dashboard card this window becomes when the user picks it.
    /// `id` lets a restored or re-selected target keep its card identity.
    func makeTarget(id: UUID = UUID()) -> TargetApplication {
        TargetApplication(
            id: id,
            displayName: appName,
            bundleIdentifier: appBundleIdentifier,
            windowTitle: windowTitle,
            note: "window #\(self.id)"
        )
    }

    /// Drops windows that are already monitored so the picker can neither
    /// list nor re-add a live target.
    static func excludingMonitored(
        _ windows: [CaptureWindowInfo],
        monitoredWindowIDs: Set<UInt32>
    ) -> [CaptureWindowInfo] {
        windows.filter { !monitoredWindowIDs.contains($0.id) }
    }
}
