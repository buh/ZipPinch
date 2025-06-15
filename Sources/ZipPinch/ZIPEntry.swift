// MIT License
//
// Copyright (c) 2023 Alexey Bukhtin (github.com/buh).
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:

// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.

// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.
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
    public let fileName: String
    let directoryRecord: ZIPDirectoryRecord
    let zip64Info: ZIP64ExtendedInfo?
    
    // Use ZIP64 values if available, otherwise fall back to 32-bit values
    public var compressedSize: Int64 {
        if let zip64CompressedSize = zip64Info?.compressedSize {
            Int64(zip64CompressedSize)
        } else {
            Int64(directoryRecord.compressedSize)
        }
    }
    
    public var uncompressedSize: Int64 {
        if let zip64UncompressedSize = zip64Info?.uncompressedSize {
            Int64(zip64UncompressedSize)
        } else {
            Int64(directoryRecord.uncompressedSize)
        }
    }
    
    var relativeOffsetOfLocalFileHeader: Int64 {
        if let zip64Offset = zip64Info?.relativeOffsetOfLocalFileHeader {
            Int64(zip64Offset)
        } else {
            Int64(directoryRecord.relativeOffsetOfLocalFileHeader)
        }
    }
    
    public var fileLastModificationDate: Date {
        guard directoryRecord.fileLastModificationDate != 0 else { return .msDOSReferenceDate }
        
        return .msDOS(
            date: directoryRecord.fileLastModificationDate,
            time: directoryRecord.fileLastModificationTime
        )
    }
    
    /// Checks if the path is directory or not.
    public var isDirectory: Bool { filePath.last == "/" }
    
    var length: Int64 {
        // Local file header size (30 bytes according to ZIP specification)
        // Plus the file name and extra field from the directory record
        // Plus the compressed data size
        Int64(ZIPFileHeader.sizeBytes) + Int64(directoryRecord.fileNameLength + directoryRecord.extraFieldLength) + compressedSize
    }
    
    var fileRange: ClosedRange<Int64> {
        // Calculate precise range for this file only
        let rangeStart = relativeOffsetOfLocalFileHeader
        let baseLength = length
        
        // Minimal buffer to account for small differences between central directory
        // and local file header extra field lengths (typically 0-8 bytes difference)
        let bufferSize: Int64 = min(max(compressedSize / 100, 8), isZIP64 ? 32 : 16)
        
        let rangeEnd = rangeStart + baseLength + bufferSize - 1
        return rangeStart...rangeEnd
    }
    
    var isZIP64: Bool
    
    init(
        filePath: String,
        directoryRecord: ZIPDirectoryRecord,
        isZIP64: Bool,
        zip64Info: ZIP64ExtendedInfo? = nil
    ) {
        id = filePath
        self.filePath = filePath
        self.isZIP64 = isZIP64
        self.zip64Info = zip64Info
        
        if filePath.hasSuffix("/") {
            fileName = ""
        } else {
            fileName = filePath.components(separatedBy: "/").last ?? ""
        }
        
        self.directoryRecord = directoryRecord
    }
}
