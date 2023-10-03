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

public struct ZIPFolder: Identifiable, Hashable, Equatable {
    public static let empty = ZIPFolder(name: "")
    
    public let id = UUID()
    public let name: String
    public internal(set) var entries: [ZIPEntry] = []
    public internal(set) var subfolders: [Self] = []
    public internal(set) var size: Int64 = 0
}

public extension [ZIPEntry] {
    func rootFolder() -> ZIPFolder {
        var rootFolder = ZIPFolder(name: "/")
        
        for entry in self where !entry.filePath.hasSuffix("/") {
            guard entry.filePath.contains("/") else {
                rootFolder.entries.append(entry)
                continue
            }
            
            var components = entry.filePath.components(separatedBy: "/")
            components.removeLast()
            var indices = [Int]()
            
            for component in components where !component.isEmpty {
                if let index = rootFolder.subfolders.firstIndex(where: { $0.name == component }, after: indices) {
                    indices.append(index)
                } else {
                    let newFolder = ZIPFolder(name: component)
                    indices.append(rootFolder.subfolders.appendFolder(newFolder, at: indices))
                }
            }
            
            rootFolder.subfolders.appendEntry(entry, at: indices)
        }
        
        rootFolder.calcSize()
        return rootFolder
    }
}

private extension ZIPFolder {
    @discardableResult
    mutating func calcSize() -> Int64 {
        let entriesSize = entries.reduce(0) { $0 + $1.compressedSize }
        let subfoldersSize = subfolders.foldersSize()
        size = entriesSize + subfoldersSize
        return size
    }
}

private extension [ZIPFolder] {
    func firstIndex(where predicate: (Element) -> Bool, after indices: [Int]) -> Int? {
        guard !indices.isEmpty else {
            return firstIndex(where: predicate)
        }
        
        var indices = indices
        let firstIndex = indices.removeFirst()
        
        if self[firstIndex].subfolders.isEmpty {
            return nil
        }
        
        return self[firstIndex].subfolders.firstIndex(where: predicate, after: indices)
    }
    
    mutating func appendFolder(_ folder: ZIPFolder, at indices: [Int]) -> Int {
        guard !indices.isEmpty else {
            append(folder)
            return count - 1
        }
        
        var indices = indices
        let firstIndex = indices.removeFirst()
        
        if self[firstIndex].subfolders.isEmpty {
            self[firstIndex].subfolders.append(folder)
            return self[firstIndex].subfolders.count - 1
        } else {
            return self[firstIndex].subfolders.appendFolder(folder, at: indices)
        }
    }
    
    mutating func appendEntry(_ entry: ZIPEntry, at indices: [Int]) {
        guard !indices.isEmpty else { return }
        
        var indices = indices
        let firstIndex = indices.removeFirst()
        
        if indices.isEmpty {
            self[firstIndex].entries.append(entry)
        } else {
            self[firstIndex].subfolders.appendEntry(entry, at: indices)
        }
    }
    
    mutating func foldersSize() -> Int64 {
        var size: Int64 = 0
        
        for index in 0..<count {
            size += self[index].calcSize()
        }
        
        return size
    }
}
