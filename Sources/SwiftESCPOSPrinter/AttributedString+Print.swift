//
//  AttributedString+Print.swift
//  SwiftESCPOSPrinter
//
//  Adapted from RasterizedReceiptPrinting
//

import Foundation
import UIKit

// Constants font type - Using system fonts as fallback
public let printingFontSizeBase: CGFloat = 24

// MARK: - Extension for rasterizing to image.
public extension NSAttributedString {
    /// Create raster image from `NSAttributedString` for printing.
    ///
    /// - Parameters:
    ///   - width: The width of the printing.
    /// - Returns: The `UIImage` of the data.
    func rasterize(width: CGFloat) -> UIImage? {
        let options: NSStringDrawingOptions = [.usesLineFragmentOrigin, .truncatesLastVisibleLine]
        // Calculate height needed
        let dataRect = boundingRect(with: CGSize(width: width, height: 10000), options: options, context: nil)
        let dataSize = CGSize(width: width, height: dataRect.height) // Ensure width is fixed
        
        UIGraphicsBeginImageContextWithOptions(dataSize, true, 1.0) // Opaque, scale 1.0 for pixel perfection
        
        guard let context = UIGraphicsGetCurrentContext() else {
            return nil
        }
        
        // Fill white background
        UIColor.white.set()
        let rect = CGRect(origin: .zero, size: dataSize)
        context.fill(rect)
        
        // Draw text
        self.draw(in: rect)
        
        // Build the image
        guard let image = UIGraphicsGetImageFromCurrentImageContext() else {
            UIGraphicsEndImageContext()
            return nil
        }
        UIGraphicsEndImageContext()
        return image
    }
}

/// Extension NSMutableAttributedString to append string with NSAttributedString
public extension NSMutableAttributedString {

    func appendX2(_ text: String) {
        self.append(text, bold: false, center: false, size: printingFontSizeBase*2)
    }
    func appendX15(_ text: String) {
        self.append(text, bold: false, center: false, size: printingFontSizeBase*1.3)
    }
    func appendCenter(_ text: String) {
        self.append(text, bold: false, center: true)
    }
    func appendCenterX2(_ text: String) {
        self.append(text, bold: false, center: true, size: printingFontSizeBase*2)
    }
    func appendBold(_ text : String) {
        self.append(text, bold: true)
    }
    func appendBoldCenter(_ text : String) {
        self.append(text, bold: true, center: true)
    }
    func appendBoldX2(_ text : String) {
        self.append(text, bold: true, center: false, size: printingFontSizeBase*2)
    }
    func appendBoldX25(_ text : String) {
        self.append(text, bold: true, center: false, size: printingFontSizeBase*2.5)
    }
    func appendBoldCenterX2(_ text : String) {
        self.append(text, bold: true, center: true, size: printingFontSizeBase*2)
    }
    func appendGroupSeperateLine(_ text : String) {
        self.append(text, bold: false, center: true, size: printingFontSizeBase*2, isGroupLine: true)
    }
    func appendPrintLargeTableName(_ text : String) {
        self.append(text, bold: true, center: true, size: printingFontSizeBase*3, isGroupLine: false, underline: true)
    }

    /// Append a string with custom style.
    ///
    /// - Parameters:
    ///   - text: The text to append.
    ///   - bold: `true` to format as bold.
    ///   - center: `true` to center aligned.
    ///   - fontSize: the size of the text.
    ///   - isGroupLine: check for case is seperate line
    func append(_ text: String, bold: Bool = false, center: Bool = false, size fontSize: CGFloat = printingFontSizeBase, isGroupLine: Bool = false) {
        self.append(text, bold: bold, center: center, size: fontSize, isGroupLine: isGroupLine, underline: false)
    }

    /// Append a string with custom style.
    ///
    /// - Parameters:
    ///   - text: The text to append.
    ///   - bold: `true` to format as bold.
    ///   - center: `true` to center aligned.
    ///   - fontSize: the size of the text.
    ///   - underline: text underlining
    func append(_ text: String, bold: Bool = false, center: Bool = false, size fontSize: CGFloat = printingFontSizeBase, isGroupLine: Bool = false, underline: Bool = false) {
        // Use system fonts instead of custom loaded fonts
        let font: UIFont
        if bold {
            font = UIFont.boldSystemFont(ofSize: fontSize)
        } else {
            font = UIFont.systemFont(ofSize: fontSize)
        }
        
        append(text, font: font, center: center, isGroupLine: isGroupLine, underline: underline)
    }


    /// Append text with specific font.
    ///
    /// - Parameters:
    ///   - text: the text to append
    ///   - font: the font to be used
    ///   - center: center text
    ///   - underline: underline text
    func append(_ text: String, font: UIFont, center: Bool = false, isGroupLine: Bool = false, underline: Bool = false) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = 10.0
        paragraph.alignment = center ? .center : .left
        if isGroupLine {
            paragraph.paragraphSpacing = 16.0
            paragraph.lineSpacing = 0.0
        }
        var attributes: [NSAttributedString.Key: Any] = [
            .backgroundColor: isGroupLine ? UIColor.black : UIColor.clear,
            .foregroundColor: isGroupLine ? UIColor.white : UIColor.black,
            .font: font,
            .paragraphStyle: paragraph]
        if underline {
            attributes[.underlineColor] = UIColor.black
            attributes[.underlineStyle] = NSUnderlineStyle.thick.rawValue
        }
        self.append(NSAttributedString(string: text, attributes: attributes))
    }

    /// Append an image for printing purpose.
    ///
    /// - Parameter image: the image to append.
    func appendImage(_ image: UIImage, height: CGFloat = 120) {
        let textAttachment = NSTextAttachment()
        let ratio = image.size.width / image.size.height
        let width = height * ratio
        textAttachment.bounds = CGRect(x: 0, y: 0, width: width, height: height)
        textAttachment.image = image

        let iconString = NSAttributedString(attachment: textAttachment)
        let logoString = NSMutableAttributedString(attributedString: iconString)
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = 12.0
        paragraph.alignment = .center
        let attributes = [NSAttributedString.Key.paragraphStyle: paragraph]
        logoString.addAttributes(attributes, range: NSMakeRange(0, iconString.length))
        append(logoString)
        append("\n")
    }
}
