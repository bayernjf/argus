// Synthetic macOS chat fixture for M3 reply-completion acceptance.
// It never uses the network and never contains user content. The event log
// records timestamps and lifecycle labels only, never message text.

import AppKit

final class FixtureController: NSObject, NSApplicationDelegate {
    private var window: NSWindow!
    private var label: NSTextField!
    private var stopButton: NSButton!
    private var spinner: NSProgressIndicator!
    private var caret: NSTextField!
    private var timer: Timer?
    private var caretTimer: Timer?
    private var chunkIndex = 0
    private var chunks: [String] = []
    private var mode = "normal"
    private var eventLog: URL?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let args = CommandLine.arguments
        mode = value(after: "--mode", in: args) ?? "normal"
        let title = value(after: "--title", in: args) ?? "Argus Fixture"
        let delay = Double(value(after: "--delay", in: args) ?? "10") ?? 10
        let count = Int(value(after: "--chunks", in: args) ?? "28") ?? 28
        if let path = value(after: "--log", in: args) {
            eventLog = URL(fileURLWithPath: path)
        }
        chunks = (1...max(1, count)).map { i in
            ["Streaming reply line \(i).", "This fixture has no user content.", "Detection should stay Streaming while text grows."][i % 3]
        }

        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 640, height: 430),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = title
        window.center()
        window.backgroundColor = .white

        let root = NSStackView()
        root.orientation = .vertical
        root.alignment = .leading
        root.spacing = 12
        root.edgeInsets = NSEdgeInsets(top: 18, left: 22, bottom: 18, right: 22)
        root.translatesAutoresizingMaskIntoConstraints = false

        let header = NSTextField(labelWithString: "Argus synthetic chat fixture")
        header.font = .systemFont(ofSize: 22, weight: .bold)
        header.textColor = .black

        let subtitle = NSTextField(labelWithString: "Mode: \(mode) · no network · no user data")
        subtitle.font = .systemFont(ofSize: 12)
        subtitle.textColor = .darkGray

        label = NSTextField(wrappingLabelWithString: "")
        label.font = .systemFont(ofSize: 17, weight: .regular)
        label.textColor = .black
        label.maximumNumberOfLines = 0
        label.preferredMaxLayoutWidth = 580

        caret = NSTextField(labelWithString: "▌")
        caret.font = .systemFont(ofSize: 17)
        caret.textColor = .black
        caret.isHidden = true

        let controlRow = NSStackView()
        controlRow.orientation = .horizontal
        controlRow.spacing = 10

        spinner = NSProgressIndicator()
        spinner.style = .spinning
        spinner.controlSize = .small
        spinner.isDisplayedWhenStopped = false
        spinner.translatesAutoresizingMaskIntoConstraints = false
        spinner.widthAnchor.constraint(equalToConstant: 16).isActive = true
        spinner.heightAnchor.constraint(equalToConstant: 16).isActive = true

        stopButton = NSButton(title: "Stop generating", target: self, action: #selector(stopPressed))
        stopButton.bezelStyle = .rounded
        stopButton.font = .systemFont(ofSize: 14)
        stopButton.setAccessibilityLabel("Stop generating")
        stopButton.isHidden = true

        controlRow.addArrangedSubview(spinner)
        controlRow.addArrangedSubview(stopButton)
        controlRow.addArrangedSubview(caret)

        let body = NSView()
        body.translatesAutoresizingMaskIntoConstraints = false
        body.heightAnchor.constraint(equalToConstant: 250).isActive = true
        body.addSubview(label)
        label.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: body.leadingAnchor),
            label.trailingAnchor.constraint(equalTo: body.trailingAnchor),
            label.topAnchor.constraint(equalTo: body.topAnchor),
            label.widthAnchor.constraint(equalToConstant: 580),
        ])

        root.addArrangedSubview(header)
        root.addArrangedSubview(subtitle)
        root.addArrangedSubview(body)
        root.addArrangedSubview(controlRow)

        let content = NSView()
        content.addSubview(root)
        NSLayoutConstraint.activate([
            root.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            root.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            root.topAnchor.constraint(equalTo: content.topAnchor),
            root.bottomAnchor.constraint(lessThanOrEqualTo: content.bottomAnchor),
        ])
        window.contentView = content

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        event("launch")

        switch mode {
        case "static":
            label.stringValue = "A completed reply is already visible. There is no generating control."
        case "blink":
            label.stringValue = "A completed reply with a blinking caret. Visual-only detection must not call this Streaming forever."
            caret.isHidden = false
            caretTimer = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: true) { [weak self] _ in
                self?.caret.isHidden.toggle()
            }
        default:
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                self?.startStreaming()
            }
        }
    }

    private func startStreaming() {
        stopButton.isHidden = false
        spinner.startAnimation(nil)
        event("stream_start")
        scheduleTick(after: 0.15)
    }

    private func scheduleTick(after interval: TimeInterval) {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            self?.tick()
        }
    }

    private func tick() {
        guard chunkIndex < chunks.count else {
            finish()
            return
        }
        let text = chunks[chunkIndex]
        chunkIndex += 1
        label.stringValue = label.stringValue.isEmpty ? text : label.stringValue + " " + text
        if chunkIndex == chunks.count {
            event("last_text_change")
        }
        if mode == "stall", chunkIndex == 8 {
            // Keep the Stop control and spinner visible while text is stable
            // for three seconds. This is the high-confidence false-positive
            // scenario: a visual-only detector must not call it Completed.
            event("stall_begin")
            scheduleTick(after: 3.0)
            return
        }
        if mode == "stallAx", chunkIndex == 8 {
            // Text and spinner both freeze; only the accessible Stop control
            // remains. Without Accessibility this would look completed, so
            // this is the targeted AX-required negative fixture.
            spinner.stopAnimation(nil)
            event("stall_begin")
            scheduleTick(after: 4.0)
            return
        }
        if mode == "stallAx", chunkIndex == 9 {
            spinner.startAnimation(nil)
            event("stall_end")
        }
        scheduleTick(after: 0.24)
    }

    private func finish() {
        timer?.invalidate()
        stopButton.isHidden = true
        spinner.stopAnimation(nil)
        event("finish")
    }

    private func event(_ label: String) {
        guard let eventLog else { return }
        let line = "\(Date().timeIntervalSince1970) \(label)\n"
        if !FileManager.default.fileExists(atPath: eventLog.path) {
            FileManager.default.createFile(atPath: eventLog.path, contents: nil)
        }
        if let handle = try? FileHandle(forWritingTo: eventLog) {
            handle.seekToEndOfFile()
            handle.write(Data(line.utf8))
            try? handle.close()
        }
    }

    @objc private func stopPressed() {
        finish()
    }

    private func value(after flag: String, in args: [String]) -> String? {
        guard let index = args.firstIndex(of: flag), args.indices.contains(index + 1) else { return nil }
        return args[index + 1]
    }
}

let app = NSApplication.shared
let controller = FixtureController()
app.delegate = controller
app.setActivationPolicy(.regular)
app.run()
