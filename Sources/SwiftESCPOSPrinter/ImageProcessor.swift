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
}
