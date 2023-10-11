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

public extension URLSession {
    /// Retrieves the contents of the ZIP folder.
    func zipFolderData(
        _ folder: ZIPFolder,
        from url: URL,
        cachePolicy: URLRequest.CachePolicy = .reloadRevalidatingCacheData,
        delegate: URLSessionTaskDelegate? = nil,
        progress: ZIPProgress? = nil,
        decompressor: @escaping (_ compressedData: NSData) throws -> NSData = { try $0.decompressed(using: .zlib) }
    ) async throws -> [(ZIPEntry, Data)] {
        try await zipFolderData(
            folder,
            for: URLRequest(url: url, cachePolicy: cachePolicy),
            delegate: delegate,
            progress: progress,
            decompressor: decompressor
        )
    }
    
    /// Retrieves the contents of the ZIP folder.
    func zipFolderData(
        _ folder: ZIPFolder,
        for request: URLRequest,
        delegate: URLSessionTaskDelegate? = nil,
        progress: ZIPProgress? = nil,
        decompressor: @escaping (_ compressedData: NSData) throws -> NSData = { try $0.decompressed(using: .zlib) }
    ) async throws -> [(ZIPEntry, Data)] {
        try await zipEntriesData(
            folder.allEntries(),
            for: request,
            delegate: delegate,
            progress: progress,
            decompressor: decompressor
        )
    }
    
    /// Retrieves the contents of the ZIP entries.
    func zipEntriesData(
        _ entries: [ZIPEntry],
        from url: URL,
        cachePolicy: URLRequest.CachePolicy = .reloadRevalidatingCacheData,
        delegate: URLSessionTaskDelegate? = nil,
        progress: ZIPProgress? = nil,
        decompressor: @escaping (_ compressedData: NSData) throws -> NSData = { try $0.decompressed(using: .zlib) }
    ) async throws -> [(ZIPEntry, Data)] {
        try await zipEntriesData(
            entries,
            for: URLRequest(url: url, cachePolicy: cachePolicy),
            delegate: delegate,
            progress: progress,
            decompressor: decompressor
        )
    }
    
    /// Retrieves the contents of the ZIP entries.
    func zipEntriesData(
        _ entries: [ZIPEntry],
        for request: URLRequest,
        delegate: URLSessionTaskDelegate? = nil,
        progress: ZIPProgress? = nil,
        decompressor: @escaping (_ compressedData: NSData) throws -> NSData = { try $0.decompressed(using: .zlib) }
    ) async throws -> [(ZIPEntry, Data)] {
        try await withThrowingTaskGroup(of: (ZIPEntry, Data).self) { taskGroup in
            let overallProgress = OverallProgress(count: Double(entries.count))
            
            for entry in entries {
                var progressPerEntry: ZIPProgress?
                
                if let progress {
                    progressPerEntry = .init(bufferSize: progress.bufferSize) { value in
                        Task {
                            let overallValue = await overallProgress.overallValue(for: value, id: entry.filePath)
                            progress.callback(overallValue)
                        }
                    }
                }
                
                taskGroup.addTask(priority: .medium) { [progressPerEntry] in
                    (entry, try await self.zipEntryData(
                        entry,
                        for: request,
                        delegate: delegate,
                        progress: progressPerEntry,
                        decompressor: decompressor
                    ))
                }
            }
            
            return try await taskGroup.reduce(into: [(ZIPEntry, Data)]()) { partialResult, value in
                partialResult.append(value)
            }
        }
    }
}

private actor OverallProgress {
    let count: Double
    private var values = [String: Double]()
    
    init(count: Double) {
        assert(count > 0)
        self.count = count
    }
    
    func overallValue(for value: Double, id: String) async -> Double {
        values[id] = value
        return values.reduce(0.0, { $0 + $1.value }) / count
    }
}
