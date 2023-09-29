// The MIT License (MIT)
//
// Copyright (c) 2023 Alexey Bukhtin (github.com/buh).
//

import Foundation

extension URLSession {
    /// Retrieves the contents of the ZIP entry.
    public func zipEntryData(
        _ entry: ZIPEntry,
        from url: URL,
        delegate: URLSessionTaskDelegate? = nil
    ) async throws -> Data {
        try await zipEntryData(
            entry,
            for: URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData),
            delegate: delegate
        )
    }
    
    /// Retrieves the contents of the ZIP entry.
    public func zipEntryData(
        _ entry: ZIPEntry,
        for request: URLRequest,
        delegate: URLSessionTaskDelegate? = nil
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
        
        print("Compressed data", compressedData.count)
        
        let decompressedData: Data
        
        if fileHeader.compressionMethod == 0 {
            decompressedData = Data(compressedData)
        } else {
            decompressedData = Data(try compressedData.decompressed(using: .zlib))
        }
        
        return decompressedData
    }
}
