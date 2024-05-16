// MIT License
//
// Copyright (c) 2024 Alexey Bukhtin (github.com/buh).
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

extension Date {
    static func msDOS(date: UInt16, time: UInt16) -> Date {
        let day = (date & 0x1f)
        let month = (date >> 5) & 0x0f
        let year = ((date >> 9) & 0x7f) + 1980
        let hours = (time >> 11)
        let minutes = (time >> 5) & 0x3f
        let seconds = (time & 0x1f) * 2
        let string = "\(day)/\(month)/\(year) \(hours):\(minutes):\(seconds)"
        return DateFormatter.msDOS.date(from: string) ?? .msDOSReferenceDate
    }
    
    static let msDOSReferenceDate = Date(timeIntervalSince1970: 315_964_800)
}

private extension DateFormatter {
    static let msDOS : DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yyyy HH:mm:ss"
        return formatter
    }()
}
