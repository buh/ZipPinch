import XCTest
import AppKit
@testable import ZipPinch

final class ArchiveTests: XCTestCase {
    func testExample() async throws {
        let urlSession = URLSession(configuration: .ephemeral)
        let url = URL(string: "http://www.spacetelescope.org/static/images/zip/top100/top100-large.zip")!
        
        let entries = try await urlSession.zipEntries(from: url)
        
        print("Entries (\(entries.count))")
        entries.forEach { print($0.filePath) }

        XCTAssertFalse(entries.isEmpty)

        let firstEntry = entries[30]

        let data = try await urlSession.zipEntryData(firstEntry, from: url)
        let image = NSImage(data: data)
        XCTAssertNotNil(image)
        XCTAssertFalse(data.isEmpty)
    }
}
