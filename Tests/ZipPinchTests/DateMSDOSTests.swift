import Testing
import Foundation
@testable import ZipPinch

struct DateMSDOSTests {
    
    @Test func msDOSDateConversion() {
        // Test a known date: January 1, 2000, 12:00:00
        // MS-DOS date format: year offset from 1980, packed into 16 bits
        // Year: 2000 - 1980 = 20, Month: 1, Day: 1
        // Date: (20 << 9) | (1 << 5) | 1 = 10240 + 32 + 1 = 10273 (0x2821)
        let date: UInt16 = 0x2821
        
        // MS-DOS time format: hours, minutes, seconds/2 packed into 16 bits  
        // 12:00:00 = (12 << 11) | (0 << 5) | 0 = 24576 (0x6000)
        let time: UInt16 = 0x6000
        
        let convertedDate = Date.msDOS(date: date, time: time)
        
        var calendar = Calendar.current
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: convertedDate)
        
        #expect(components.year == 2000)
        #expect(components.month == 1)
        #expect(components.day == 1)
        #expect(components.hour == 12)
        #expect(components.minute == 0)
        #expect(components.second == 0)
    }
    
    @Test func msDOSDateEdgeCases() {
        // Test minimum date: January 1, 1980, 00:00:00
        let minDate: UInt16 = 0x0021 // Year 0, Month 1, Day 1
        let minTime: UInt16 = 0x0000 // 00:00:00
        
        let convertedMinDate = Date.msDOS(date: minDate, time: minTime)
        
        var calendar = Calendar.current
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let components = calendar.dateComponents([.year, .month, .day], from: convertedMinDate)
        
        #expect(components.year == 1980)
        #expect(components.month == 1)
        #expect(components.day == 1)
    }
    
    @Test func msDOSDateMaximum() {
        // Test maximum valid date: December 31, 2107, 23:59:58 (seconds are stored as /2)
        // Year: 2107 - 1980 = 127 (7 bits max)
        // Month: 12, Day: 31, Hour: 23, Minute: 59, Second: 58/2 = 29
        let maxDate: UInt16 = (127 << 9) | (12 << 5) | 31  // 2107-12-31
        let maxTime: UInt16 = (23 << 11) | (59 << 5) | 29  // 23:59:58
        
        let convertedMaxDate = Date.msDOS(date: maxDate, time: maxTime)
        
        // Should not crash and should return a valid date greater than reference
        #expect(convertedMaxDate > Date.msDOSReferenceDate)
    }
    
    @Test func msDOSReferenceDate() {
        let referenceDate = Date.msDOSReferenceDate
        
        // MS-DOS reference date should be January 1, 1980
        var calendar = Calendar.current
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let components = calendar.dateComponents([.year, .month, .day], from: referenceDate)
        
        #expect(components.year == 1980)
        #expect(components.month == 1)
        #expect(components.day == 1)
    }
    
    @Test func msDOSDateSecondsPrecision() {
        // MS-DOS time has 2-second precision (seconds are stored divided by 2)
        let date: UInt16 = 0x2841 // January 1, 2000
        let time: UInt16 = 0x0001 // 00:00:02 (1 * 2 = 2 seconds)
        
        let convertedDate = Date.msDOS(date: date, time: time)
        
        var calendar = Calendar.current
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let components = calendar.dateComponents([.second], from: convertedDate)
        
        #expect(components.second == 2)
    }
    
    @Test func msDOSInvalidDate() {
        // Test with invalid date/time values that might cause parsing to fail
        let invalidDate: UInt16 = 0x0000 // All zeros
        let invalidTime: UInt16 = 0x0000
        
        let convertedDate = Date.msDOS(date: invalidDate, time: invalidTime)
        
        // Should fallback to reference date when parsing fails
        #expect(convertedDate == Date.msDOSReferenceDate)
    }
}