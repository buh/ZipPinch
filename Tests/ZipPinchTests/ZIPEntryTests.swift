import Testing
import Foundation
@testable import ZipPinch

struct ZIPEntryTests {
    
    @Test func zipEntryProperties() {
        // Create mock directory record
        let mockData = Data(count: 46) // Minimum size for ZIPDirectoryRecord
        let directoryRecord = mockData.withUnsafeBytes { bytes in
            ZIPDirectoryRecord(dataPointer: bytes.bindMemory(to: UInt8.self).baseAddress!)
        }
        
        // Test regular ZIP entry
        let entry = ZIPEntry(
            filePath: "test/file.txt",
            directoryRecord: directoryRecord,
            isZIP64: false
        )
        
        #expect(entry.id == "test/file.txt")
        #expect(entry.filePath == "test/file.txt")
        #expect(entry.fileName == "file.txt")
        #expect(!entry.isDirectory)
        #expect(!entry.isZIP64)
    }
    
    @Test func zipEntryDirectory() {
        let mockData = Data(count: 46)
        let directoryRecord = mockData.withUnsafeBytes { bytes in
            ZIPDirectoryRecord(dataPointer: bytes.bindMemory(to: UInt8.self).baseAddress!)
        }
        
        let directory = ZIPEntry(
            filePath: "test/folder/",
            directoryRecord: directoryRecord,
            isZIP64: false
        )
        
        #expect(directory.isDirectory)
        #expect(directory.fileName == "")
    }
    
    @Test func zipEntryZIP64() {
        let mockData = Data(count: 46)
        let directoryRecord = mockData.withUnsafeBytes { bytes in
            ZIPDirectoryRecord(dataPointer: bytes.bindMemory(to: UInt8.self).baseAddress!)
        }
        
        let zip64Info = ZIP64ExtendedInfo()
        
        let entry = ZIPEntry(
            filePath: "large/file.bin",
            directoryRecord: directoryRecord,
            isZIP64: true,
            zip64Info: zip64Info
        )
        
        #expect(entry.isZIP64)
    }
    
    @Test func zipEntryFileRange() {
        let mockData = Data(count: 46)
        let directoryRecord = mockData.withUnsafeBytes { bytes in
            ZIPDirectoryRecord(dataPointer: bytes.bindMemory(to: UInt8.self).baseAddress!)
        }
        
        let entry = ZIPEntry(
            filePath: "test.txt",
            directoryRecord: directoryRecord,
            isZIP64: false
        )
        
        let range = entry.fileRange
        #expect(range.lowerBound >= 0)
        #expect(range.upperBound > range.lowerBound)
    }
    
    @Test func zip64ExtendedInfoHasZIP64Values() {
        var info = ZIP64ExtendedInfo()
        #expect(!info.hasZIP64Values)
        
        info.uncompressedSize = 1000
        #expect(info.hasZIP64Values)
        
        info = ZIP64ExtendedInfo()
        info.compressedSize = 500
        #expect(info.hasZIP64Values)
        
        info = ZIP64ExtendedInfo()
        info.relativeOffsetOfLocalFileHeader = 12345
        #expect(info.hasZIP64Values)
        
        info = ZIP64ExtendedInfo()
        info.diskNumberWhereFileStarts = 1
        #expect(info.hasZIP64Values)
    }
}