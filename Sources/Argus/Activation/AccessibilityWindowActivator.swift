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
    private struct Candidate {
        let app: NSRunningApplication
        let window: AXUIElement
        let title: String
    }

    func activate(_ target: TargetApplication) throws -> WindowActivationOutcome {
        let running = NSWorkspace.shared.runningApplications.filter {
            $0.bundleIdentifier == target.bundleIdentifier && !$0.isTerminated
        }
        guard let fallbackApp = running.first else {
            throw WindowActivationError.targetNotRunning
        }

        guard AXIsProcessTrusted() else {
            bringApplicationForward(fallbackApp)
            return .applicationOnly(.accessibilityNotGranted)
        }

        // One bundle can have several live processes (e.g. `open -n`). Collect
        // windows across all of them: activating only the first process could
        // raise a window from an instance the target was never bound to.
        let candidates = running.flatMap { app -> [Candidate] in
            let element = AXUIElementCreateApplication(app.processIdentifier)
            return copyWindows(of: element).map { window in
                Candidate(app: app, window: window, title: windowTitle(of: window))
            }
        }
        let titles = candidates.map(\.title)

        switch WindowMatchPolicy.match(targetTitle: target.windowTitle, candidateTitles: titles) {
        case .unique(let index):
            guard candidates.indices.contains(index) else {
                throw WindowActivationError.windowNotFound
            }
            let candidate = candidates[index]
            bringApplicationForward(candidate.app)
            raise(candidate.window)
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
