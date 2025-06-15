import Testing
import Foundation
@testable import ZipPinch

struct ZIPErrorTests {
    
    @Test func zipErrorBadResponseStatusCode() {
        let error = ZIPError.badResponseStatusCode(404)
        #expect(error.localizedDescription == "The response was unsuccessful (Status Code: 404).")
        
        // Test equality
        let sameError = ZIPError.badResponseStatusCode(404)
        let differentError = ZIPError.badResponseStatusCode(500)
        
        #expect(error == sameError)
        #expect(error != differentError)
    }
    
    @Test func zipErrorExpectedContentLengthUnknown() {
        let error = ZIPError.expectedContentLengthUnknown
        #expect(error.localizedDescription.contains("Content-Length"))
    }
    
    @Test func zipErrorContentLengthTooSmall() {
        let error = ZIPError.contentLengthTooSmall
        #expect(error.localizedDescription.contains("smaller than expected"))
    }
    
    @Test func zipErrorCentralDirectoryNotFound() {
        let error = ZIPError.centralDirectoryNotFound
        #expect(error.localizedDescription.contains("central directory"))
    }
    
    @Test func zipErrorFileNotFound() {
        let error = ZIPError.fileNotFound
        #expect(error.localizedDescription.contains("not found"))
    }
    
    @Test func zipErrorFileDataFailedToReceive() {
        let error = ZIPError.fileDataFailedToReceive
        #expect(error.localizedDescription.contains("failed to receive"))
    }
    
    @Test func zipErrorReceivedFileDataSizeSmall() {
        let error = ZIPError.receivedFileDataSizeSmall
        #expect(error.localizedDescription.contains("too small"))
    }
    
    @Test func zipErrorEntryIsDirectory() {
        let error = ZIPError.entryIsDirectory
        #expect(error.localizedDescription.contains("directory"))
    }
    
    @Test func zipErrorZip64ExtendedInfoCorrupted() {
        let error = ZIPError.zip64ExtendedInfoCorrupted
        #expect(error.localizedDescription.contains("ZIP64"))
        #expect(error.localizedDescription.contains("corrupted"))
    }
    
    @Test func zipErrorEquality() {
        #expect(ZIPError.fileNotFound == ZIPError.fileNotFound)
        #expect(ZIPError.fileNotFound != ZIPError.entryIsDirectory)
        
        #expect(ZIPError.badResponseStatusCode(404) == ZIPError.badResponseStatusCode(404))
        #expect(ZIPError.badResponseStatusCode(404) != ZIPError.badResponseStatusCode(500))
    }
}