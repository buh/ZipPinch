// The MIT License (MIT)
//
// Copyright (c) 2023 Alexey Bukhtin (github.com/buh).
//

import Foundation

extension URLSession {
    /// Retrieves the ZIP entries.
    public func zipEntries(from url: URL, delegate: URLSessionTaskDelegate? = nil) async throws -> [ZIPEntry] {
        try await zipEntries(for: URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData), delegate: delegate)
    }
    
    /// Retrieves the ZIP entries.
    public func zipEntries(
        for request: URLRequest,
        delegate: URLSessionTaskDelegate? = nil
    ) async throws -> [ZIPEntry] {
        var headRequest = request
        headRequest.httpMethod = "HEAD"
        headRequest.setValue("None", forHTTPHeaderField: "Accept-Encoding")
        let (_, response) = try await data(for: headRequest, delegate: delegate)
        
        let httpStatusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
        
        guard 200..<300 ~= httpStatusCode else {
            throw ZIPRequestError.badResponseStatusCode(httpStatusCode)
        }
        
        if response.expectedContentLength == -1 {
            throw ZIPRequestError.expectedContentLengthUnknown
        }
        
        guard response.expectedContentLength > ZIPEndRecord.size else {
            throw ZIPRequestError.contentLengthTooSmall
        }
        
        return try await findCentralDirectory(
            for: request,
            fileLength: response.expectedContentLength,
            delegate: delegate
        )
    }
}

// MARK: - Extracting ZIP Entries

private extension URLSession {
    func findCentralDirectory(
        for request: URLRequest,
        fileLength: Int64,
        delegate: URLSessionTaskDelegate?
    ) async throws -> [ZIPEntry] {
        let endRecordData = try await rangedData(
            for: request,
            bytesRange: (fileLength - ZIPEndRecord.size) ... (fileLength - 1),
            delegate: delegate
        )
        
        var length = endRecordData.count
        var currentPointer = NSData(data: endRecordData).bytes
        var foundPointer: UnsafeRawPointer?
        
        repeat {
            guard let filePointer = memchr(currentPointer, 0x50, length) else { break }
            
            if memcmp(ZIPEndRecord.signature, filePointer, 4) == 0 {
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
            throw ZIPRequestError.centralDirectoryNotFound
        }
        
        let endRecord = ZIPEndRecord(dataPointer: foundPointer)
        return try await parseCentralDirectory(for: request, endRecord: endRecord, delegate: delegate)
    }
    
    func parseCentralDirectory(
        for request: URLRequest,
        endRecord: ZIPEndRecord,
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
                let entry = ZIPEntry(filePath: String(filePath), directoryRecord: directoryRecord)
                entries.append(entry)
            }
            
            length -= directoryRecord.totalLength
            currentPointer += directoryRecord.totalLength
        }
        
        return entries
    }
}
