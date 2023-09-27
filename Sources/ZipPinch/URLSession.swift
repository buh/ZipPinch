// The MIT License (MIT)
//
// Copyright (c) 2023 Alexey Bukhtin (github.com/buh).
//

import Foundation

extension URLSession {
    /// Retrieves the ZIP entries.
    /// - Returns: a list of entries.
    public func zipEntries(from url: URL, delegate: URLSessionTaskDelegate? = nil) async throws -> [ZIPEntry] {
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData)
        request.httpMethod = "HEAD"
        request.setValue("None", forHTTPHeaderField: "Accept-Encoding")
        let (_, response) = try await data(for: request, delegate: delegate)
        
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
        
        return try await findCentralDirectory(from: url, fileLength: response.expectedContentLength, delegate: delegate)
    }
    
    /// Retrieves the contents of the ZIP entry.
    /// - Parameters:
    ///   - entry: the file entry.
    /// - Returns: the file data.
    public func zipEntryData(_ entry: ZIPEntry, delegate: URLSessionTaskDelegate? = nil) async throws -> Data {
        guard !entry.isDirectory else {
            throw ZIPRequestError.entryIsDirectory
        }
        
        let fileHeaderData = NSData(data: try await rangedData(
            from: entry.zipURL,
            bytesRange: entry.fileRange,
            delegate: delegate
        ))
        
        guard fileHeaderData.count > 0 else { throw ZIPRequestError.fileNotFound }
        
        let fileHeader = ZIPFileHeader(dataPointer: fileHeaderData.bytes)
        
        let compressedData = NSData(
            bytes: fileHeaderData.bytes.advanced(by: fileHeader.dataOffset),
            length: fileHeaderData.count - fileHeader.dataOffset
        )
        
        let decompressedData: Data
        
        if fileHeader.compressionMethod == 0 {
            decompressedData = Data(compressedData)
        } else {
            decompressedData = Data(try compressedData.decompressed(using: .zlib))
        }
        
        return decompressedData
    }
    
    /// Retrieves a part of the contents of a URL and delivers the data asynchronously.
    /// - Parameters:
    ///   - url: the URL to retrieve.
    ///   - bytesRange: the range of bytes of the data.
    /// - Returns: An asynchronously-delivered a Data instance.
    private func rangedData(
        from url: URL,
        bytesRange: ClosedRange<Int64>,
        delegate: URLSessionTaskDelegate?
    ) async throws -> Data {
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData)
        request.addValue("bytes=\(bytesRange.lowerBound)-\(bytesRange.upperBound)", forHTTPHeaderField: "Range")
        let (data, _) = try await data(for: request, delegate: delegate)
        return data
    }
}

// MARK: - Extracting ZIP Entries

private extension URLSession {
    func findCentralDirectory(
        from url: URL,
        fileLength: Int64,
        delegate: URLSessionTaskDelegate?
    ) async throws -> [ZIPEntry] {
        let endRecordData = try await rangedData(
            from: url,
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
        return try await parseCentralDirectory(from: url, endRecord: endRecord, delegate: delegate)
    }
    
    func parseCentralDirectory(
        from url: URL,
        endRecord: ZIPEndRecord,
        delegate: URLSessionTaskDelegate?
    ) async throws -> [ZIPEntry] {
        let directoryRecordData = try await rangedData(from: url, bytesRange: endRecord.centerDirectoryRange, delegate: delegate)
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
                let entry = ZIPEntry(url: url, filePath: String(filePath), directoryRecord: directoryRecord)
                entries.append(entry)
            }
            
            length -= directoryRecord.totalLength
            currentPointer += directoryRecord.totalLength
        }
        
        return entries
    }
}

// MARK: - Errors

/// ZIP requests errors.
public enum ZIPRequestError: Error {
    /// The response was unsuccessful.
    case badResponseStatusCode(Int)
    /// The response does not contain a `Content-Length` header.
    /// The server hosting the zip file must support the `Content-Length` header.
    case expectedContentLengthUnknown
    /// The size of the zip file is smaller than expected.
    case contentLengthTooSmall
    /// No central directory information was found inside the zip file.
    case centralDirectoryNotFound
    /// The file inside the zip file is not found or its size is zero.
    case fileNotFound
    /// The requested entry file data is a directory.
    case entryIsDirectory
}
