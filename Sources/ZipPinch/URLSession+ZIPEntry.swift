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

import Foundation

extension URLSession {
    /// Retrieves the contents of the ZIP entry.
    public func zipEntryData(
        _ entry: ZIPEntry,
        from url: URL,
        delegate: URLSessionTaskDelegate? = nil,
        decompressor: (_ compressedData: NSData) throws -> NSData = { try $0.decompressed(using: .zlib) }
    ) async throws -> Data {
        try await zipEntryData(
            entry,
            for: URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData),
            delegate: delegate,
            decompressor: decompressor
        )
    }
    
    /// Retrieves the contents of the ZIP entry.
    public func zipEntryData(
        _ entry: ZIPEntry,
        for request: URLRequest,
        delegate: URLSessionTaskDelegate? = nil,
        decompressor: (_ compressedData: NSData) throws -> NSData = { try $0.decompressed(using: .zlib) }
    ) async throws -> Data {
        guard !entry.isDirectory else {
            throw ZIPRequestError.entryIsDirectory
        }
        
        let fileHeaderData = NSData(data: try await rangedData(
            for: request,
            bytesRange: entry.fileRange,
            delegate: delegate
        ))
        
        guard fileHeaderData.count > 0 else { throw ZIPRequestError.fileNotFound }
        
        let fileHeader = ZIPFileHeader(dataPointer: fileHeaderData.bytes)
        
        let compressedData = NSData(
            bytes: fileHeaderData.bytes.advanced(by: fileHeader.dataOffset),
            length: fileHeaderData.count - fileHeader.dataOffset
        )
        
        let decompressedData: NSData
        
        if fileHeader.compressionMethod == 0 {
            decompressedData = compressedData
        } else {
            decompressedData = try decompressor(compressedData)
        }
        
        return Data(referencing: decompressedData)
    }
}
