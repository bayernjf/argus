import Foundation

/// A downsampled grayscale snapshot used for deterministic visual diffing.
///
/// Pixels are kept in memory only. Dimensions must match for comparison;
/// callers that change ROI reset the baseline instead of comparing shapes.
public struct LumaGrid: Equatable, Sendable {
    public let width: Int
    public let height: Int
    public let pixels: [UInt8]

    public init(width: Int, height: Int, pixels: [UInt8]) {
        precondition(width > 0 && height > 0, "LumaGrid dimensions must be positive")
        precondition(pixels.count == width * height, "LumaGrid pixel count mismatch")
        self.width = width
        self.height = height
        self.pixels = pixels
    }

    /// Fraction of pixels whose absolute luminance delta is at least
    /// `perPixelThreshold`. Returns `nil` when the two grids are not comparable,
    /// which callers must treat as "signal unavailable", not "unchanged".
    public func changedPixelRatio(
        comparedTo previous: LumaGrid,
        perPixelThreshold: UInt8 = 8
    ) -> Double? {
        guard width == previous.width, height == previous.height else {
            return nil
        }
        guard !pixels.isEmpty else { return 0 }
        var changed = 0
        for index in pixels.indices {
            let delta = abs(Int(pixels[index]) - Int(previous.pixels[index]))
            if delta >= Int(perPixelThreshold) {
                changed += 1
            }
        }
        return Double(changed) / Double(pixels.count)
    }
}
