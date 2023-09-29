// The MIT License (MIT)
//
// Copyright (c) 2023 Alexey Bukhtin (github.com/buh).
//

import Foundation

extension URLSession {
    /// Retrieves a part of the contents of a URL and delivers the data asynchronously.
    func rangedData(
        for request: URLRequest,
        bytesRange: ClosedRange<Int64>,
        delegate: URLSessionTaskDelegate?
    ) async throws -> Data {
        var request = request
        request.httpMethod = "GET"
        request.addValue("bytes=\(bytesRange.lowerBound)-\(bytesRange.upperBound)", forHTTPHeaderField: "Range")
        let (data, _) = try await data(for: request, delegate: delegate)
        return data
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
