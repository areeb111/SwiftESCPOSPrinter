import SwiftUI
import SwiftESCPOSPrinter

struct ContentView: View {
    @State private var ipAddress: String = "192.168.1.100"
    @State private var port: String = "9100"
    @State private var statusMessage: String = "Ready"
    @State private var isPrinting: Bool = false
    
    private let printer = PrinterManager()
    
    var body: some View {
        VStack(spacing: 20) {
            Text("ESC/POS Printer Test")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            VStack(alignment: .leading) {
                Text("Printer IP Address")
                TextField("192.168.1.100", text: $ipAddress)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .keyboardType(.decimalPad)
                
                Text("Port")
                TextField("9100", text: $port)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .keyboardType(.numberPad)
            }
            .padding()
            
            Button(action: printReceipt) {
                if isPrinting {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Text("Print Test Receipt")
                        .fontWeight(.semibold)
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(10)
            .disabled(isPrinting)
            
            Text(statusMessage)
                .font(.footnote)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
            
            Spacer()
        }
        .padding()
    }
    
    func printReceipt() {
        guard let portInt = UInt16(port) else {
            statusMessage = "Invalid Port"
            return
        }
        
        isPrinting = true
        statusMessage = "Connecting..."
        
        printer.connect(host: ipAddress, port: portInt) { success, error in
            if !success {
                DispatchQueue.main.async {
                    statusMessage = "Connection failed: \(error?.localizedDescription ?? "Unknown error")"
                    isPrinting = false
                }
                return
            }
            
            DispatchQueue.main.async {
                statusMessage = "Connected. Generating receipt..."
            }
            
            // Create Receipt
            let receipt = NSMutableAttributedString(string: "SwiftESCPOSPrinter\n", attributes: [.font: UIFont.boldSystemFont(ofSize: 30)])
            receipt.appendCenter("Test Receipt\n")
            receipt.append("--------------------------------\n")
            receipt.append("Item 1 ................. $10.00\n")
            receipt.append("Item 2 ................. $20.00\n")
            receipt.append("--------------------------------\n")
            receipt.appendBold("Total .................. $30.00\n")
            receipt.append("\n\n")
            
            // Rasterize
            guard let image = receipt.rasterize(width: 576) else {
                DispatchQueue.main.async {
                    statusMessage = "Failed to rasterize receipt"
                    isPrinting = false
                    printer.disconnect()
                }
                return
            }
            
            DispatchQueue.main.async {
                statusMessage = "Printing..."
            }
            
            printer.print(image: image) { error in
                if let error = error {
                    DispatchQueue.main.async {
                        statusMessage = "Print failed: \(error.localizedDescription)"
                    }
                } else {
                    printer.cutPaper { _ in
                        DispatchQueue.main.async {
                            statusMessage = "Printed Successfully!"
                        }
                        printer.disconnect()
                    }
                }
                
                DispatchQueue.main.async {
                    isPrinting = false
                }
            }
        }
    }
}
