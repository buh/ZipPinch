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

fileprivate let logger = Logger(subsystem: "ZipPinch", category: "ZipEntries")

extension URLSession {
    /// Retrieves the ZIP entries.
    public func zipEntries(
        from url: URL,
        cachePolicy: URLRequest.CachePolicy = .reloadRevalidatingCacheData,
        delegate: URLSessionTaskDelegate? = nil
    ) async throws -> [ZIPEntry] {
        logger.debug("🗂️ Starting ZIP entries retrieval from URL: \(url.absoluteString)")
        return try await zipEntries(for: URLRequest(url: url, cachePolicy: cachePolicy), delegate: delegate)
    }
    
    /// Retrieves the ZIP entries.
    public func zipEntries(
        for request: URLRequest,
        delegate: URLSessionTaskDelegate? = nil
    ) async throws -> [ZIPEntry] {
        let startTime = CFAbsoluteTimeGetCurrent()
        let zipContentLength = try await zipContentLength(for: request, delegate: delegate)
        logger.info("📏 ZIP content length: \(zipContentLength) bytes (\(ByteCountFormatter().string(fromByteCount: zipContentLength)))")
        
        let entries = try await zipEntries(for: request, contentLength: zipContentLength, delegate: delegate)
        let duration = CFAbsoluteTimeGetCurrent() - startTime
        logger.info("✅ Retrieved \(entries.count) ZIP entries in \(String(format: "%.2f", duration))s")
        return entries
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
        logger.debug("📀 Requesting ZIP content length with HEAD request")
        var headRequest = request
        headRequest.httpMethod = "HEAD"
        headRequest.setValue("None", forHTTPHeaderField: "Accept-Encoding")
        
        let (_, response) = try await data(for: headRequest, delegate: delegate)
        
        try response.checkStatusCodeOK()
        
        if response.expectedContentLength == -1 {
            logger.error("❌ Content-Length header missing from server response")
            throw ZIPError.expectedContentLengthUnknown
        }
        
        guard response.expectedContentLength > ZIPEndRecord.size else {
            logger.error("❌ ZIP file too small: \(response.expectedContentLength) bytes (minimum: \(ZIPEndRecord.size))")
            throw ZIPError.contentLengthTooSmall
        }
        
        let contentLength = response.expectedContentLength
        logger.debug("✅ ZIP content length: \(ByteCountFormatter().string(fromByteCount: contentLength))")
        
        // Log if this might be a ZIP64 file
        if contentLength >= 0xFFFFFFFF {
            logger.info("🔍 Large ZIP file detected (\(ByteCountFormatter().string(fromByteCount: contentLength))) - likely ZIP64")
        }
        
        return contentLength
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
        logger.info("🔍 Parsing ZIP file with content length: \(ByteCountFormatter().string(fromByteCount: contentLength)) using range requests only")
        
        // CORE PRINCIPLE: Only download what we need using HTTP range requests
        // 1. Download end of file to find Central Directory location
        // 2. Download only the Central Directory to parse entries
        // 3. Individual files downloaded later using specific byte ranges
        
        let result = try await findEndOfCentralDirectory(
            for: request,
            contentLength: contentLength,
            delegate: delegate
        )
        
        logger.info("📋 Found \(result.isZIP64 ? "ZIP64" : "standard ZIP") End of Central Directory via range request")
        
        return try await parseCentralDirectory(
            for: request,
            endRecord: result.endRecord,
            isZIP64: result.isZIP64,
            delegate: delegate
        )
    }
}

// MARK: - Extracting ZIP Entries

private extension URLSession {
    
    struct EndOfCentralDirectoryResult {
        let endRecord: any ZIPEndRecordType
        let isZIP64: Bool
    }
    
