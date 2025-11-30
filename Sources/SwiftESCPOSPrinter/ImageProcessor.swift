//
//  ImageProcessor.swift
//  SwiftESCPOSPrinter
//

import UIKit

public class ImageProcessor {
    
    /// Resizes the image to the target width while maintaining aspect ratio.
    public static func resize(image: UIImage, targetWidth: CGFloat) -> UIImage? {
        let size = image.size
        let widthRatio  = targetWidth  / size.width
        
        // Figure out what our orientation is, and use that to form the rectangle
        var newSize: CGSize
        if(widthRatio > 1) {
            newSize = CGSize(width: size.width * widthRatio, height: size.height * widthRatio)
        } else {
            newSize = CGSize(width: size.width * widthRatio, height: size.height * widthRatio)
        }
        
        // This is the rect that we've calculated out and this is what is actually used below
        let rect = CGRect(x: 0, y: 0, width: newSize.width, height: newSize.height)
        
        // Actually do the resizing to the rect using the ImageContext stuff
        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        image.draw(in: rect)
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return newImage
    }
    
    /// Converts a UIImage to ESC/POS raster bit image data (GS v 0).
    /// Assumes image is already resized to correct width (e.g. 576 dots).
    public static func toRasterCommand(image: UIImage) -> Data? {
        guard let cgImage = image.cgImage else { return nil }
        
        let width = cgImage.width
        let height = cgImage.height
        
        // Width must be divisible by 8 for byte packing
        let bytesPerRow = (width + 7) / 8
        
        guard let dataProvider = cgImage.dataProvider,
              let data = dataProvider.data,
              let ptr = CFDataGetBytePtr(data) else {
            return nil
        }
        
        var rasterData = Data()
        
        // Iterate over pixels
        // This is a simplified thresholding. For better results, Floyd-Steinberg dithering should be used.
        // Here we assume the image is already desaturated/grayscale.
        
        let bytesPerPixel = cgImage.bitsPerPixel / 8
        let bytesPerLine = cgImage.bytesPerRow
        
        for y in 0..<height {
            for xByte in 0..<bytesPerRow {
                var byte: UInt8 = 0
                for bit in 0..<8 {
                    let x = xByte * 8 + bit
                    if x < width {
                        // Get pixel luminosity
                        let offset = y * bytesPerLine + x * bytesPerPixel
                        // Assuming RGBA or similar where R, G, B are first 3 bytes.
                        // If grayscale, just one byte.
                        // Let's assume standard RGBA for simplicity from UIGraphics
                        
                        let r = ptr[offset]
                        let g = ptr[offset + 1]
                        let b = ptr[offset + 2]
                        
                        // Luminance formula
                        let luminance = 0.299 * Double(r) + 0.587 * Double(g) + 0.114 * Double(b)
                        
                        // Threshold (128 is standard mid-point)
                        // 0 = black (print), 1 = white (no print)
                        // In ESC/POS GS v 0: 1 = print (black), 0 = white (no print)
                        // Wait, standard raster mode: 1 is print.
                        // So if luminance < 128 (dark), set bit to 1.
                        
                        if luminance < 128 {
                            byte |= (1 << (7 - bit))
                        }
                    }
                }
                rasterData.append(byte)
            }
        }
        
        // Construct command
        // GS v 0 m xL xH yL yH d1...dk
        var command = Data()
        command.append(contentsOf: [0x1D, 0x76, 0x30, 0x00]) // GS v 0 normal mode
        
        // xL, xH (bytes per row)
        let xL = UInt8(bytesPerRow % 256)
        let xH = UInt8(bytesPerRow / 256)
        command.append(contentsOf: [xL, xH])
        
        // yL, yH (height in dots)
        let yL = UInt8(height % 256)
        let yH = UInt8(height / 256)
        command.append(contentsOf: [yL, yH])
        
        command.append(rasterData)
        
        return command
    }
    
    /// Converts a UIImage to ESC/POS Bit Image commands (ESC *).
    /// This follows the logic from the Medium article (24-dot double density).
    public static func toBitImageCommand(image: UIImage) -> Data? {
        guard let cgImage = image.cgImage else { return nil }
        
        let width = cgImage.width
        let height = cgImage.height
        
        guard let dataProvider = cgImage.dataProvider,
              let data = dataProvider.data,
              let ptr = CFDataGetBytePtr(data) else {
            return nil
        }
        
        var command = Data()
        
        // Set line spacing to 0: ESC 3 0
        command.append(contentsOf: [0x1B, 0x33, 0x00])
        
        let bytesPerPixel = cgImage.bitsPerPixel / 8
        let bytesPerLine = cgImage.bytesPerRow
        
        // Helper to get pixel intensity (0=light, 1=dark)
        func getPixel(x: Int, y: Int) -> UInt8 {
            if x >= width || y >= height { return 0 }
            let offset = y * bytesPerLine + x * bytesPerPixel
            let r = ptr[offset]
            let g = ptr[offset + 1]
            let b = ptr[offset + 2]
            let luminance = 0.299 * Double(r) + 0.587 * Double(g) + 0.114 * Double(b)
            return luminance < 128 ? 1 : 0
        }
        
        // Iterate through each 24-dot high strip
        // The article uses height / 24. If height is not divisible, we might lose bottom lines or need padding.
        // We'll iterate to cover full height.
        let strips = (height + 23) / 24
        
        for j in 0..<strips {
            // ESC * 33 nL nH
            // Mode 33 = 24-dot double density
            command.append(contentsOf: [0x1B, 0x2A, 33])
            
            let nL = UInt8(width % 256)
            let nH = UInt8(width / 256)
            command.append(contentsOf: [nL, nH])
            
            // Iterate columns
            for i in 0..<width {
                // Each column has 3 bytes (24 pixels)
                for m in 0..<3 {
                    var byte: UInt8 = 0
                    for n in 0..<8 {
                        let y = j * 24 + m * 8 + n
                        let val = getPixel(x: i, y: y)
                        // Article logic: byte = (byte << 1) | b
                        // This packs MSB first (top pixel is MSB?)
                        // Let's check article: "byte = (byte << 1) | b" inside loop n=0..8
                        // If n=0 (top), it gets shifted 7 times? No.
                        // n=0: byte = b
                        // n=1: byte = b0<<1 | b1
                        // ...
                        // n=7: byte = b0<<7 ... | b7
                        // So top pixel is MSB. Correct for ESC *.
                        byte = (byte << 1) | val
                    }
                    command.append(byte)
                }
            }
            
            // Line Feed
            command.append(0x0A)
        }
        
        // Restore line spacing (optional, usually 30 or 32)
        command.append(contentsOf: [0x1B, 0x32])
        
        return command
    }
}
