import ArgusCore
import Foundation

/// File-backed target list (docs/02 §7). The dashboard owns an instance;
/// decoding failures quarantine the file instead of silently dropping it,
/// so a damaged list can be inspected instead of vanishing on overwrite.
struct TargetFileStore: Sendable {
    static let fileName = "targets.json"

    let directory: URL

    init(directory: URL = TargetFileStore.defaultDirectory) {
        self.directory = directory
    }

    static var defaultDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory())
                .appendingPathComponent("Library/Application Support", isDirectory: true)
        return base.appendingPathComponent("Argus", isDirectory: true)
    }

    var fileURL: URL {
        directory.appendingPathComponent(Self.fileName)
    }

    /// `nil` when no list has been saved yet. Throws when the file exists but
    /// cannot be decoded or versioned; the bad file is moved aside first.
    func load() throws -> TargetFile? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        let data = try Data(contentsOf: fileURL)
        do {
            return try JSONDecoder().decode(TargetFile.self, from: data)
        } catch {
            try? quarantine()
            throw error
        }
    }

    func save(_ file: TargetFile) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(file)
        try data.write(to: fileURL, options: [.atomic])
    }

    private func quarantine() throws {
        let stamp = Int(Date().timeIntervalSince1970)
        let destination = directory.appendingPathComponent("targets.corrupt-\(stamp).json")
        try? FileManager.default.removeItem(at: destination)
        try FileManager.default.moveItem(at: fileURL, to: destination)
    }
}
