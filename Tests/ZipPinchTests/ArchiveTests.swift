import Testing
import OSLog
@testable import ZipPinch

#if canImport(AppKit)
import AppKit
#endif
#if canImport(UIKit)
import UIKit
#endif

private let logger = Logger(subsystem: "ZipPinch", category: "ArchiveTests")

struct ArchiveTests {
    @Test func hubbleArchive() async throws {
        let urlSession = URLSession(configuration: .ephemeral)
        let url = URL(string: "http://www.spacetelescope.org/static/images/zip/top100/top100-large.zip")!
        
        logger.info("🧪 Downloading Hubble archive from \(url)")
        let entries = try await urlSession.zipEntries(from: url)
        #expect(!entries.isEmpty)
        
        // Find the smallest file to minimize download time (much faster than index 99)
        let testEntry = entries.min { $0.compressedSize < $1.compressedSize }!
        logger.info("🧪 Testing with smallest file: \(testEntry.fileName) (\(ByteCountFormatter().string(fromByteCount: testEntry.compressedSize)) compressed)")
        
        let data = try await urlSession.zipEntryData(testEntry, from: url)
        
        #if os(macOS)
        let image = NSImage(data: data)
        #expect(image != nil)
        #else
        let image = UIImage(data: data, scale: 2)
        #expect(image != nil)
        #endif
        #expect(!data.isEmpty)
    }
}
