import ArgusCore
import XCTest

@testable import Argus

final class TargetFileStoreTests: XCTestCase {
    private var directory: URL!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("argus-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let directory {
            try? FileManager.default.removeItem(at: directory)
        }
    }

    private var store: TargetFileStore { TargetFileStore(directory: directory) }

    private func record(title: String = "ChatGPT") -> PersistedTarget {
        PersistedTarget(
            id: UUID(),
            displayName: "ChatGPT",
            bundleIdentifier: "com.openai.chat",
            windowTitle: title
        )
    }

    func testLoadReturnsNilBeforeFirstSave() throws {
        XCTAssertNil(try store.load())
    }

    func testRoundTripWritesAndReads() throws {
        let file = TargetFile(targets: [record(title: "One"), record(title: "Two")])
        try store.save(file)
        XCTAssertTrue(FileManager.default.fileExists(atPath: store.fileURL.path))
        XCTAssertEqual(try store.load(), file)
    }

    func testCorruptFileIsQuarantinedNotOverwritten() throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data("not json".utf8).write(to: store.fileURL)

        XCTAssertThrowsError(try store.load())
        XCTAssertFalse(FileManager.default.fileExists(atPath: store.fileURL.path), "bad file must be moved aside")
        let quarantined = try FileManager.default.contentsOfDirectory(atPath: directory.path)
            .filter { $0.hasPrefix("targets.corrupt-") }
        XCTAssertEqual(quarantined.count, 1)
    }

    func testUnsupportedVersionIsQuarantined() throws {
        var file = TargetFile(targets: [record()])
        file.version = 42
        try store.save(file)

        XCTAssertThrowsError(try store.load())
        XCTAssertFalse(FileManager.default.fileExists(atPath: store.fileURL.path))
    }
}
