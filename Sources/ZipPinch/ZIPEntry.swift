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
            return Int64(zip64CompressedSize)
        }
        return Int64(directoryRecord.compressedSize)
    }
    
    public var uncompressedSize: Int64 {
        if let zip64UncompressedSize = zip64Info?.uncompressedSize {
            return Int64(zip64UncompressedSize)
        }
        return Int64(directoryRecord.uncompressedSize)
    }
    
    var relativeOffsetOfLocalFileHeader: Int64 {
        if let zip64Offset = zip64Info?.relativeOffsetOfLocalFileHeader {
            return Int64(zip64Offset)
        }
        return Int64(directoryRecord.relativeOffsetOfLocalFileHeader)
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
        Int64(MemoryLayout<ZIPFileHeader>.size) + compressedSize +
        Int64(directoryRecord.fileNameLength + directoryRecord.extraFieldLength)
    }
    
    var fileRange: ClosedRange<Int64> {
        relativeOffsetOfLocalFileHeader
        // The 64 extra bytes is because the extraFieldLength is sometimes different
        // from the length of the centralDirectory and fileEntry header.
        // For ZIP64, we need more buffer space
        ... (relativeOffsetOfLocalFileHeader + length + (isZIP64 ? 64 : 16))
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
