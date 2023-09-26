// The MIT License (MIT)
//
// Copyright (c) 2023 Alexey Bukhtin (github.com/buh).
//

import Foundation

/// Archive is a manager for requesting and parsing data from a remote zip file.
///
/// The server hosting the zip file must support the `Content-Length` and `Range` headers.
public actor Archive {
    /// The zip file URL.
    public let url: URL
    private let urlSession: URLSession
    
    /// Creates an archive for a specific zip file.
    /// - Parameters:
    ///   - url: the zip file URL.
    ///   - urlSessionConfiguration: the configuration object that defines behavior and policies for a URL session.
    public init(url: URL, urlSessionConfiguration: URLSessionConfiguration = .ephemeral) {
        self.url = url
        self.urlSession = URLSession(configuration: urlSessionConfiguration)
    }
    
    /// Fetches the zip file entries.
    /// - Returns: a list of entries.
    public func fetchEntries() async throws -> [Entry] {
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData)
        request.httpMethod = "HEAD"
        request.setValue("None", forHTTPHeaderField: "Accept-Encoding")
        let (_, response) = try await urlSession.data(for: request)
        
        let httpStatusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
        
        guard 200..<300 ~= httpStatusCode else {
            throw ArchiveError.badResponseStatusCode(httpStatusCode)
        }
        
        if response.expectedContentLength == -1 {
            throw ArchiveError.expectedContentLengthUnknown
        }
        
        guard response.expectedContentLength > ZipEndRecord.size else {
            throw ArchiveError.contentLengthTooSmall
        }
        
        return try await findCentralDirectory(fileLength: response.expectedContentLength)
    }
    
    /// Fetches the data of a specific file within a zip file.
    /// - Parameters:
    ///   - entry: the file entry.
    /// - Returns: the file data.
    public func fetchFileData(_ entry: Entry) async throws -> Data {
        guard !entry.isDirectory else {
            throw ArchiveError.entryIsDirectory
        }
        
        let data = try await fetch(range: entry.fileRange)
        
        guard data.count > 0 else { throw ArchiveError.fileNotFound }
        
        let fileHeader = ZipFileHeader(dataPointer: data.bytes)
        
        let compressedData = NSData(
            bytes: data.bytes.advanced(by: fileHeader.dataOffset),
            length: data.count - fileHeader.dataOffset
        )
        
        let decompressedData: Data
        
        if fileHeader.compressionMethod == 0 {
            decompressedData = Data(compressedData)
        } else {
            decompressedData = Data(try compressedData.decompressed(using: .zlib))
        }
        
        return decompressedData
    }
    
    /// Fetches a range of bytes from the remote zip file.
    private func fetch(range: ClosedRange<Int64>) async throws -> NSData {
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData)
        request.addValue("bytes=\(range.lowerBound)-\(range.upperBound)", forHTTPHeaderField: "Range")
        let (data, _) = try await urlSession.data(for: request)
        return NSData(data: data)
    }
}

// MARK: - Extracting Archive Entries

private extension Archive {
    func findCentralDirectory(fileLength: Int64) async throws -> [Entry] {
        let data = try await fetch(range: (fileLength - ZipEndRecord.size) ... (fileLength - 1))
        var length = data.count
        var currentPointer = data.bytes
        var foundPointer: UnsafeRawPointer?
        
        repeat {
            guard let filePointer = memchr(currentPointer, 0x50, length) else { break }
            
            if memcmp(ZipEndRecord.signature, filePointer, 4) == 0 {
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
            throw ArchiveError.centralDirectoryNotFound
        }
        
        let endRecord = ZipEndRecord(dataPointer: foundPointer)
        return try await parseCentralDirectory(endRecord: endRecord)
    }
    
    func parseCentralDirectory(endRecord: ZipEndRecord) async throws -> [Entry] {
        let data = try await fetch(range: endRecord.centerDirectoryRange)
        var length = data.count
        var currentPointer = data.bytes
        var entries = [Entry]()
        
        while length > ZipDirectoryRecord.sizeBytes {
            let directoryRecord = ZipDirectoryRecord(dataPointer: currentPointer)
            
            let filePath = NSString(
                bytes: currentPointer + ZipDirectoryRecord.sizeBytes,
                length: Int(directoryRecord.fileNameLength),
                encoding: NSUTF8StringEncoding
            )
            
            if let filePath {
                let entry = Entry(url: url, filePath: String(filePath), directoryRecord: directoryRecord)
                entries.append(entry)
            }
            
            length -= directoryRecord.totalLength
            currentPointer += directoryRecord.totalLength
        }
        
        return entries
    }
}

// MARK: - Errors

/// Archive specific errors.
public enum ArchiveError: Error {
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
