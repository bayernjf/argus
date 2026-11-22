// Samples the visible Argus card phases through Accessibility at 10 Hz.
// Read-only: it never writes to Argus or the fixture apps and never reads
// chat text. Usage: PhaseSampler <seconds>

import AppKit
import ApplicationServices

let phases: Set<String> = ["Idle", "Streaming", "Settling", "Completed", "Unknown"]
let targetGroups: [(label: String, names: [String])] = [
    ("A", ["Argus Soak A", "Argus Fixture A"]),
    ("B", ["Argus Soak B", "Argus Fixture B"]),
    ("C", ["Argus Soak C", "Argus Fixture C"])
]
let duration = Double(CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "30") ?? 30
let start = Date()

func value(_ el: AXUIElement, _ attr: String) -> CFTypeRef? {
    var v: CFTypeRef?
    return AXUIElementCopyAttributeValue(el, attr as CFString, &v) == .success ? v : nil
}
func str(_ el: AXUIElement, _ attr: String) -> String {
    value(el, attr) as? String ?? ""
}
func collectTexts(_ el: AXUIElement, into values: inout [String]) {
    if str(el, kAXRoleAttribute) == kAXStaticTextRole as String {
        let text = str(el, kAXValueAttribute)
        if !text.isEmpty { values.append(text) }
    }
    if let children = value(el, kAXChildrenAttribute) as? [AXUIElement] {
        for child in children { collectTexts(child, into: &values) }
    }
}

func snapshot() -> String {
    guard let app = NSWorkspace.shared.runningApplications.first(where: { $0.localizedName == "Argus" }) else {
        return "ARGUS_NOT_RUNNING"
    }
    let axApp = AXUIElementCreateApplication(app.processIdentifier)
    guard let windows = value(axApp, kAXWindowsAttribute) as? [AXUIElement], let window = windows.first else {
        return "NO_WINDOW"
    }
    var texts: [String] = []
    collectTexts(window, into: &texts)
    var result: [String] = []
    for group in targetGroups {
        if let index = texts.firstIndex(where: { group.names.contains($0) }),
           texts.indices.contains(index + 1),
           phases.contains(texts[index + 1]) {
            result.append("\(group.label)=\(texts[index + 1])")
        } else {
            result.append("\(group.label)=?")
        }
    }
    return result.joined(separator: " ")
}

while Date().timeIntervalSince(start) < duration {
    let timestamp = String(format: "%.2f", Date().timeIntervalSince1970)
    print("\(timestamp) \(snapshot())")
    fflush(stdout)
    Thread.sleep(forTimeInterval: 0.1)
}
