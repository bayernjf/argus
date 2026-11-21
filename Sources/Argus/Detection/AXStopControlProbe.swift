import ApplicationServices
import ArgusCore
import Foundation

/// Optional Accessibility signal: does the bound window expose an enabled
/// Stop-like button right now?
///
/// The probe only inspects the process that owns the captured window and
/// matches that window by its exact title first. Duplicate titles return
/// `nil` (unmeasured) instead of reading an unrelated conversation. No text is
/// retained after the boolean is returned.
enum AXStopControlProbe {
    private static let maxNodes = 600
    private static let maxDepth = 8
    private static let stopKeywords = [
        "stop", "stop generating", "stop response", "停止", "停止生成",
    ]

    /// `true` = visible enabled Stop control, `false` = Accessibility tree was
    /// observable but no Stop control, `nil` = permission/window/tree
    /// unavailable. Callers must treat `nil` as "not measured".
    static func generatingIndicator(
        processID: Int32,
        windowTitle: String,
        isTrusted: Bool = AXIsProcessTrusted()
    ) -> Bool? {
        guard isTrusted else { return nil }
        let app = AXUIElementCreateApplication(pid_t(processID))
        let windows = copyWindows(of: app)
        guard !windows.isEmpty else { return nil }
        let titles = windows.map { stringAttribute($0, kAXTitleAttribute) ?? "" }

        guard case .unique(let index) = WindowMatchPolicy.match(
            targetTitle: windowTitle,
            candidateTitles: titles
        ), windows.indices.contains(index) else {
            return nil
        }

        var sawControl = false
        var sawStop = false
        var remaining = maxNodes
        walk(
            windows[index],
            depth: 0,
            remaining: &remaining,
            sawControl: &sawControl,
            foundStop: &sawStop
        )
        // A tree with zero exposed controls may be a web canvas; absence is
        // not evidence of completion, so leave it unmeasured.
        return sawControl ? sawStop : nil
    }

    private static func walk(
        _ element: AXUIElement,
        depth: Int,
        remaining: inout Int,
        sawControl: inout Bool,
        foundStop: inout Bool
    ) {
        guard depth <= maxDepth, remaining > 0, !foundStop else { return }
        remaining -= 1

        let role = stringAttribute(element, kAXRoleAttribute) ?? ""
        if role == kAXButtonRole as String {
            sawControl = true
            let enabled = boolAttribute(element, kAXEnabledAttribute) ?? true
            if enabled, isStopLabel(elementLabel(element)) {
                foundStop = true
                return
            }
        }

        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &value) == .success,
              let children = value as? [AXUIElement]
        else { return }
        for child in children {
            guard remaining > 0 else { return }
            walk(
                child,
                depth: depth + 1,
                remaining: &remaining,
                sawControl: &sawControl,
                foundStop: &foundStop
            )
            if foundStop { return }
        }
    }

    private static func elementLabel(_ element: AXUIElement) -> String {
        [kAXTitleAttribute, kAXDescriptionAttribute, kAXHelpAttribute, kAXValueAttribute]
            .compactMap { stringAttribute(element, $0) }
            .joined(separator: " ")
    }

    private static func isStopLabel(_ label: String) -> Bool {
        let normalized = label
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return false }
        return stopKeywords.contains { keyword in
            if normalized == keyword { return true }
            guard keyword.unicodeScalars.allSatisfy(\.isASCII) else {
                return normalized.contains(keyword)
            }
            return normalized.range(
                of: keyword,
                options: [.caseInsensitive, .diacriticInsensitive]
            ).map { range in
                let beforeOK = range.lowerBound == normalized.startIndex
                    || !normalized[normalized.index(before: range.lowerBound)].isLetter
                let afterOK = range.upperBound == normalized.endIndex
                    || !normalized[range.upperBound].isLetter
                return beforeOK && afterOK
            } ?? false
        }
    }

    private static func copyWindows(of app: AXUIElement) -> [AXUIElement] {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(app, kAXWindowsAttribute as CFString, &value) == .success,
              let windows = value as? [AXUIElement]
        else { return [] }
        return windows
    }

    private static func stringAttribute(_ element: AXUIElement, _ attribute: String) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success
        else { return nil }
        return value as? String
    }

    private static func boolAttribute(_ element: AXUIElement, _ attribute: String) -> Bool? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success
        else { return nil }
        return value as? Bool
    }
}
