import XCTest
@testable import SwiftESCPOSPrinter
import UIKit

final class SwiftESCPOSPrinterTests: XCTestCase {
    
    func testAttributedStringRasterization() {
        let string = NSMutableAttributedString(string: "Hello World")
        string.appendBold("\nBold Text")
        
        let image = string.rasterize(width: 384)
        XCTAssertNotNil(image, "Rasterization should return an image")
        XCTAssertEqual(image?.size.width, 384, "Image width should match requested width")
    }
    
    func testImageDesaturation() {
        // Create a simple colored image
        let rect = CGRect(x: 0, y: 0, width: 100, height: 100)
        UIGraphicsBeginImageContext(rect.size)
        UIColor.red.setFill()
        UIRectFill(rect)
        let image = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        
        let desaturated = image.desaturated()
        XCTAssertNotNil(desaturated, "Desaturation should return an image")
    }
    
    func testImageProcessorResize() {
        let rect = CGRect(x: 0, y: 0, width: 100, height: 100)
        UIGraphicsBeginImageContext(rect.size)
        UIColor.black.setFill()
        UIRectFill(rect)
        let image = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        
        let resized = ImageProcessor.resize(image: image, targetWidth: 50)
        XCTAssertNotNil(resized)
        XCTAssertEqual(resized?.size.width, 50)
    }
    
    func testImageProcessorToRasterCommand() {
        let rect = CGRect(x: 0, y: 0, width: 8, height: 8) // 8x8 pixels
        UIGraphicsBeginImageContext(rect.size)
        UIColor.black.setFill() // Black = Print
        UIRectFill(rect)
        let image = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        
        let command = ImageProcessor.toRasterCommand(image: image)
        XCTAssertNotNil(command)
        
        // GS v 0 m xL xH yL yH d1...dk
        // Header: 1D 76 30 00
        // xL, xH: 1, 0 (1 byte width)
        // yL, yH: 8, 0 (8 dots height)
        // Data: 8 bytes (each byte FF because black lines?)
        // Wait, logic: luminance < 128 => bit 1. Black is luminance 0. So bit 1.
        // So 8 pixels black => 11111111 => 0xFF.
        // So we expect 8 bytes of 0xFF.
        
        // Total length: 4 (header) + 2 (x) + 2 (y) + 8 (data) = 16 bytes
        XCTAssertEqual(command?.count, 16)
        
        if let data = command {
            XCTAssertEqual(data[0], 0x1D)
            XCTAssertEqual(data[1], 0x76)
            XCTAssertEqual(data[2], 0x30)
            XCTAssertEqual(data[3], 0x00)
            XCTAssertEqual(data[4], 1) // xL
            XCTAssertEqual(data[5], 0) // xH
            XCTAssertEqual(data[6], 8) // yL
            XCTAssertEqual(data[7], 0) // yH
            
            // Check first data byte
            XCTAssertEqual(data[8], 0xFF)
        }
    }
}
