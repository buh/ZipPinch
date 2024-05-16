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

protocol ZIPEndRecordProtocol {
    static var size: Int64 { get }
    static var signature: [Int8]  { get }
    var isZIP64: Bool { get }
    
    var centerDirectoryRange: ClosedRange<Int64> { get }
    
    init(dataPointer: UnsafeRawPointer)
}

struct ZIPEndRecord: ZIPEndRecordProtocol {
    static let size: Int64 = 4096
    static let signature: [Int8] = [0x50, 0x4b, 0x05, 0x06]
    let isZIP64 = false
    
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
        var extractor = BinaryExtractor(dataPointer: dataPointer)
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
    let isZIP64 = true
    
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
        var extractor = BinaryExtractor(dataPointer: dataPointer)
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
