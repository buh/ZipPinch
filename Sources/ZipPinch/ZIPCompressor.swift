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

fileprivate let logger = Logger(subsystem: "ZipPinch", category: "ZIPDecompressor")

/// Decompressor.
public enum ZIPDecompressor {
    public static var decompress: @Sendable (_ compressedData: NSData) throws -> NSData = { compressedData in
        logger.debug("🗜️ Decompressing \(compressedData.length) bytes using zlib")
        let startTime = CFAbsoluteTimeGetCurrent()
        
        do {
            let decompressedData = try compressedData.decompressed(using: .zlib)
            let duration = CFAbsoluteTimeGetCurrent() - startTime
            let compressionRatio = Double(decompressedData.length) / Double(compressedData.length)
            let throughput = Double(decompressedData.length) / duration / 1024 / 1024 // MB/s
            
            logger.debug("✅ Decompression completed: \(compressedData.length) -> \(decompressedData.length) bytes (\(String(format: "%.1fx", compressionRatio)) ratio, \(String(format: "%.1f", throughput)) MB/s)")
            return decompressedData
        } catch {
            logger.error("❌ Decompression failed: \(error.localizedDescription)")
            throw error
        }
    }
}
