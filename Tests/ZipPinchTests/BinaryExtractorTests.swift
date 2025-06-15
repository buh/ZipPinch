import Testing
import Foundation
@testable import ZipPinch

struct BinaryExtractorTests {
    
    @Test func binaryExtractorUInt8() {
        let data = Data([0x42])
        data.withUnsafeBytes { bytes in
            var extractor = BinaryExtractor(dataPointer: bytes.bindMemory(to: UInt8.self).baseAddress!)
            let value: UInt8 = extractor.next(of: UInt8.self)
            #expect(value == 0x42)
            #expect(extractor.pointerOffset == 1)
        }
    }
    
    @Test func binaryExtractorUInt16() {
        let data = Data([0x34, 0x12]) // Little endian 0x1234
        data.withUnsafeBytes { bytes in
            var extractor = BinaryExtractor(dataPointer: bytes.bindMemory(to: UInt8.self).baseAddress!)
            let value: UInt16 = extractor.next(of: UInt16.self)
            #expect(value == 0x1234)
            #expect(extractor.pointerOffset == 2)
        }
    }
    
    @Test func binaryExtractorUInt32() {
        let data = Data([0x78, 0x56, 0x34, 0x12]) // Little endian 0x12345678
        data.withUnsafeBytes { bytes in
            var extractor = BinaryExtractor(dataPointer: bytes.bindMemory(to: UInt8.self).baseAddress!)
            let value: UInt32 = extractor.next(of: UInt32.self)
            #expect(value == 0x12345678)
            #expect(extractor.pointerOffset == 4)
        }
    }
    
    @Test func binaryExtractorUInt64() {
        let data = Data([0xF0, 0xDE, 0xBC, 0x9A, 0x78, 0x56, 0x34, 0x12]) // Little endian
        data.withUnsafeBytes { bytes in
            var extractor = BinaryExtractor(dataPointer: bytes.bindMemory(to: UInt8.self).baseAddress!)
            let value: UInt64 = extractor.next(of: UInt64.self)
            #expect(value == 0x123456789ABCDEF0)
            #expect(extractor.pointerOffset == 8)
        }
    }
    
    @Test func binaryExtractorMultipleReads() {
        let data = Data([0x12, 0x34, 0x56, 0x78, 0x9A, 0xBC, 0xDE, 0xF0])
        data.withUnsafeBytes { bytes in
            var extractor = BinaryExtractor(dataPointer: bytes.bindMemory(to: UInt8.self).baseAddress!)
            
            let byte1: UInt8 = extractor.next(of: UInt8.self)
            #expect(byte1 == 0x12)
            #expect(extractor.pointerOffset == 1)
            
            let word: UInt16 = extractor.next(of: UInt16.self)
            #expect(word == 0x5634) // Little endian 0x34, 0x56
            #expect(extractor.pointerOffset == 3)
            
            let dword: UInt32 = extractor.next(of: UInt32.self)
            #expect(dword == 0xDEBC9A78) // Little endian 0x78, 0x9A, 0xBC, 0xDE
            #expect(extractor.pointerOffset == 7)
        }
    }
    
    @Test func binaryExtractorSignedIntegers() {
        let data = Data([0xFF, 0xFF, 0xFF, 0xFF]) // -1 in two's complement
        data.withUnsafeBytes { bytes in
            var extractor = BinaryExtractor(dataPointer: bytes.bindMemory(to: UInt8.self).baseAddress!)
            let value: Int32 = extractor.next(of: Int32.self)
            #expect(value == -1)
        }
    }
}