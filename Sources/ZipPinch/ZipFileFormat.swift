// The MIT License (MIT)
//
// Copyright (c) 2023 Alexey Bukhtin (github.com/buh).
//
// The zip file information sources:
// http://en.wikipedia.org/wiki/ZIP_(file_format)#File_headers
// https://pkware.cachefly.net/webdocs/APPNOTE/APPNOTE-6.3.9.TXT
// https://fossies.org/linux/unzip/proginfo/extrafld.txt

import Foundation

/// The ZIP entry.
public struct ZIPEntry: Identifiable, Hashable, Codable {
    public let id: String
    
    /// The path to a file or directory.
    public let filePath: String
    let directoryRecord: ZIPDirectoryRecord
    
    public var compressedSize: Int64 { Int64(directoryRecord.compressedSize) }
    public var uncompressedSize: Int64 { Int64(directoryRecord.uncompressedSize) }
    
    public var fileLastModificationDate: Date? {
        guard directoryRecord.fileLastModificationDate != 0 else { return nil }
        
        return .msDOS(
            date: directoryRecord.fileLastModificationDate,
            time: directoryRecord.fileLastModificationTime
        )
    }
    
    /// Checks if the path is directory or not.
    public var isDirectory: Bool { filePath.last == "/" }
    
    var length: Int {
        MemoryLayout<ZIPFileHeader>.size
            + Int(directoryRecord.compressedSize)
            + Int(directoryRecord.fileNameLength + directoryRecord.extraFieldLength)
    }
    
    var fileRange: ClosedRange<Int64> {
        Int64(directoryRecord.relativeOffsetOfLocalFileHeader)
        ... (Int64(directoryRecord.relativeOffsetOfLocalFileHeader) + Int64(length))
    }
    
    init(filePath: String, directoryRecord: ZIPDirectoryRecord) {
        id = filePath
        self.filePath = filePath
        self.directoryRecord = directoryRecord
    }
}

struct ZIPDirectoryRecord: Hashable, Codable {
    static let sizeBytes = MemoryLayout<Self>.size - 2
    
    let centralDirectoryFileHeaderSignature: UInt32
    let versionMadeBy: UInt16
    let versionNeededToExtract: UInt16
    let generalPurposeBitFlag: UInt16
    let compressionMethod: UInt16
    let fileLastModificationTime: UInt16
    let fileLastModificationDate: UInt16
    let CRC32: UInt32
    let compressedSize: UInt32
    let uncompressedSize: UInt32
    let fileNameLength: UInt16
    let extraFieldLength: UInt16
    let fileCommentLength: UInt16
    let diskNumberWhereFileStarts: UInt16
    let internalFileAttributes: UInt16
    let externalFileAttributes: UInt32
    let relativeOffsetOfLocalFileHeader: UInt32
    
    var totalLength: Int {
        Self.sizeBytes + Int(fileNameLength) + Int(extraFieldLength) + Int(fileCommentLength)
    }
    
    init(dataPointer: UnsafeRawPointer) {
        var extractor = Extractor(dataPointer: dataPointer)
        centralDirectoryFileHeaderSignature = extractor.next(of: UInt32.self)
        versionMadeBy = extractor.next(of: UInt16.self)
        versionNeededToExtract = extractor.next(of: UInt16.self)
        generalPurposeBitFlag = extractor.next(of: UInt16.self)
        compressionMethod = extractor.next(of: UInt16.self)
        fileLastModificationTime = extractor.next(of: UInt16.self)
        fileLastModificationDate = extractor.next(of: UInt16.self)
        CRC32 = extractor.next(of: UInt32.self)
        compressedSize = extractor.next(of: UInt32.self)
        uncompressedSize = extractor.next(of: UInt32.self)
        fileNameLength = extractor.next(of: UInt16.self)
        extraFieldLength = extractor.next(of: UInt16.self)
        fileCommentLength = extractor.next(of: UInt16.self)
        diskNumberWhereFileStarts = extractor.next(of: UInt16.self)
        internalFileAttributes = extractor.next(of: UInt16.self)
        externalFileAttributes = extractor.next(of: UInt32.self)
        relativeOffsetOfLocalFileHeader = extractor.next(of: UInt32.self)
    }
}

struct ZIPFileHeader {
    static let sizeBytes = MemoryLayout<Self>.size - 2
    
    let localFileHeaderSignature: UInt32
    let versionNeededToExtract: UInt16
    let generalPurposeBitFlag: UInt16
    let compressionMethod: UInt16
    let fileLastModificationTime: UInt16
    let fileLastModificationDate: UInt16
    let CRC32: UInt32
    let compressedSize: UInt32
    let uncompressedSize: UInt32
    let fileNameLength: UInt16
    let extraFieldLength: UInt16
    
    var dataOffset: Int { Self.sizeBytes + Int(fileNameLength) + Int(extraFieldLength) }
    
    init(dataPointer: UnsafeRawPointer) {
        var extractor = Extractor(dataPointer: dataPointer)
        localFileHeaderSignature = extractor.next(of: UInt32.self)
        versionNeededToExtract = extractor.next(of: UInt16.self)
        generalPurposeBitFlag = extractor.next(of: UInt16.self)
        compressionMethod = extractor.next(of: UInt16.self)
        fileLastModificationTime = extractor.next(of: UInt16.self)
        fileLastModificationDate = extractor.next(of: UInt16.self)
        CRC32 = extractor.next(of: UInt32.self)
        compressedSize = extractor.next(of: UInt32.self)
        uncompressedSize = extractor.next(of: UInt32.self)
        fileNameLength = extractor.next(of: UInt16.self)
        extraFieldLength = extractor.next(of: UInt16.self)
    }
}