    func findEndOfCentralDirectory(
        for request: URLRequest,
        contentLength: Int64,
        delegate: URLSessionTaskDelegate?
    ) async throws -> EndOfCentralDirectoryResult {
        logger.debug("🔎 Using range request to search for End of Central Directory Record")
        
        // Correct logic: Larger files need larger search windows for ZIP64 structures
        let searchSize: Int64
        if contentLength >= 8_000_000_000 { // 8GB+ files (very large ZIP64)
            searchSize = min(contentLength, 131072) // 128KB for very large ZIP64 files
            logger.info("🔍 Very large ZIP64 file (\(ByteCountFormatter().string(fromByteCount: contentLength))) - using 128KB search window")
        } else if contentLength >= 4_000_000_000 { // 4GB+ files (large ZIP64)
            searchSize = min(contentLength, 65536) // 64KB for large ZIP64 files
            logger.info("🔍 Large ZIP64 file (\(ByteCountFormatter().string(fromByteCount: contentLength))) - using 64KB search window")
        } else { // Normal files <4GB
            searchSize = min(contentLength, 32768) // 32KB for normal files
            logger.debug("📝 Normal ZIP file - using 32KB search window")
        }
        
        let rangeStart = contentLength - searchSize
        let rangeEnd = contentLength - 1
        
        logger.debug("📡 EOCD range request: bytes=\(rangeStart)-\(rangeEnd) (\(ByteCountFormatter().string(fromByteCount: searchSize)))")
        
        let endRecordData = try await rangedData(
            for: request,
            bytesRange: rangeStart ... rangeEnd,
            delegate: delegate
        )
        
        // Find the regular End of Central Directory Record first
        guard let regularEOCDPointer = findEndOfCentralDirectorySignature(
            in: endRecordData,
            signature: ZIPEndRecord.signature
        ) else {
            logger.error("❌ Could not find ZIP End of Central Directory signature in range")
            throw ZIPError.centralDirectoryNotFound
        }
        
        logger.debug("✅ Found standard EOCD signature via range request")
        let regularEOCD = ZIPEndRecord(dataPointer: regularEOCDPointer)
        
        // Check if this is a ZIP64 archive by looking for 0xFFFFFFFF markers
        let isZIP64 = regularEOCD.numberOfThisDisk == 0xFFFF ||
                     regularEOCD.diskWhereCentralDirectoryStarts == 0xFFFF ||
                     regularEOCD.numberOfCentralDirectoryRecordsOnThisDisk == 0xFFFF ||
                     regularEOCD.totalNumberOfCentralDirectoryRecords == 0xFFFF ||
                     regularEOCD.sizeOfCentralDirectory == 0xFFFFFFFF ||
                     regularEOCD.offsetOfStartOfCentralDirectory == 0xFFFFFFFF
        
        if isZIP64 {
            logger.info("🔍 ZIP64 markers detected, searching for ZIP64 End of Central Directory")
            
            // Find ZIP64 End of Central Directory Locator in the same buffer
            guard let zip64LocatorPointer = findEndOfCentralDirectorySignature(
                in: endRecordData,
                signature: ZIPEndRecord64Locator.signature
            ) else {
                logger.error("❌ ZIP64 EOCD Locator not found despite ZIP64 markers")
                throw ZIPError.centralDirectoryNotFound
            }
            
            let zip64Locator = ZIPEndRecord64Locator(dataPointer: zip64LocatorPointer)
            logger.debug("📍 ZIP64 EOCD offset: \(zip64Locator.offsetOfZip64EndOfCentralDirectoryRecord)")
            
            // CRITICAL: For ZIP64, read the actual ZIP64 End of Central Directory Record
            // This contains the real directory information, not the stub regular EOCD
            let zip64RangeStart = Int64(zip64Locator.offsetOfZip64EndOfCentralDirectoryRecord)
            let zip64RangeEnd = zip64RangeStart + ZIPEndRecord64.fixedSize + 200 // Extra buffer for extensions
            logger.debug("📡 ZIP64 EOCD range request: bytes=\(zip64RangeStart)-\(zip64RangeEnd)")
            
            let zip64EOCDData = try await rangedData(
                for: request,
                bytesRange: zip64RangeStart ... zip64RangeEnd,
                delegate: delegate
            )
            
            let zip64EOCD = ZIPEndRecord64(dataPointer: zip64EOCDData.withUnsafeBytes { $0.bindMemory(to: UInt8.self).baseAddress! })
            
            logger.info("✅ Successfully parsed ZIP64 End of Central Directory")
            logger.debug("📊 ZIP64 Stats - Records: \(zip64EOCD.totalNumberOfCentralDirectoryRecords), Directory Size: \(zip64EOCD.sizeOfCentralDirectory)")
            
            return EndOfCentralDirectoryResult(endRecord: zip64EOCD, isZIP64: true)
        } else {
            logger.info("✅ Standard ZIP format detected")
            logger.debug("📊 ZIP Stats - Records: \(regularEOCD.totalNumberOfCentralDirectoryRecords), Directory Size: \(regularEOCD.sizeOfCentralDirectory)")
            return EndOfCentralDirectoryResult(endRecord: regularEOCD, isZIP64: false)
        }
    }
    
