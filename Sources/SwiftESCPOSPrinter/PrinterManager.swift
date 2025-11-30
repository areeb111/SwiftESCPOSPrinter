//
//  PrinterManager.swift
//  SwiftESCPOSPrinter
//

import Foundation
import Network
import UIKit

@available(iOS 12.0, macOS 10.14, *)
public class PrinterManager {
    
    private var connection: NWConnection?
    private let queue = DispatchQueue(label: "com.swiftescposprinter.queue")
    
    public init() {}
    
    public func connect(host: String, port: UInt16, completion: @escaping (Bool, Error?) -> Void) {
        let hostEndpoint = NWEndpoint.Host(host)
        let portEndpoint = NWEndpoint.Port(integerLiteral: port)
        
        connection = NWConnection(host: hostEndpoint, port: portEndpoint, using: .tcp)
        
        connection?.stateUpdateHandler = { state in
            switch state {
            case .ready:
                completion(true, nil)
            case .failed(let error):
                completion(false, error)
            default:
                break
            }
        }
        
        connection?.start(queue: queue)
    }
    
    public func disconnect() {
        connection?.cancel()
        connection = nil
    }
    
    public func print(image: UIImage, width: CGFloat = 576, completion: @escaping (Error?) -> Void) {
        // 1. Desaturate
        guard let desaturated = image.desaturated() else {
            completion(NSError(domain: "PrinterManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to desaturate image"]))
            return
        }
        
        // 2. Resize
        guard let resized = ImageProcessor.resize(image: desaturated, targetWidth: width) else {
            completion(NSError(domain: "PrinterManager", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to resize image"]))
            return
        }
        
        // 3. Convert to Command
        guard let command = ImageProcessor.toRasterCommand(image: resized) else {
            completion(NSError(domain: "PrinterManager", code: 3, userInfo: [NSLocalizedDescriptionKey: "Failed to convert image to commands"]))
            return
        }
        
        // 4. Send
        send(data: command, completion: completion)
    }
    
    public func cutPaper(completion: @escaping (Error?) -> Void) {
        // GS V 66 0
        let command = Data([0x1D, 0x56, 66, 0])
        send(data: command, completion: completion)
    }
    
    private func send(data: Data, completion: @escaping (Error?) -> Void) {
        guard let connection = connection else {
            completion(NSError(domain: "PrinterManager", code: 0, userInfo: [NSLocalizedDescriptionKey: "Not connected"]))
            return
        }
        
        connection.send(content: data, completion: .contentProcessed { error in
            completion(error)
        })
    }
}
