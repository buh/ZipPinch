import XCTest
@testable import ZipPinch

#if canImport(AppKit)
import AppKit
#endif
#if canImport(UIKit)
import UIKit
#endif

final class ArchiveTests: XCTestCase {
    func test_hubble() async throws {
        let urlSession = URLSession(configuration: .ephemeral)
        let url = URL(string: "http://www.spacetelescope.org/static/images/zip/top100/top100-large.zip")!
        
        let entries = try await urlSession.zipEntries(from: url)
        XCTAssertFalse(entries.isEmpty)
        
        let firstEntry = entries[99]
        let data = try await urlSession.zipEntryData(firstEntry, from: url)
        
        #if os(macOS)
        let image = NSImage(data: data)
        XCTAssertNotNil(image)
        #else
        let image = UIImage(data: data, scale: 3)
        XCTAssertNotNil(image)
        #endif
        XCTAssertFalse(data.isEmpty)
    }
}