    func findEndOfCentralDirectorySignature(
        in data: Data,
        signature: [Int8]
    ) -> UnsafeRawPointer? {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        let result = data.withUnsafeBytes { (bytes: UnsafeRawBufferPointer) -> UnsafeRawPointer? in
            var length = bytes.count
            var currentPointer = bytes.bindMemory(to: UInt8.self).baseAddress!
            var foundPointer: UnsafeRawPointer?
            
            while length >= signature.count {
                if let filePointer = memchr(currentPointer, Int32(signature[0]), length) {
                    let offset = Int(bitPattern: filePointer) - Int(bitPattern: currentPointer)
                    
                    if length - offset >= signature.count {
                        let signatureMatch = signature.withUnsafeBufferPointer { (sigBytes: UnsafeBufferPointer<Int8>) -> Bool in
                            return memcmp(sigBytes.baseAddress!, filePointer, signature.count) == 0
                        }
                        
                        if signatureMatch {
                            foundPointer = UnsafeRawPointer(filePointer)
                            break
                        }
                    }
                    
                    let advance = offset + 1
                    currentPointer = currentPointer.advanced(by: advance)
                    length -= advance
                } else {
                    break
                }
            }
            
            return foundPointer
        }
        
        let duration = CFAbsoluteTimeGetCurrent() - startTime
        logger.debug("🔍 Signature search completed in \(String(format: "%.3f", duration))s, found: \(result != nil)")
        
        return result
    }
    
    func parseCentralDirectory(
        for request: URLRequest,
        endRecord: some ZIPEndRecordType,
        isZIP64: Bool,
        delegate: URLSessionTaskDelegate?
    ) async throws -> [ZIPEntry] {
        logger.info("📂 Parsing Central Directory via range request (ZIP64: \(isZIP64))")
        
        // RANGE REQUEST: Download only the Central Directory, not the entire ZIP file
        let centralDirRange = endRecord.centerDirectoryRange
        let centralDirSize = centralDirRange.upperBound - centralDirRange.lowerBound + 1
        logger.debug("📡 Central Directory range request: bytes=\(centralDirRange.lowerBound)-\(centralDirRange.upperBound) (\(ByteCountFormatter().string(fromByteCount: centralDirSize)))")
        
        let startTime = CFAbsoluteTimeGetCurrent()
        let directoryRecordData = try await rangedData(
            for: request,
            bytesRange: centralDirRange,
            delegate: delegate
        )
        
        let downloadDuration = CFAbsoluteTimeGetCurrent() - startTime
        logger.debug("📥 Downloaded Central Directory: \(ByteCountFormatter().string(fromByteCount: Int64(directoryRecordData.count))) in \(String(format: "%.2f", downloadDuration))s")
        
        var length = directoryRecordData.count
        var currentPointer = directoryRecordData.withUnsafeBytes { $0.bindMemory(to: UInt8.self).baseAddress! }
        var entries = [ZIPEntry]()
        var zip64EntriesCount = 0
        var parseErrors = 0
        
        while length > ZIPDirectoryRecord.sizeBytes {
            let directoryRecord = ZIPDirectoryRecord(dataPointer: currentPointer)
            
            // Parse file name
            let filePath = NSString(
                bytes: currentPointer + ZIPDirectoryRecord.sizeBytes,
                length: Int(directoryRecord.fileNameLength),
                encoding: NSUTF8StringEncoding
            )
            
            if let filePath = filePath {
                // Parse extra fields to get ZIP64 extended information if needed
                var zip64Info: ZIP64ExtendedInfo? = nil
                
                if isZIP64 {
                    let extraFieldStart = currentPointer + ZIPDirectoryRecord.sizeBytes + Int(directoryRecord.fileNameLength)
                    zip64Info = parseZIP64ExtendedInfo(
                        extraFieldData: Data(bytes: extraFieldStart, count: Int(directoryRecord.extraFieldLength)),
                        directoryRecord: directoryRecord
                    )
                    
                    if zip64Info?.hasZIP64Values == true {
                        zip64EntriesCount += 1
                        logger.debug("📦 ZIP64 entry: \(String(filePath))")
                    }
                }
                
                let entry = ZIPEntry(
                    filePath: String(filePath),
                    directoryRecord: directoryRecord,
                    isZIP64: isZIP64,
                    zip64Info: zip64Info
                )
                entries.append(entry)
            } else {
                parseErrors += 1
                logger.warning("⚠️ Failed to parse file path for entry at offset \(directoryRecordData.count - length)")
            }
            
            length -= directoryRecord.totalLength
            currentPointer = currentPointer.advanced(by: directoryRecord.totalLength)
        }
        
        let duration = CFAbsoluteTimeGetCurrent() - startTime
        logger.info("✅ Parsed \(entries.count) entries in \(String(format: "%.2f", duration))s")
        
        if isZIP64 {
            logger.info("📊 ZIP64 Statistics: \(zip64EntriesCount)/\(entries.count) entries use ZIP64 extended info")
        }
        
        if parseErrors > 0 {
            logger.warning("⚠️ Encountered \(parseErrors) parse errors during Central Directory processing")
        }
        
        return entries
    }
    
