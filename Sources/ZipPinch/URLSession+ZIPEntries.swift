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
    /// Retrieves the ZIP entries.
    public func zipEntries(
        from url: URL,
        cachePolicy: URLRequest.CachePolicy = .reloadRevalidatingCacheData,
        delegate: URLSessionTaskDelegate? = nil
    ) async throws -> [ZIPEntry] {
        try await zipEntries(for: URLRequest(url: url, cachePolicy: cachePolicy), delegate: delegate)
    }
    
    /// Retrieves the ZIP entries.
    public func zipEntries(
        for request: URLRequest,
        delegate: URLSessionTaskDelegate? = nil
    ) async throws -> [ZIPEntry] {
        let zipContentLength = try await zipContentLength(for: request, delegate: delegate)
        return try await zipEntries(for: request, contentLength: zipContentLength, delegate: delegate)
    }
    
    /// Retrieves the ZIP content length.
    ///
    /// To have the zip file content length is useful for caching requests.
    public func zipContentLength(
        from url: URL,
        cachePolicy: URLRequest.CachePolicy = .reloadRevalidatingCacheData,
        delegate: URLSessionTaskDelegate? = nil
    ) async throws -> Int64 {
        try await zipContentLength(for: .init(url: url, cachePolicy: cachePolicy), delegate: delegate)
    }
    
    /// Retrieves the ZIP content length.
    ///
    /// To have the zip file content length is useful for caching requests.
    public func zipContentLength(
        for request: URLRequest,
        delegate: URLSessionTaskDelegate? = nil
    ) async throws -> Int64 {
        var headRequest = request
        headRequest.httpMethod = "HEAD"
        headRequest.setValue("None", forHTTPHeaderField: "Accept-Encoding")
        let (_, response) = try await data(for: headRequest, delegate: delegate)
        
        try response.checkStatusCodeOK()
        
        if response.expectedContentLength == -1 {
            throw ZIPError.expectedContentLengthUnknown
        }
        
        guard response.expectedContentLength > ZIPEndRecord.size else {
            throw ZIPError.contentLengthTooSmall
        }
        
        return response.expectedContentLength
    }
    
    /// Retrieves the ZIP entries with a known length of the zip file contents.
    public func zipEntries(
        from url: URL,
        contentLength: Int64,
        cachePolicy: URLRequest.CachePolicy = .reloadRevalidatingCacheData,
        delegate: URLSessionTaskDelegate? = nil
    ) async throws -> [ZIPEntry] {
        try await zipEntries(
            for: .init(url: url, cachePolicy: cachePolicy),
            contentLength: contentLength,
            delegate: delegate
        )
    }
    
    /// Retrieves the ZIP entries with a known length of the zip file contents.
    public func zipEntries(
        for request: URLRequest,
        contentLength: Int64,
        delegate: URLSessionTaskDelegate? = nil
    ) async throws -> [ZIPEntry] {
        let entries: [ZIPEntry]
        
        // If the file size is more then 4 GB,
        // then the zip was encoded as 64 bit version.
        if contentLength > 0xffffffff {
            entries = try await findCentralDirectory(
                for: request,
                contentLength: contentLength,
                endRecordType: ZIPEndRecord64.self,
                delegate: delegate
            )
        } else {
            entries = try await findCentralDirectory(
                for: request,
                contentLength: contentLength,
                endRecordType: ZIPEndRecord.self,
                delegate: delegate
            )
        }
        
        return entries
    }
}

// MARK: - Extracting ZIP Entries

private extension URLSession {
    func findCentralDirectory<T: ZIPEndRecordType>(
        for request: URLRequest,
        contentLength: Int64,
        endRecordType: T.Type,
        delegate: URLSessionTaskDelegate?
    ) async throws -> [ZIPEntry] {
        let endRecordData = try await rangedData(
            for: request,
            bytesRange: (contentLength - endRecordType.size) ... contentLength,
            delegate: delegate
        )
        
        var length = endRecordData.count
        var currentPointer = NSData(data: endRecordData).bytes
        var foundPointer: UnsafeRawPointer?
        
        repeat {
            guard let filePointer = memchr(currentPointer, 0x50, length) else { break }
            
            if memcmp(endRecordType.signature, filePointer, 4) == 0 {
                foundPointer = UnsafeRawPointer(filePointer)
            }
            
            length -= (Int(bitPattern: filePointer) - Int(bitPattern: currentPointer)) - 1
            
            if let p = UnsafeRawPointer(bitPattern: Int(bitPattern: filePointer) + 1) {
                currentPointer = p
            } else {
                break
            }
        } while true
        
        guard let foundPointer else {
            throw ZIPError.centralDirectoryNotFound
        }
        
        let endRecord = endRecordType.init(dataPointer: foundPointer)
        return try await parseCentralDirectory(for: request, endRecord: endRecord, delegate: delegate)
    }
    
    func parseCentralDirectory(
        for request: URLRequest,
        endRecord: some ZIPEndRecordType,
        delegate: URLSessionTaskDelegate?
    ) async throws -> [ZIPEntry] {
        let directoryRecordData = try await rangedData(
            for: request,
            bytesRange: endRecord.centerDirectoryRange,
            delegate: delegate
        )
        
        var length = directoryRecordData.count
        var currentPointer = NSData(data: directoryRecordData).bytes
        var entries = [ZIPEntry]()
        
        while length > ZIPDirectoryRecord.sizeBytes {
            let directoryRecord = ZIPDirectoryRecord(dataPointer: currentPointer)
            
            let filePath = NSString(
                bytes: currentPointer + ZIPDirectoryRecord.sizeBytes,
                length: Int(directoryRecord.fileNameLength),
                encoding: NSUTF8StringEncoding
            )
            
            if let filePath {
                let entry = ZIPEntry(
                    filePath: String(filePath),
                    directoryRecord: directoryRecord,
                    isZIP64: endRecord is ZIPEndRecord64
                )
                entries.append(entry)
            }
            
            length -= directoryRecord.totalLength
            currentPointer += directoryRecord.totalLength
        }
        
        return entries
    }
}
