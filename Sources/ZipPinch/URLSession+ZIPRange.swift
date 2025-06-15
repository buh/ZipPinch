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

fileprivate let logger = Logger(subsystem: "ZipPinch", category: "ZipRange")

extension URLSession {
    /// Creates a URLSession configuration optimized for range requests
    private static func createRangeRequestSession() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 15.0
        config.timeoutIntervalForResource = 60.0
        config.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        config.urlCache = nil
        config.httpMaximumConnectionsPerHost = 2
        
        return URLSession(configuration: config)
    }
    
    /// Retrieves a part of the contents of a URL and delivers the data asynchronously.
    func rangedData(
        for request: URLRequest,
        bytesRange: ClosedRange<Int64>,
        delegate: URLSessionTaskDelegate?
    ) async throws -> Data {
        let rangeSize = bytesRange.upperBound - bytesRange.lowerBound + 1
        logger.debug("📡 Range request: bytes=\(bytesRange.lowerBound)-\(bytesRange.upperBound) (\(ByteCountFormatter().string(fromByteCount: rangeSize)))")
        
        var request = request
        request.httpMethod = "GET"
        request.setValue("bytes=\(bytesRange.lowerBound)-\(bytesRange.upperBound)", forHTTPHeaderField: "Range")
        
        // Set reasonable timeout for range requests
        request.timeoutInterval = 10.0 // 10 seconds timeout
        
        // Add User-Agent and accept headers to avoid server blocking
        request.setValue("ZipPinch/1.0 (macOS)", forHTTPHeaderField: "User-Agent")
        request.setValue("*/*", forHTTPHeaderField: "Accept")
        request.setValue("gzip, deflate, br", forHTTPHeaderField: "Accept-Encoding")
        
        logger.debug("🌐 Making range request to: \(request.url?.absoluteString ?? "unknown")")
        logger.debug("📋 Request headers: \(request.allHTTPHeaderFields ?? [:])")
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Retry logic for network issues
        var lastError: Error?
        let maxRetries = 3
        
        for attempt in 1...maxRetries {
            do {
                if attempt > 1 {
                    logger.debug("🔄 Retry attempt \(attempt)/\(maxRetries)")
                    // Brief delay between retries
                    try await Task.sleep(nanoseconds: UInt64(attempt * 500_000_000)) // 0.5s * attempt
                }
                
                let session = Self.createRangeRequestSession()
                logger.debug("🔧 Created URLSession with configuration")
                
                // Add task debugging with timeout
                logger.debug("🚀 Starting URLSession.data(for:delegate:)")
                let (data, response) = try await withThrowingTaskGroup(of: (Data, URLResponse).self) { group in
                    group.addTask {
                        try await session.data(for: request, delegate: delegate)
                    }
                    
                    group.addTask {
                        try await Task.sleep(nanoseconds: 3_000_000_000) // 3 seconds
                        throw URLError(.timedOut)
                    }
                    
                    let result = try await group.next()!
                    group.cancelAll()
                    return result
                }
                logger.debug("🎯 URLSession.data completed successfully")
                let duration = CFAbsoluteTimeGetCurrent() - startTime
                
                logger.debug("📥 Received response after \(String(format: "%.2f", duration))s (attempt \(attempt))")
                logger.debug("📊 Response type: \(type(of: response))")
                
                if let httpResponse = response as? HTTPURLResponse {
                    logger.debug("📋 Response status: \(httpResponse.statusCode)")
                    logger.debug("📋 Response headers: \(httpResponse.allHeaderFields)")
                    logger.debug("📏 Response data size: \(data.count) bytes")
                }
                
                try response.checkStatusCodeOK()
                
                let throughput = Double(data.count) / duration / 1024 / 1024 // MB/s
                logger.debug("✅ Range request completed: \(ByteCountFormatter().string(fromByteCount: Int64(data.count))) in \(String(format: "%.2f", duration))s (\(String(format: "%.1f", throughput)) MB/s)")
                
                return data
                
            } catch {
                lastError = error
                let duration = CFAbsoluteTimeGetCurrent() - startTime
                logger.error("❌ Range request attempt \(attempt) failed after \(String(format: "%.2f", duration))s: \(error)")
                
                if let nsError = error as NSError? {
                    logger.error("🔐 NSError domain: \(nsError.domain), code: \(nsError.code)")
                    
                    // Don't retry for certain errors
                    switch nsError.code {
                    case -1200, -1201, -1202: // SSL/TLS errors
                        logger.error("🔐 SSL/TLS error - not retrying")
                        throw error
                    case -1001: // Timeout
                        if attempt == maxRetries {
                            logger.error("⏱️ Final timeout after \(maxRetries) attempts")
                        } else {
                            logger.debug("⏱️ Timeout - will retry")
                        }
                    case -1009: // No internet
                        logger.error("🌐 No internet connection - not retrying")
                        throw error
                    default:
                        logger.debug("🔄 Network error - will retry if attempts remain")
                    }
                }
                
                if attempt == maxRetries {
                    break
                }
            }
        }
        
        // If we get here, all retries failed
        if let lastError = lastError {
            throw lastError
        } else {
            throw ZIPError.fileDataFailedToReceive
        }
    }
    
    /// Retrieves a part of the contents as bytes of a URL and delivers the data asynchronously.
    func rangedAsyncBytes(
        for request: URLRequest,
        bytesRange: ClosedRange<Int64>,
        delegate: URLSessionTaskDelegate?
    ) async throws -> (AsyncBytes, URLResponse) {
        var request = request
        request.httpMethod = "GET"
        request.setValue("bytes=\(bytesRange.lowerBound)-\(bytesRange.upperBound)", forHTTPHeaderField: "Range")
        return try await bytes(for: request, delegate: delegate)
    }
}

extension URLResponse {
    func checkStatusCodeOK() throws {
        let httpStatusCode = (self as? HTTPURLResponse)?.statusCode ?? 0
        guard 200..<300 ~= httpStatusCode || httpStatusCode == 304 else {
            logger.error("Bad response status code: \(httpStatusCode)")
            throw ZIPError.badResponseStatusCode(httpStatusCode)
        }
    }
}

// MARK: - Errors

/// ZIP requests errors.
public enum ZIPError: Error, Equatable {
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
    /// The file data failed to receive.
    case fileDataFailedToReceive
    /// The received file data size is too small.
    case receivedFileDataSizeSmall
    /// The requested entry file data is a directory.
    case entryIsDirectory
    /// ZIP64 extended information is corrupted or invalid.
    case zip64ExtendedInfoCorrupted
    
    public var localizedDescription: String {
        switch self {
        case .badResponseStatusCode(let statusCode):
            return "The response was unsuccessful (Status Code: \(statusCode))."
        case .expectedContentLengthUnknown:
            return "The response does not contain a `Content-Length` header. "
            + "The server hosting the zip file must support the `Content-Length` header."
        case .contentLengthTooSmall:
            return "The size of the zip file is smaller than expected."
        case .centralDirectoryNotFound:
            return "No central directory information was found inside the zip file."
        case .fileNotFound:
            return "The file inside the zip file is not found or its size is zero."
        case .fileDataFailedToReceive:
            return "The file data failed to receive."
        case .receivedFileDataSizeSmall:
            return "The received file data size is too small."
        case .entryIsDirectory:
            return "The requested entry file data is a directory."
        case .zip64ExtendedInfoCorrupted:
            return "ZIP64 extended information is corrupted or contains invalid values."
        }
    }
}
