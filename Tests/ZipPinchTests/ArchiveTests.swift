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
        let url = URL(string: "https://esahubble.org/static/images/zip/top100/top100-large.zip")!
        
        logger.info("🧪 Downloading Hubble archive from \(url)")
        let entries = try await urlSession.zipEntries(from: url)
        #expect(!entries.isEmpty)
        
        // Find the smallest file to minimize download time (much faster than index 99)
        let testEntry = entries.filter { !$0.isDirectory }.min { $0.compressedSize < $1.compressedSize }!
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
    
    @Test func quickRangeTest() async throws {
        let urlSession = URLSession(configuration: .ephemeral)
        let url = URL(string: "https://esahubble.org/static/images/zip/top100/top100-large.zip")!
        
        // This should be fast - just getting entries via range requests
        let startTime = Date()
        let entries = try await urlSession.zipEntries(from: url)
        let entriesDuration = Date().timeIntervalSince(startTime)
        
        logger.info("✅ Got \(entries.count) entries in \(String(format: "%.2f", entriesDuration))s")
        
        // Find a very small file (not necessarily the smallest to avoid edge cases)
        let smallFiles = entries.filter { !$0.isDirectory && $0.compressedSize < 50000 }.sorted { $0.compressedSize < $1.compressedSize }
        
        #expect(!smallFiles.isEmpty, "Should have small files")
        
        let testEntry = smallFiles[0]
        logger.info("📄 Testing file: \(testEntry.fileName) (\(testEntry.compressedSize) bytes compressed)")
        
        let rangeSize = testEntry.fileRange.upperBound - testEntry.fileRange.lowerBound + 1
        logger.info("📏 Range size: \(rangeSize) bytes (ratio: \(String(format: "%.1f", Double(rangeSize) / Double(testEntry.compressedSize)))x)")
        
        // This should be very fast for a small file
        let downloadStart = Date()
        let data = try await urlSession.zipEntryData(testEntry, from: url)
        let downloadDuration = Date().timeIntervalSince(downloadStart)
        
        logger.info("✅ Downloaded and decompressed \(data.count) bytes in \(String(format: "%.2f", downloadDuration))s")
        
        #expect(!data.isEmpty)
        #expect(downloadDuration < 3.0, "Small file download should be under 3 seconds, was \(downloadDuration)s")
    }
    
    @Test func debugZIP64Archive() async throws {
        let urlSession = URLSession(configuration: .ephemeral)
        let url = URL(string: "https://esahubble.org/static/images/zip/top100/top100-original.zip")!
        
        logger.info("🔍 Testing ZIP64 archive: \(url)")
        
        // First, get content length
        let contentLength = try await urlSession.zipContentLength(from: url)
        logger.info("📏 Archive size: \(ByteCountFormatter().string(fromByteCount: contentLength)) (\(contentLength) bytes)")
        
        // Should be ZIP64 if >4GB
        let isLikelyZIP64 = contentLength >= 0xFFFFFFFF
        logger.info("🔍 Likely ZIP64: \(isLikelyZIP64)")
        
        // Try to get entries (this is where it likely fails)
        do {
            let startTime = Date()
            let entries = try await urlSession.zipEntries(from: url)
            let duration = Date().timeIntervalSince(startTime)
            
            logger.info("✅ Successfully parsed ZIP64 archive with \(entries.count) entries in \(String(format: "%.2f", duration))s")
            
            // Check if we have any ZIP64 entries
            let zip64Entries = entries.filter { $0.isZIP64 }
            logger.info("📊 ZIP64 entries: \(zip64Entries.count)/\(entries.count)")
            
            // Find a small file to test extraction
            if let smallFile = entries.filter({ !$0.isDirectory && $0.compressedSize < 100000 }).first {
                logger.info("📄 Testing small file extraction: \(smallFile.fileName)")
                let data = try await urlSession.zipEntryData(smallFile, from: url)
                logger.info("✅ Successfully extracted \(data.count) bytes")
                #expect(!data.isEmpty)
            }
            
        } catch {
            logger.error("❌ Failed to parse ZIP64 archive: \(error)")
            logger.error("🔍 Error details: \(String(describing: error))")
            
            if let zipError = error as? ZIPError {
                logger.error("🔍 ZIP Error type: \(zipError)")
                logger.error("🔍 ZIP Error description: \(zipError.localizedDescription)")
            }
            
            throw error
        }
    }
}
