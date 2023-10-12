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

/// Progress callback container.
/// It can be configured for buffer size, which will affect how often the callback is invoked.
public struct ZIPProgress {
    /// A number of bytes of the buffer, which will affect how often the callback is invoked.
    /// It can be greater than or equal to 64 Kb (default value).
    public let bufferSize: Int
    
    /// Callback progress with a value between 0 and 1.
    public let callback: (Double) -> Void
    
    /// Creates the progress container.
    /// - Parameters:
    ///   - bufferSize: the number of bytes of the buffer (64 Kb by default).
    ///   - callback: the callback progress with a value between 0 and 1.
    public init(bufferSize: Int = 0xffff, callback: @escaping (Double) -> Void) {
        self.bufferSize = bufferSize
        self.callback = callback
    }
}

public extension URLSession {
    /// Retrieves the contents of the ZIP entry.
    func zipEntryData(
        _ entry: ZIPEntry,
        from url: URL,
        cachePolicy: URLRequest.CachePolicy = .reloadRevalidatingCacheData,
        delegate: URLSessionTaskDelegate? = nil,
        progress: ZIPProgress? = nil
    ) async throws -> Data {
        try await zipEntryData(
            entry,
            for: URLRequest(url: url, cachePolicy: cachePolicy),
            delegate: delegate,
            progress: progress
        )
    }
    
    /// Retrieves the contents of the ZIP entry.
    func zipEntryData(
        _ entry: ZIPEntry,
        for request: URLRequest,
        delegate: URLSessionTaskDelegate? = nil,
        progress: ZIPProgress? = nil
    ) async throws -> Data {
        guard !entry.isDirectory else {
            throw ZIPError.entryIsDirectory
        }
        
        var receivedData: Data?
        
        if let progress, (entry.compressedSize == 0 || progress.bufferSize < Int(entry.compressedSize)) {
            do {
                receivedData = try await zipEntryDataWithProgress(
                    for: request,
                    bytesRange: entry.fileRange,
                    delegate: delegate,
                    progress: progress
                )
            } catch let error as ZIPError {
                if error != .expectedContentLengthUnknown {
                    throw error
                }
            }
        }
        
        if receivedData == nil {
            receivedData = try await rangedData(
                for: request,
                bytesRange: entry.fileRange,
                delegate: delegate
            )
        }
        
        guard let receivedData else {
            throw ZIPError.fileDataFailedToReceive
        }
        
        let fileHeaderData = NSData(data: receivedData)
        
        guard fileHeaderData.count > 0 else {
            throw ZIPError.fileNotFound
        }
        
        let fileHeader = ZIPFileHeader(dataPointer: fileHeaderData.bytes)
        
        guard receivedData.count >= entry.compressedSize else {
            throw ZIPError.receivedFileDataSizeSmall
        }
        
        let compressedData = NSData(
            bytes: fileHeaderData.bytes.advanced(by: fileHeader.dataOffset),
            length: fileHeaderData.count - fileHeader.dataOffset
        )
        
        let decompressedData: NSData
        
        if fileHeader.compressionMethod == 0 {
            decompressedData = compressedData
        } else {
            decompressedData = try ZIPEntry.decompress(compressedData)
        }
        
        return Data(referencing: decompressedData)
    }
}

// MARK: - Private

private extension URLSession {
    func zipEntryDataWithProgress(
        for request: URLRequest,
        bytesRange: ClosedRange<Int64>,
        delegate: URLSessionTaskDelegate?,
        progress: ZIPProgress
    ) async throws -> Data {
        let (asyncBytes, urlResponse) = try await rangedAsyncBytes(
            for: request,
            bytesRange: bytesRange,
            delegate: delegate
        )
        
        let length = urlResponse.expectedContentLength
        guard length > 0 else { throw ZIPError.expectedContentLengthUnknown }
        
        var data = Data()
        data.reserveCapacity(Int(length))
        let bufferSize = max(progress.bufferSize, 0xffff) // min 64 Kb
        var buffer = Data()
        buffer.reserveCapacity(min(Int(length), bufferSize))
        
        for try await byte in asyncBytes {
            buffer.append(byte)
            
            if buffer.count >= bufferSize {
                try Task.checkCancellation()
                data.append(buffer)
                buffer.removeAll(keepingCapacity: true)
                progress.callback(Double(data.count) / Double(length))
                await Task.yield()
            }
        }
        
        try Task.checkCancellation()
        
        if !buffer.isEmpty {
            data.append(buffer)
            progress.callback(1)
        }
        
        return data
    }
}
