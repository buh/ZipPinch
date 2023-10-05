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
        let (data, response) = try await data(for: request, delegate: delegate)
        try response.checkStatusCodeOK()
        return data
    }
    
    /// Retrieves a part of the contents as bytes of a URL and delivers the data asynchronously.
    func rangedAsyncBytes(
        for request: URLRequest,
        bytesRange: ClosedRange<Int64>,
        delegate: URLSessionTaskDelegate?
    ) async throws -> (AsyncBytes, URLResponse) {
        var request = request
        request.httpMethod = "GET"
        request.addValue("bytes=\(bytesRange.lowerBound)-\(bytesRange.upperBound)", forHTTPHeaderField: "Range")
        return try await bytes(for: request, delegate: delegate)
    }
}

extension URLResponse {
    func checkStatusCodeOK() throws {
        let httpStatusCode = (self as? HTTPURLResponse)?.statusCode ?? 0
        
        guard 200..<300 ~= httpStatusCode else {
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
        }
    }
}