    func parseZIP64ExtendedInfo(
        extraFieldData: Data,
        directoryRecord: ZIPDirectoryRecord
    ) -> ZIP64ExtendedInfo? {
        guard extraFieldData.count >= 4 else {
            logger.debug("🔍 Extra field data too small for ZIP64 info: \(extraFieldData.count) bytes")
            return nil
        }
        
        return extraFieldData.withUnsafeBytes { bytes in
            var offset = 0
            let basePointer = bytes.bindMemory(to: UInt8.self).baseAddress!
            
            while offset + 4 <= bytes.count {
                let headerID = UInt16(littleEndian: basePointer.advanced(by: offset).withMemoryRebound(to: UInt16.self, capacity: 1) { $0.pointee })
                let dataSize = UInt16(littleEndian: basePointer.advanced(by: offset + 2).withMemoryRebound(to: UInt16.self, capacity: 1) { $0.pointee })
                
                if headerID == 0x0001 { // ZIP64 Extended Information Extra Field
                    logger.debug("📋 Found ZIP64 Extended Info field, size: \(dataSize) bytes")
                    return parseZIP64ExtendedInfoField(
                        data: Data(bytes: basePointer.advanced(by: offset + 4), count: Int(dataSize)),
                        directoryRecord: directoryRecord
                    )
                }
                
                offset += 4 + Int(dataSize)
            }
            
            return nil
        }
    }
    
    func parseZIP64ExtendedInfoField(
        data: Data,
        directoryRecord: ZIPDirectoryRecord
    ) -> ZIP64ExtendedInfo {
        var info = ZIP64ExtendedInfo()
        
        // Validate minimum data size for expected fields
        let requiredSize = calculateRequiredZIP64FieldsSize(directoryRecord: directoryRecord)
        guard data.count >= requiredSize else {
            logger.warning("⚠️ ZIP64 extended info data too small: \(data.count) bytes, expected at least \(requiredSize)")
            return info
        }
        
        data.withUnsafeBytes { bytes in
            var offset = 0
            let basePointer = bytes.bindMemory(to: UInt8.self).baseAddress!
            
            // Parse fields in the order they appear, only if the corresponding 32-bit field is 0xFFFFFFFF
            if directoryRecord.uncompressedSize == 0xFFFFFFFF {
                guard offset + 8 <= data.count else {
                    logger.warning("⚠️ Missing ZIP64 uncompressedSize field")
                    return
                }
                info.uncompressedSize = UInt64(littleEndian: basePointer.advanced(by: offset).withMemoryRebound(to: UInt64.self, capacity: 1) { $0.pointee })
                logger.debug("📏 ZIP64 uncompressed size: \(info.uncompressedSize!) bytes")
                offset += 8
            }
            
            if directoryRecord.compressedSize == 0xFFFFFFFF {
                guard offset + 8 <= data.count else {
                    logger.warning("⚠️ Missing ZIP64 compressedSize field")
                    return
                }
                info.compressedSize = UInt64(littleEndian: basePointer.advanced(by: offset).withMemoryRebound(to: UInt64.self, capacity: 1) { $0.pointee })
                logger.debug("📦 ZIP64 compressed size: \(info.compressedSize!) bytes")
                offset += 8
            }
            
            if directoryRecord.relativeOffsetOfLocalFileHeader == 0xFFFFFFFF {
                guard offset + 8 <= data.count else {
                    logger.warning("⚠️ Missing ZIP64 relativeOffsetOfLocalFileHeader field")
                    return
                }
                info.relativeOffsetOfLocalFileHeader = UInt64(littleEndian: basePointer.advanced(by: offset).withMemoryRebound(to: UInt64.self, capacity: 1) { $0.pointee })
                logger.debug("📍 ZIP64 relative offset: \(info.relativeOffsetOfLocalFileHeader!)")
                offset += 8
            }
            
            if directoryRecord.diskNumberWhereFileStarts == 0xFFFF {
                guard offset + 4 <= data.count else {
                    logger.warning("⚠️ Missing ZIP64 diskNumberWhereFileStarts field")
                    return
                }
                info.diskNumberWhereFileStarts = UInt32(littleEndian: basePointer.advanced(by: offset).withMemoryRebound(to: UInt32.self, capacity: 1) { $0.pointee })
                logger.debug("💿 ZIP64 disk number: \(info.diskNumberWhereFileStarts!)")
                offset += 4
            }
        }
        
        return info
    }
    
