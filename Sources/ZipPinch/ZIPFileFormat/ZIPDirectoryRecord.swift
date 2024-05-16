// MIT License
//
// Copyright (c) 2024 Alexey Bukhtin (github.com/buh).
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

import Foundation

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
        var extractor = BinaryExtractor(dataPointer: dataPointer)
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
