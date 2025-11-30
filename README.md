# SwiftESCPOSPrinter

A Swift Package for generating image-based receipts and printing them to ESC/POS printers via TCP/IP.

## Features

- **Layout to Image**: Convert `NSAttributedString` layouts to `UIImage` for printing.
- **Image Processing**: Automatically desaturates, resizes, and dithers images for thermal printing.
- **ESC/POS Support**: Sends standard `GS v 0` raster commands compatible with most thermal printers (Epson, Star, generic).
- **Network Printing**: Connects directly to printers via IP address and Port.
- **No External Dependencies**: All necessary logic is included within the package.

## Installation

### Swift Package Manager

Add the following dependency to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/areeb111/SwiftESCPOSPrinter.git", from: "1.0.0")
]
```

## Usage

### 1. Import the Package

```swift
import SwiftESCPOSPrinter
import UIKit // Required for UIImage and NSAttributedString
```

### 2. Create Receipt Content

Use `NSMutableAttributedString` to build your receipt layout. The package provides extensions for easy formatting.

```swift
let receipt = NSMutableAttributedString(string: "My Store\n", attributes: [.font: UIFont.boldSystemFont(ofSize: 30)])
receipt.appendCenter("123 Main St, City\n")
receipt.append("--------------------------------\n")
receipt.append("Item 1 ................. $10.00\n")
receipt.append("Item 2 ................. $20.00\n")
receipt.append("--------------------------------\n")
receipt.appendBold("Total .................. $30.00\n")
receipt.append("\n\n")
```

### 3. Print

Connect to the printer and send the data.

```swift
let printer = PrinterManager()
let printerIP = "192.168.1.100"
let printerPort: UInt16 = 9100

printer.connect(host: printerIP, port: printerPort) { success, error in
    guard success else {
        print("Connection failed: \(String(describing: error))")
        return
    }

    // Rasterize the receipt to an image (width 576 is standard for 80mm paper)
    if let image = receipt.rasterize(width: 576) {
        // Print using Raster mode (default, faster) or BitImage mode (ESC *, from Medium article)
        printer.print(image: image, mode: .raster) { error in
            if let error = error {
                print("Print failed: \(error)")
            } else {
                print("Printed successfully!")
                // Cut paper
                printer.cutPaper { _ in
                    printer.disconnect()
                }
            }
        }
    }
}
```

### Print Modes

The `print` function supports two modes:

- `.raster` (Default): Uses `GS v 0` command. Faster and recommended for modern printers.
- `.bitImage`: Uses `ESC *` command. Follows the implementation described in the Medium article. Useful for older printers or specific compatibility needs.

## Requirements

- iOS 12.0+
- Swift 5.0+

## License

MIT
