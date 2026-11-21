import ArgusCore
import CoreGraphics
import CoreImage
import CoreMedia
import ScreenCaptureKit

/// M1c single-window capture: one SCStream per target, 2 fps, only the
/// latest frame kept in memory (docs/02 §捕获会话规格). Unrecoverable stream
/// stops (window closed, permission revoked) surface through the failure
/// state instead of crashing; re-establishing sessions is M2 scope.
final class ScreenCaptureSession: NSObject, CaptureSource, SCStreamOutput, SCStreamDelegate, @unchecked Sendable {
    private enum Layout {
        static let outputWidth = 960
        static let maxOutputHeight = 1440
    }

    let targetID = UUID()

    // Thread-safe renderer: frames are converted on the stream queue, read on
    // the main actor afterwards as immutable CGImages.
    private let renderContext = CIContext()

    private var stream: SCStream?
    private var latest: CaptureFrame?
    private var failed = false
    private var failureText: String?
    private let stateLock = NSLock()

    var isFailed: Bool { withState { failed } }
    var failureMessage: String? { withState { failureText } }

    /// Resolves the picked window by its `SCWindow.windowID` from fresh
    /// shareable content; a minimized/off-screen window no longer resolves,
    /// which surfaces as `.windowNotFound` instead of a dead stream.
    init(target: CaptureWindowInfo) async throws {
        super.init()
        let content = try await SCShareableContent.excludingDesktopWindows(true, onScreenWindowsOnly: true)
        guard let scWindow = content.windows.first(where: { $0.windowID == target.id }) else {
            throw CaptureSessionError.windowNotFound(target: target)
        }

        let aspect = scWindow.frame.width > 0 ? scWindow.frame.height / scWindow.frame.width : 9.0 / 16.0
        let configuration = SCStreamConfiguration()
        configuration.width = Layout.outputWidth
        configuration.height = min(Layout.maxOutputHeight, max(1, Int((CGFloat(Layout.outputWidth) * aspect).rounded())))
        // 2 fps: the M1 exit criterion is "thumbnail updates within 1 s of a
        // content change"; at 1 fps the pipeline alone could exceed it
        // (docs/03 §退出条件, observed during M1 acceptance).
        configuration.minimumFrameInterval = CMTime(value: 1, timescale: 2)
        configuration.queueDepth = 3
        configuration.showsCursor = false
        configuration.capturesAudio = false

        let filter = SCContentFilter(desktopIndependentWindow: scWindow)
        let stream = SCStream(filter: filter, configuration: configuration, delegate: self)
        try stream.addStreamOutput(
            self,
            type: .screen,
            sampleHandlerQueue: DispatchQueue(label: "argus.capture.\(targetID.uuidString)")
        )
        self.stream = stream
    }

    func start() async throws {
        let stream: SCStream? = withState { self.stream }
        guard let stream else { throw CaptureSessionError.stopped }
        try await stream.startCapture()
    }

    func stop() {
        let stream: SCStream? = withState {
            let current = self.stream
            self.stream = nil
            return current
        }
        guard let stream else { return }
        try? stream.removeStreamOutput(self, type: .screen)
        Task.detached(priority: .utility) { try? await stream.stopCapture() }
    }

    func latestFrame() -> CaptureFrame? {
        withState { latest }
    }

    private func withState<T>(_ body: () -> T) -> T {
        stateLock.lock()
        defer { stateLock.unlock() }
        return body()
    }

    // MARK: SCStreamOutput

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen,
              CMSampleBufferDataIsReady(sampleBuffer),
              let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)
        else { return }
        let image = CIImage(cvPixelBuffer: pixelBuffer)
        guard let cgImage = renderContext.createCGImage(image, from: image.extent) else { return }
        withState {
            latest = CaptureFrame(targetID: targetID, image: cgImage, capturedAt: Date())
        }
    }

    // MARK: SCStreamDelegate

    func stream(_ stream: SCStream, didStopWithError error: Error) {
        withState {
            failed = true
            failureText = error.localizedDescription
        }
    }
}

/// Session setup/teardown failures. Runtime stream stops surface through the
/// `CaptureSource` failure state instead.
enum CaptureSessionError: Error, Sendable, CustomStringConvertible {
    case windowNotFound(target: CaptureWindowInfo)
    case stopped

    var description: String {
        switch self {
        case .windowNotFound(let target):
            "Window \"\(target.windowTitle)\" is not on screen anymore. Is it minimized or closed?"
        case .stopped:
            "Capture session was already stopped."
        }
    }
}