// MARK: - ZIP End Record
protocol ZIPEndRecordProtocol {
    static var size: Int64 { get }
    static var signature: [Int8]  { get }
    
    var centerDirectoryRange: ClosedRange<Int64> { get }
    
    init(dataPointer: UnsafeRawPointer)
}

struct ZIPEndRecord: ZIPEndRecordProtocol {
    static let size: Int64 = 4096
    static let signature: [Int8] = [0x50, 0x4b, 0x05, 0x06]
    
    let endOfCentralDirectorySignature: UInt32
    let numberOfThisDisk: UInt16
    let diskWhereCentralDirectoryStarts: UInt16
    let numberOfCentralDirectoryRecordsOnThisDisk: UInt16
    let totalNumberOfCentralDirectoryRecords: UInt16
    let sizeOfCentralDirectory: UInt32
    let offsetOfStartOfCentralDirectory: UInt32
    let zipFileCommentLength: UInt16
    
    var centerDirectoryRange: ClosedRange<Int64> {
        Int64(offsetOfStartOfCentralDirectory)
        ... (Int64(offsetOfStartOfCentralDirectory) + Int64(sizeOfCentralDirectory) - 1)
    }
    
    init(dataPointer: UnsafeRawPointer) {
        var extractor = Extractor(dataPointer: dataPointer)
        endOfCentralDirectorySignature = extractor.next(of: UInt32.self)
        numberOfThisDisk = extractor.next(of: UInt16.self)
        diskWhereCentralDirectoryStarts = extractor.next(of: UInt16.self)
        numberOfCentralDirectoryRecordsOnThisDisk = extractor.next(of: UInt16.self)
        totalNumberOfCentralDirectoryRecords = extractor.next(of: UInt16.self)
        sizeOfCentralDirectory = extractor.next(of: UInt32.self)
        offsetOfStartOfCentralDirectory = extractor.next(of: UInt32.self)
        zipFileCommentLength = extractor.next(of: UInt16.self)
    }
}

struct ZIPEndRecord64: ZIPEndRecordProtocol {
    static let size: Int64 = 4096
    static let signature: [Int8] = [0x50, 0x4b, 0x06, 0x06]
    
    let endOfCentralDirectorySignature: UInt32
    let sizeOfTheEOCD64: UInt64
    let versionMadeBy: UInt16
    let versionNeededToExtract: UInt16
    let numberOfThisDisk: UInt32
    let diskWhereCentralDirectoryStarts: UInt32
    let numberOfCentralDirectoryRecordsOnThisDisk: UInt64
    let totalNumberOfCentralDirectoryRecords: UInt64
    let sizeOfCentralDirectory: UInt64
    let offsetOfStartOfCentralDirectory: UInt64
    
    var centerDirectoryRange: ClosedRange<Int64> {
        Int64(offsetOfStartOfCentralDirectory)
        ... (Int64(offsetOfStartOfCentralDirectory) + Int64(sizeOfCentralDirectory) - 1)
    }
    
    init(dataPointer: UnsafeRawPointer) {
        var extractor = Extractor(dataPointer: dataPointer)
        endOfCentralDirectorySignature = extractor.next(of: UInt32.self)
        sizeOfTheEOCD64 = extractor.next(of: UInt64.self)
        versionMadeBy = extractor.next(of: UInt16.self)
        versionNeededToExtract = extractor.next(of: UInt16.self)
        numberOfThisDisk = extractor.next(of: UInt32.self)
        diskWhereCentralDirectoryStarts = extractor.next(of: UInt32.self)
        numberOfCentralDirectoryRecordsOnThisDisk = extractor.next(of: UInt64.self)
        totalNumberOfCentralDirectoryRecords = extractor.next(of: UInt64.self)
        sizeOfCentralDirectory = extractor.next(of: UInt64.self)
        offsetOfStartOfCentralDirectory = extractor.next(of: UInt64.self)
    }
}

// MARK: - Helpers

private struct Extractor {
    let dataPointer: UnsafeRawPointer
    var pointerOffset = 0
    
    mutating func next<T: FixedWidthInteger>(of: T.Type) -> T {
        let size = MemoryLayout<T>.size
        var value: T = 0
        memcpy(&value, dataPointer.advanced(by: pointerOffset), size)
        pointerOffset += size
        return value
    }
}

// MARK: - MSDOS Date/Time

private extension Date {
    static func msDOS(date: UInt16, time: UInt16) -> Date? {
        let day = (date & 0x1f)
        let month = (date >> 5) & 0x0f
        let year = ((date >> 9) & 0x7f) + 1980
        let hours = (time >> 11)
        let minutes = (time >> 5) & 0x3f
        let seconds = (time & 0x1f) * 2
        let string = "\(day)/\(month)/\(year) \(hours):\(minutes):\(seconds)"
        return DateFormatter.msDos.date(from: string)
    }
}

private extension DateFormatter {
    static let msDos : DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yyyy HH:mm:ss"
        return formatter
    }()
}