    private func calculateRequiredZIP64FieldsSize(directoryRecord: ZIPDirectoryRecord) -> Int {
        var size = 0
        if directoryRecord.uncompressedSize == 0xFFFFFFFF { size += 8 }
        if directoryRecord.compressedSize == 0xFFFFFFFF { size += 8 }
        if directoryRecord.relativeOffsetOfLocalFileHeader == 0xFFFFFFFF { size += 8 }
        if directoryRecord.diskNumberWhereFileStarts == 0xFFFF { size += 4 }
        return size
    }
}

struct ZIP64ExtendedInfo: Codable, Hashable {
    enum CodingKeys: CodingKey {
        case uncompressedSize
        case compressedSize
        case relativeOffsetOfLocalFileHeader
        case diskNumberWhereFileStarts
    }
    
    var uncompressedSize: UInt64?
    var compressedSize: UInt64?
    var relativeOffsetOfLocalFileHeader: UInt64?
    var diskNumberWhereFileStarts: UInt32?
    
    /// Returns true if any ZIP64 values are present
    var hasZIP64Values: Bool {
        return uncompressedSize != nil || compressedSize != nil ||
               relativeOffsetOfLocalFileHeader != nil || diskNumberWhereFileStarts != nil
    }
    
    init() {}
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        uncompressedSize = try container.decodeIfPresent(UInt64.self, forKey: .uncompressedSize)
        compressedSize = try container.decodeIfPresent(UInt64.self, forKey: .compressedSize)
        relativeOffsetOfLocalFileHeader = try container.decodeIfPresent(UInt64.self, forKey: .relativeOffsetOfLocalFileHeader)
        diskNumberWhereFileStarts = try container.decodeIfPresent(UInt32.self, forKey: .diskNumberWhereFileStarts)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(uncompressedSize, forKey: .uncompressedSize)
        try container.encodeIfPresent(compressedSize, forKey: .compressedSize)
        try container.encodeIfPresent(relativeOffsetOfLocalFileHeader, forKey: .relativeOffsetOfLocalFileHeader)
        try container.encodeIfPresent(diskNumberWhereFileStarts, forKey: .diskNumberWhereFileStarts)
    }
}

struct ZIPEndRecord64Locator {
    static let signature: [Int8] = [0x50, 0x4b, 0x07, 0x06]
    
    let zip64EndOfCentralDirLocatorSignature: UInt32
    let numberOfDiskWithStartOfZip64EndOfCentralDir: UInt32
    let offsetOfZip64EndOfCentralDirectoryRecord: UInt64
    let totalNumberOfDisks: UInt32
    
    init(dataPointer: UnsafeRawPointer) {
        var extractor = BinaryExtractor(dataPointer: dataPointer)
        zip64EndOfCentralDirLocatorSignature = extractor.next(of: UInt32.self)
        numberOfDiskWithStartOfZip64EndOfCentralDir = extractor.next(of: UInt32.self)
        offsetOfZip64EndOfCentralDirectoryRecord = extractor.next(of: UInt64.self)
        totalNumberOfDisks = extractor.next(of: UInt32.self)
    }
}
