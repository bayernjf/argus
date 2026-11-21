import AppKit
import ApplicationServices
import ArgusCore

/// AX-backed window activation (docs/02 §5, ADR-012).
///
/// Match first, activate second: when the card's window cannot be identified
/// uniquely, no app is brought forward, so a failed click never lands the
/// user in a different conversation.
@MainActor
final class AccessibilityWindowActivator: WindowActivating {
    func activate(_ target: TargetApplication) throws -> WindowActivationOutcome {
        guard let running = NSWorkspace.shared.runningApplications.first(where: {
            $0.bundleIdentifier == target.bundleIdentifier
        }) else {
            throw WindowActivationError.targetNotRunning
        }

        guard AXIsProcessTrusted() else {
            bringApplicationForward(running)
            return .applicationOnly(.accessibilityNotGranted)
        }

        let appElement = AXUIElementCreateApplication(running.processIdentifier)
        let windows = copyWindows(of: appElement)
        let titles = windows.map(windowTitle(of:))

        switch WindowMatchPolicy.match(targetTitle: target.windowTitle, candidateTitles: titles) {
        case .unique(let index):
            guard windows.indices.contains(index) else {
                throw WindowActivationError.windowNotFound
            }
            bringApplicationForward(running)
            raise(windows[index])
            return .exactWindow
        case .ambiguous(let count):
            throw WindowActivationError.ambiguousWindows(count: count)
        case .none:
            throw WindowActivationError.windowNotFound
        }
    }

    private func copyWindows(of app: AXUIElement) -> [AXUIElement] {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(app, kAXWindowsAttribute as CFString, &value) == .success,
              let windows = value as? [AXUIElement]
        else { return [] }
        return windows
    }

    private func windowTitle(of window: AXUIElement) -> String {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(window, kAXTitleAttribute as CFString, &value) == .success,
              let title = value as? String
        else { return "" }
        return title
    }

    private func raise(_ window: AXUIElement) {
        AXUIElementSetAttributeValue(window, kAXMinimizedAttribute as CFString, kCFBooleanFalse)
        AXUIElementPerformAction(window, kAXRaiseAction as CFString)
        AXUIElementSetAttributeValue(window, kAXMainAttribute as CFString, kCFBooleanTrue)
        AXUIElementSetAttributeValue(window, kAXFocusedAttribute as CFString, kCFBooleanTrue)
    }

    private func bringApplicationForward(_ app: NSRunningApplication) {
        if app.isHidden {
            app.unhide()
        }
        app.activate(options: [])
    }
}
