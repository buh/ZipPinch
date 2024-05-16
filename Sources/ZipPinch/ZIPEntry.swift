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
    
    public var compressedSize: Int64 { Int64(directoryRecord.compressedSize) }
    public var uncompressedSize: Int64 { Int64(directoryRecord.uncompressedSize) }
    
    public var fileLastModificationDate: Date {
        guard directoryRecord.fileLastModificationDate != 0 else { return .msDOSReferenceDate }
        
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
        // The 16 extra bytes is because the extraFieldLength is sometimes different
        // from the length of the centralDirectory and fileEntry header.
        ... (Int64(directoryRecord.relativeOffsetOfLocalFileHeader) + Int64(length) + 16)
    }
    
    var isZIP64: Bool
    
    init(filePath: String, directoryRecord: ZIPDirectoryRecord, isZIP64: Bool) {
        id = filePath
        self.filePath = filePath
        self.isZIP64 = isZIP64
        
        if filePath.hasSuffix("/") {
            fileName = ""
        } else {
            fileName = filePath.components(separatedBy: "/").last ?? ""
        }
        
        self.directoryRecord = directoryRecord
    }
}
