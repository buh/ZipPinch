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
import OSLog

fileprivate let logger = Logger(subsystem: "ZipPinch", category: "ZipEntry")

/// Progress callback container.
/// It can be configured for buffer size, which will affect how often the callback is invoked.
public struct ZIPProgress {
    /// A number of bytes of the buffer, which will affect how often the callback is invoked.
    /// It can be greater than or equal to 64 Kb (default value).
    public let bufferSize: Int
    
    /// Callback progress with a value between 0 and 1.
    public let callback: @Sendable (Double) -> Void
    
    /// Creates the progress container.
    /// - Parameters:
    ///   - bufferSize: the number of bytes of the buffer (64 Kb by default).
    ///   - callback: the callback progress with a value between 0 and 1.
    public init(bufferSize: Int = 0xffff, callback: @Sendable @escaping (Double) -> Void) {
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
        let startTime = CFAbsoluteTimeGetCurrent()
        
        logger.info("📁 Extracting entry: \(entry.fileName) via range request")
        logger.debug("📊 Entry stats - Compressed: \(ByteCountFormatter().string(fromByteCount: entry.compressedSize)), Uncompressed: \(ByteCountFormatter().string(fromByteCount: entry.uncompressedSize))")
        logger.debug("📡 File range request: bytes=\(entry.fileRange.lowerBound)-\(entry.fileRange.upperBound) (\(ByteCountFormatter().string(fromByteCount: entry.fileRange.upperBound - entry.fileRange.lowerBound + 1)))")
        logger.debug("📍 Entry offset: \(entry.relativeOffsetOfLocalFileHeader), ZIP64: \(entry.isZIP64)")
        
        guard !entry.isDirectory else {
            logger.error("❌ Attempted to extract data from directory entry: \(entry.filePath)")
            throw ZIPError.entryIsDirectory
        }
        
        // Validate entry sizes
        guard entry.compressedSize >= 0 && entry.compressedSize <= Int64.max,
              entry.uncompressedSize >= 0 && entry.uncompressedSize <= Int64.max else {
            logger.error("❌ Invalid entry sizes - Compressed: \(entry.compressedSize), Uncompressed: \(entry.uncompressedSize)")
            throw ZIPError.zip64ExtendedInfoCorrupted
        }
        
        var receivedData: Data?
        
        // RANGE REQUEST: Download only this specific file's bytes, never the whole ZIP
        if let progress, (entry.compressedSize == 0 || progress.bufferSize < Int(entry.compressedSize)) {
            logger.debug("📈 Using progressive range download with buffer size: \(ByteCountFormatter().string(fromByteCount: Int64(progress.bufferSize)))")
            do {
                receivedData = try await zipEntryDataWithProgress(
                    for: request,
                    bytesRange: entry.fileRange,
                    delegate: delegate,
                    progress: progress
                )
                logger.debug("✅ Progressive range download completed")
            } catch let error as ZIPError {
                if error != .expectedContentLengthUnknown {
                    logger.error("❌ Progressive range download failed: \(error.localizedDescription)")
                    throw error
                } else {
                    logger.warning("⚠️ Progressive range download fallback to standard range request")
                }
            }
        }
        
        if receivedData == nil {
            logger.debug("📥 Using standard range request for file data")
            receivedData = try await rangedData(
                for: request,
                bytesRange: entry.fileRange,
                delegate: delegate
            )
        }
        
        guard let receivedData else {
            logger.error("❌ Failed to receive entry data")
            throw ZIPError.fileDataFailedToReceive
        }
        
        logger.debug("📦 Received \(receivedData.count) bytes for entry")
        
        let fileData = NSData(data: receivedData)
        
        guard fileData.count > 0 else {
            logger.error("❌ Entry data is empty")
            throw ZIPError.fileNotFound
        }
        
        let fileHeader = ZIPFileHeader(dataPointer: fileData.bytes)
        logger.debug("🏷️ File header - Compression: \(fileHeader.compressionMethod), Name length: \(fileHeader.fileNameLength), Extra length: \(fileHeader.extraFieldLength)")
        
        // Calculate actual data offset, considering ZIP64 extended info if present
        var dataOffset = fileHeader.dataOffset
        
        if entry.isZIP64 {
            logger.debug("🔍 Parsing ZIP64 local file extended info")
            // Parse extra fields in local file header to find ZIP64 extended info
            let extraFieldStart = fileData.bytes.advanced(by: ZIPFileHeader.sizeBytes + Int(fileHeader.fileNameLength))
            let extraFieldData = Data(bytes: extraFieldStart, count: Int(fileHeader.extraFieldLength))
            
            if parseZIP64LocalFileExtendedInfo(extraFieldData: extraFieldData, fileHeader: fileHeader) != nil {
                logger.debug("✅ Found ZIP64 local file extended info")
                // Recalculate data offset if ZIP64 extended info is present
                dataOffset = ZIPFileHeader.sizeBytes + Int(fileHeader.fileNameLength) + Int(fileHeader.extraFieldLength)
            }
        }
        
        logger.debug("📍 Data starts at offset: \(dataOffset)")
        
        // Ensure we have enough data for the compressed file
        let remainingDataSize = receivedData.count - dataOffset
        let expectedCompressedSize = Int(entry.compressedSize)
        
        guard expectedCompressedSize >= 0 && expectedCompressedSize <= Int.max else {
            logger.error("❌ Compressed size out of bounds: \(expectedCompressedSize)")
            throw ZIPError.zip64ExtendedInfoCorrupted
        }
        
        guard remainingDataSize >= expectedCompressedSize else {
            logger.error("❌ Insufficient data - Available: \(remainingDataSize), Expected: \(expectedCompressedSize)")
            throw ZIPError.receivedFileDataSizeSmall
        }
        
        let compressedData = NSData(
            bytes: fileData.bytes.advanced(by: dataOffset),
            length: expectedCompressedSize
        )
        
        logger.debug("🗜️ Extracted compressed data: \(compressedData.length) bytes")
        
        let decompressedData: NSData
        
        if fileHeader.compressionMethod == 0 {
            logger.debug("📄 No compression - using data as-is")
            decompressedData = compressedData
        } else {
            logger.debug("🗜️ Decompressing data using method: \(fileHeader.compressionMethod)")
            do {
                decompressedData = try ZIPDecompressor.decompress(compressedData)
                logger.debug("✅ Decompression successful: \(decompressedData.length) bytes")
            } catch {
                logger.error("❌ Decompression failed: \(error.localizedDescription)")
                throw error
            }
        }
        
        // Validate decompressed size matches expected size
        if entry.uncompressedSize > 0 && decompressedData.length != Int(entry.uncompressedSize) {
            logger.warning("⚠️ Decompressed size mismatch - Expected: \(entry.uncompressedSize), Got: \(decompressedData.length)")
        }
        
        let duration = CFAbsoluteTimeGetCurrent() - startTime
        let throughput = Double(decompressedData.length) / duration / 1024 / 1024 // MB/s
        
        logger.info("✅ Entry extraction completed in \(String(format: "%.2f", duration))s (\(String(format: "%.1f", throughput)) MB/s)")
        
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
        let rangeSize = bytesRange.upperBound - bytesRange.lowerBound + 1
        logger.debug("📊 Starting progressive range download: bytes=\(bytesRange.lowerBound)-\(bytesRange.upperBound) (\(ByteCountFormatter().string(fromByteCount: rangeSize)))")
        
        // RANGE REQUEST: Progressive download using async bytes with range request
        let (asyncBytes, urlResponse) = try await rangedAsyncBytes(
            for: request,
            bytesRange: bytesRange,
            delegate: delegate
        )
        
        let length = urlResponse.expectedContentLength
        guard length > 0 else {
            logger.warning("⚠️ No content length available for progressive download")
            throw ZIPError.expectedContentLengthUnknown
        }
        
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
    
    func parseZIP64LocalFileExtendedInfo(
        extraFieldData: Data,
        fileHeader: ZIPFileHeader
    ) -> ZIP64LocalFileExtendedInfo? {
        guard extraFieldData.count >= 4 else { return nil }
        
        return extraFieldData.withUnsafeBytes { bytes in
            var offset = 0
            let basePointer = bytes.bindMemory(to: UInt8.self).baseAddress!
            
            while offset + 4 <= bytes.count {
                let headerID = UInt16(littleEndian: basePointer.advanced(by: offset).withMemoryRebound(to: UInt16.self, capacity: 1) { $0.pointee })
                let dataSize = UInt16(littleEndian: basePointer.advanced(by: offset + 2).withMemoryRebound(to: UInt16.self, capacity: 1) { $0.pointee })
                
                if headerID == 0x0001 { // ZIP64 Extended Information Extra Field
                    return parseZIP64LocalFileExtendedInfoField(
                        data: Data(bytes: basePointer.advanced(by: offset + 4), count: Int(dataSize)),
                        fileHeader: fileHeader
                    )
                }
                
                offset += 4 + Int(dataSize)
            }
            
            return nil
        }
    }
    
    func parseZIP64LocalFileExtendedInfoField(
        data: Data,
        fileHeader: ZIPFileHeader
    ) -> ZIP64LocalFileExtendedInfo {
        var info = ZIP64LocalFileExtendedInfo()
        
        data.withUnsafeBytes { bytes in
            var offset = 0
            let basePointer = bytes.bindMemory(to: UInt8.self).baseAddress!
            
            // Parse fields in the order they appear, only if the corresponding 32-bit field is 0xFFFFFFFF
            if fileHeader.uncompressedSize == 0xFFFFFFFF && offset + 8 <= data.count {
                info.uncompressedSize = UInt64(littleEndian: basePointer.advanced(by: offset).withMemoryRebound(to: UInt64.self, capacity: 1) { $0.pointee })
                offset += 8
            }
            
            if fileHeader.compressedSize == 0xFFFFFFFF && offset + 8 <= data.count {
                info.compressedSize = UInt64(littleEndian: basePointer.advanced(by: offset).withMemoryRebound(to: UInt64.self, capacity: 1) { $0.pointee })
                offset += 8
            }
        }
        
        return info
    }
}

struct ZIP64LocalFileExtendedInfo {
    var uncompressedSize: UInt64?
    var compressedSize: UInt64?
}
