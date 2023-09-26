// The MIT License (MIT)
//
// Copyright (c) 2023 Alexey Bukhtin (github.com/buh).
//

import Foundation

/// The archive entry.
public struct Entry {
    /// The archive URL.
    public let url: URL
    /// The path to a file or directory.
    public let filePath: String
    let directoryRecord: ZipDirectoryRecord
    
    /// Checks if the path is directory or not.
    public var isDirectory: Bool { filePath.last == "/" }
    
    var length: Int {
        MemoryLayout<ZipFileHeader>.size
            + Int(directoryRecord.compressedSize)
            + Int(directoryRecord.fileNameLength + directoryRecord.extraFieldLength)
    }
    
    var fileRange: ClosedRange<Int64> {
        Int64(directoryRecord.relativeOffsetOfLocalFileHeader)
        ... (Int64(directoryRecord.relativeOffsetOfLocalFileHeader) + Int64(length))
    }
    
    init(url: URL, filePath: String, directoryRecord: ZipDirectoryRecord) {
        self.url = url
        self.filePath = filePath
        self.directoryRecord = directoryRecord
    }
}
