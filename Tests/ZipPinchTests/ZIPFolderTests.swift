import Testing
import Foundation
@testable import ZipPinch

struct ZIPFolderTests {
    
    @Test func zipFolderInitialization() {
        let folder = ZIPFolder(name: "test")
        
        #expect(folder.name == "test")
        #expect(folder.entries.isEmpty)
        #expect(folder.subfolders.isEmpty)
        #expect(folder.compressedSize == 0)
        #expect(folder.uncompressedSize == 0)
    }
    
    @Test func zipFolderEmpty() {
        let emptyFolder = ZIPFolder.empty
        #expect(emptyFolder.name == "")
        #expect(emptyFolder.entries.isEmpty)
    }
    
    @Test func zipFolderAllEntries() {
        let folder = ZIPFolder(name: "root")
        let entries = folder.allEntries()
        #expect(entries.isEmpty)
    }
    
    @Test func rootFolderCreation() {
        let mockData = Data(count: 46)
        let directoryRecord = mockData.withUnsafeBytes { bytes in
            ZIPDirectoryRecord(dataPointer: bytes.bindMemory(to: UInt8.self).baseAddress!)
        }
        
        let entries = [
            ZIPEntry(filePath: "file1.txt", directoryRecord: directoryRecord, isZIP64: false),
            ZIPEntry(filePath: "folder/file2.txt", directoryRecord: directoryRecord, isZIP64: false),
            ZIPEntry(filePath: "folder/subfolder/file3.txt", directoryRecord: directoryRecord, isZIP64: false)
        ]
        
        let rootFolder = entries.rootFolder()
        
        #expect(rootFolder.name == "/")
        #expect(rootFolder.entries.count == 1) // file1.txt
        #expect(rootFolder.subfolders.count == 1) // folder
        
        let subfolder = rootFolder.subfolders.first!
        #expect(subfolder.name == "folder")
        #expect(subfolder.entries.count == 1) // file2.txt
        #expect(subfolder.subfolders.count == 1) // subfolder
    }
    
    @Test func rootFolderFlatStructure() {
        let mockData = Data(count: 46)
        let directoryRecord = mockData.withUnsafeBytes { bytes in
            ZIPDirectoryRecord(dataPointer: bytes.bindMemory(to: UInt8.self).baseAddress!)
        }
        
        let entries = [
            ZIPEntry(filePath: "file1.txt", directoryRecord: directoryRecord, isZIP64: false),
            ZIPEntry(filePath: "file2.txt", directoryRecord: directoryRecord, isZIP64: false),
            ZIPEntry(filePath: "file3.txt", directoryRecord: directoryRecord, isZIP64: false)
        ]
        
        let rootFolder = entries.rootFolder()
        
        #expect(rootFolder.entries.count == 3)
        #expect(rootFolder.subfolders.count == 0)
    }
    
    @Test func rootFolderDirectoriesExcluded() {
        let mockData = Data(count: 46)
        let directoryRecord = mockData.withUnsafeBytes { bytes in
            ZIPDirectoryRecord(dataPointer: bytes.bindMemory(to: UInt8.self).baseAddress!)
        }
        
        let entries = [
            ZIPEntry(filePath: "folder/", directoryRecord: directoryRecord, isZIP64: false),
            ZIPEntry(filePath: "folder/file.txt", directoryRecord: directoryRecord, isZIP64: false)
        ]
        
        let rootFolder = entries.rootFolder()
        
        // Directory entries ending with "/" should be excluded from processing
        #expect(rootFolder.subfolders.count == 1)
        #expect(rootFolder.subfolders.first?.entries.count == 1)
    }
}